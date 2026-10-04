import ARKit

/// The AR position mode: ARKit's camera tracking used as a far better step counter. It reports how far the
/// phone moved east and north (ARKit lines its axes up with gravity and the compass), and `PositionEstimator`
/// adds that to the last sign fix. No view: the camera runs headless at its smallest video format, but it's
/// still the camera plus motion tracking, so it costs a lot of battery. Only tracks while the camera can see
/// (phone held up); in a pocket the estimator falls back to steps.
final class ARPositionTracker: NSObject, ARSessionDelegate {
    enum State: Equatable {
        case off
        case starting
        case tracking
        /// Running, but ARKit can't tell where it is right now (dark, covered, moving fast).
        case limited(String)
        /// Stopped for a reason the player should know (camera busy, interrupted, failed).
        case paused(String)
        case unsupported

        var label: String {
            switch self {
            case .off: return "off"
            case .starting: return "starting…"
            case .tracking: return "tracking"
            case .limited(let why): return "lost: \(why)"
            case .paused(let why): return "paused: \(why)"
            case .unsupported: return "not supported on this phone"
            }
        }
    }

    /// Meters east and north since the last report (main thread).
    var onMove: ((_ east: Double, _ north: Double) -> Void)?
    /// Main thread.
    var onState: ((State) -> Void)?

    private let session = ARSession()
    private let queue = DispatchQueue(label: "ar-position")
    /// Main thread only.
    private var running = false
    private var state: State = .off
    // Delegate queue only.
    private var lastPose: (position: SIMD3<Float>, time: TimeInterval)?
    private var lastSampleAt: TimeInterval = 0

    /// Samples per second sent on: plenty for a map dot, and cheap.
    private static let sampleInterval: TimeInterval = 0.2
    /// Faster than this between samples is ARKit jumping (relocalizing), not a person walking.
    private static let maxSpeed = 4.0

    override init() {
        super.init()
        session.delegate = self
        session.delegateQueue = queue
    }

    func start() {
        guard !running else { return }
        guard ARWorldTrackingConfiguration.isSupported else { report(.unsupported); return }
        running = true
        let configuration = ARWorldTrackingConfiguration()
        // +x east, +y up, +z south: moves come out in map directions, no heading of our own needed.
        configuration.worldAlignment = .gravityAndHeading
        configuration.planeDetection = []
        configuration.isLightEstimationEnabled = false
        // Smallest picture ARKit offers: tracking needs features, not pixels.
        func pixels(_ format: ARConfiguration.VideoFormat) -> CGFloat { format.imageResolution.width * format.imageResolution.height }
        if let smallest = ARWorldTrackingConfiguration.supportedVideoFormats.min(by: { pixels($0) < pixels($1) }) {
            configuration.videoFormat = smallest
        }
        queue.async { self.lastPose = nil }
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        report(.starting)
    }

    /// Stops the camera. `reason` says why when it's not just the mode being off (e.g. scanning a sign).
    func stop(reason: String? = nil) {
        if running {
            running = false
            session.pause()
            queue.async { self.lastPose = nil }
        }
        if state != .unsupported { report(reason.map { .paused($0) } ?? .off) }
    }

    // MARK: - ARSessionDelegate (delegate queue)

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let time = frame.timestamp
        guard time - lastSampleAt >= Self.sampleInterval else { return }
        lastSampleAt = time
        let camera = frame.camera
        guard case .normal = camera.trackingState else {
            lastPose = nil
            report(.limited(Self.reason(camera.trackingState)))
            return
        }
        let c = camera.transform.columns.3
        let position = SIMD3(c.x, c.y, c.z)
        let previous = lastPose
        lastPose = (position, time)
        report(.tracking)
        guard let previous else { return }
        let east = Double(position.x - previous.position.x)
        let north = Double(previous.position.z - position.z)
        let distance = (east * east + north * north).squareRoot()
        guard distance > 0.01, distance / max(time - previous.time, 0.001) < Self.maxSpeed else { return }
        DispatchQueue.main.async { self.onMove?(east, north) }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        lastPose = nil
        report(.paused("camera interrupted"))
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        lastPose = nil
        report(.starting)
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        lastPose = nil
        DispatchQueue.main.async {
            self.running = false
            self.report(.paused(error.localizedDescription))
        }
    }

    // MARK: -

    private func report(_ next: State) {
        DispatchQueue.main.async {
            guard self.state != next else { return }
            self.state = next
            self.onState?(next)
        }
    }

    private static func reason(_ state: ARCamera.TrackingState) -> String {
        switch state {
        case .limited(.excessiveMotion): return "moving too fast"
        case .limited(.insufficientFeatures): return "can't see enough (dark, covered or blank wall)"
        case .limited(.relocalizing): return "relocalizing"
        case .limited(.initializing): return "starting up"
        case .notAvailable: return "not available"
        default: return "limited"
        }
    }
}
