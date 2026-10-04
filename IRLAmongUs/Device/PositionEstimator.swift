import CoreGraphics
import CoreLocation
import CoreMotion
import Observation
import UIKit

/// How this phone works out where it is (Settings, for testing them against each other).
enum PositionMode: String, CaseIterable, Identifiable {
    /// The original estimator: GPS always blended in, steps follow the compass only with the screen facing up.
    case gps
    /// Starts at the red button, steps move you the way you face (any tilt), sign scans correct; no GPS indoors.
    case steps
    /// Like steps, but ARKit camera tracking measures the movement while the phone is held up. Heavy on battery.
    case ar

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gps: return "GPS"
        case .steps: return "Steps"
        case .ar: return "AR"
        }
    }

    var detail: String {
        switch self {
        case .gps: return "The original: GPS blended with steps. GPS is off by tens of meters indoors."
        case .steps: return "Starts you at the red button; steps move you the way the phone faces; each sign scan corrects you. GPS only outdoors."
        case .ar: return "Like Steps, but the camera tracks your movement while the phone is held up (much more accurate, much more battery). Steps take over when the camera can't see."
        }
    }
}

/// This phone's best guess at where it is, from the phone's own sensors only (no beacons).
///
/// A small filter in local meters: a position plus one uncertainty radius.
/// - **Sign check-ins** are exact fixes: scanning a sign puts you at that sign, within a few meters.
/// - **The red button** is where everyone starts, so the game's start is a fix there too.
/// - **Steps** are detected one by one from the phone's motion (the pedometer only reports every few
///   seconds, so it just calibrates stride length) and move the estimate the way the player faces while the
///   phone is held in front of them, at any tilt from flat to nearly upright. Just after lowering the phone,
///   the last way it faced is used; with no direction at all (in a pocket), steps only grow the radius: you
///   can't be further from the last fix than you've walked. (GPS mode keeps the original pedometer steps.)
/// - **GPS** pulls the estimate in proportion to how good the fix claims to be. Fixes that disagree
///   wildly with everything else are mostly ignored rather than trusted (indoor GPS jumps). Indoors, once
///   a sign has placed you, GPS is ignored altogether: steps from that sign beat it (except in `PositionMode.gps`).
/// - **The floor plan** keeps the dot out of walls when it's only just outside a room, and names the room.
/// - **The barometer** notices going up or down a floor from the last sign (GPS can't).
/// - **AR** (`PositionMode.ar`): ARKit's camera tracking moves the estimate instead of steps while it can see.
///
/// The server adds what only it can see: who is standing next to whom over BLE (see positions.ts).
@Observable
final class PositionEstimator {
    struct Estimate: Equatable {
        var lat: Double
        var lng: Double
        /// One-sigma uncertainty radius, meters.
        var accuracyM: Double
        var roomId: String?
        var room: String?
        /// SFU building and floor (campus map), when known.
        var buildingId: String?
        var floorId: String?
        /// e.g. "SUB · 2000 Level", for display.
        var place: String?
        /// Floors up (+) or down (-) from the last sign check-in.
        var levelDelta: Int
        /// What fed the estimate recently: sign, steps, compass, gps, map, baro.
        var sources: [String]
        var updatedAt: Date
    }

    /// Sensor readouts for the live map's testing panel.
    struct Diagnostics: Equatable {
        var gpsAccuracyM: Double?
        /// How far the last GPS fix moved the estimate, 0 (ignored) to 1 (taken as is).
        var gpsWeight: Double?
        var gpsOutlier = false
        /// GPS is being ignored: indoors, after a sign fix.
        var gpsIgnoredIndoors = false
        /// AR mode: what the camera tracking is doing, and how far it has moved you since the last fix.
        var arState: String?
        var arMetersSinceFix = 0.0
        var stepsSinceFix = 0
        var metersSinceFix = 0.0
        var compassUsable = false
        var phoneHeldUp = false
        var stepsAvailable = CMPedometer.isStepCountingAvailable()
        /// Step length in use (meters), calibrated by the pedometer.
        var strideM = PositionEstimator.defaultStrideM
        /// How the last step was steered: "compass", "compass (unsure)", "last facing", or "no direction".
        var lastStepDirection: String?
        var lastFixName: String?
        var lastFixAt: Date?
        var altitudeSinceFixM: Double?
        var snappedToMap = false
    }

    private(set) var estimate: Estimate?
    private(set) var diagnostics = Diagnostics()

    // Filter state: meters east/north of `origin`, and the variance of each axis (m²).
    @ObservationIgnored private var origin: CLLocationCoordinate2D?
    @ObservationIgnored private var x = 0.0
    @ObservationIgnored private var y = 0.0
    @ObservationIgnored private var variance = 0.0
    @ObservationIgnored private var hasState = false

    @ObservationIgnored private let pedometer = CMPedometer()
    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private let altimeter = CMAltimeter()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var running = false
    @ObservationIgnored private var lastTick = Date()

    @ObservationIgnored private var lastPedometerDistance: Double?
    @ObservationIgnored private var lastPedometerSteps: Int?
    @ObservationIgnored private var heading: (degrees: Double, accuracy: Double, at: Date)?
    /// Compass samples while walking, averaged over each pedometer interval.
    @ObservationIgnored private var headingSum = (sin: 0.0, cos: 0.0, usable: 0, total: 0)

    @ObservationIgnored private var lastStepAt: Date?
    @ObservationIgnored private var lastCompassMoveAt: Date?
    @ObservationIgnored private var lastGPSUsedAt: Date?
    @ObservationIgnored private var lastGPSProcessedAt: Date?
    @ObservationIgnored private var lastGPSTimestamp: Date?
    @ObservationIgnored private var relativeAltitude: Double?
    @ObservationIgnored private var altitudeAtFix: Double?
    @ObservationIgnored private var levelDelta = 0

    /// The campus floor plans, for which building, floor and room the estimate is in.
    @ObservationIgnored weak var campus: CampusMap?
    /// Building and floor of the last sign check-in: the barometer counts floors from there.
    @ObservationIgnored private var fixBuildingId: String?
    @ObservationIgnored private var fixFloorId: String?
    /// The game's play area: assumed until a sign check-in says otherwise.
    @ObservationIgnored var playArea: CampusPlace?
    /// Which way to work out position (Settings).
    @ObservationIgnored var mode: PositionMode = .steps
    @ObservationIgnored private var arTrackingAt: Date?
    @ObservationIgnored private var lastARMoveAt: Date?
    /// True north minus magnetic north, degrees, from Core Location (the motion sensors only know magnetic north).
    @ObservationIgnored private var declination = 0.0
    /// Which way is up on the screen as the player sees it, in the phone's own axes (refreshed every second).
    @ObservationIgnored private var screenUp = (x: 0.0, y: 1.0)
    /// Steps and AR modes: steps detected as they happen, and the way the player last faced.
    @ObservationIgnored private var stepDetector = StepDetector()
    @ObservationIgnored private var facing: (degrees: Double, trusted: Bool, at: Date)?

    // Tuning. Indoor GPS radii are optimistic and successive fixes share the same error, so they're
    // inflated and thinned out; the pedometer's step length is decent, the phone's heading less so.
    static let signFixM = 3.0
    /// Everyone stands around the red button when the game starts.
    static let startFixM = 5.0
    private static let gpsInflation = 1.5
    private static let gpsMinGap: TimeInterval = 2.5
    private static let compassStepError = 0.3
    /// Compass says it's disturbed (common indoors), or the phone was just lowered: still the best guess.
    private static let unsureStepError = 0.5
    private static let pocketStepError = 0.9
    static let defaultStrideM = 0.7
    /// How long after lowering the phone its last facing still steers steps.
    private static let facingMemory: TimeInterval = 5
    private static let minAccuracyM = 2.0
    private static let maxAccuracyM = 250.0
    private static let floorHeightM = 4.0
    /// ARKit drifts about 1-3% of the distance walked.
    private static let arMoveError = 0.03

    func start() {
        guard !running else { return }
        running = true
        lastTick = Date()
        if CMPedometer.isDistanceAvailable() || CMPedometer.isStepCountingAvailable() {
            pedometer.startUpdates(from: Date()) { [weak self] data, _ in
                guard let data else { return }
                DispatchQueue.main.async { self?.usePedometer(data) }
            }
        }
        if motion.isDeviceMotionAvailable {
            // Fast enough to see each step's bounce.
            motion.deviceMotionUpdateInterval = 1.0 / 50
            // A magnetic reference frame fills in `magneticField`, so the heading works at any tilt.
            let magnetic = CMMotionManager.availableAttitudeReferenceFrames().contains(.xMagneticNorthZVertical)
            motion.startDeviceMotionUpdates(using: magnetic ? .xMagneticNorthZVertical : .xArbitraryZVertical, to: .main) { [weak self] data, _ in
                guard let data else { return }
                self?.useMotion(data)
            }
        }
        updateScreenUp()
        // The barometer restarts from zero: its first reading becomes the baseline for the next fix.
        relativeAltitude = nil
        altitudeAtFix = nil
        levelDelta = 0
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
                guard let data else { return }
                self?.useAltitude(data.relativeAltitude.doubleValue)
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
    }

    func stop() {
        guard running else { return }
        running = false
        pedometer.stopUpdates()
        motion.stopDeviceMotionUpdates()
        altimeter.stopRelativeAltitudeUpdates()
        timer?.invalidate()
        timer = nil
        lastPedometerDistance = nil
        lastPedometerSteps = nil
        stepDetector = StepDetector()
        facing = nil
    }

    /// Forget everything (leaving a game).
    func reset() {
        stop()
        hasState = false
        origin = nil
        estimate = nil
        diagnostics = Diagnostics()
        altitudeAtFix = nil
        levelDelta = 0
        fixBuildingId = nil
        fixFloorId = nil
    }

    // MARK: - Inputs

    /// A verified sign check-in (or the game starting at the red button): we know where the player is,
    /// to within `accuracyM`.
    func fix(lat: Double, lng: Double, name: String, buildingId: String? = nil, floorId: String? = nil,
             accuracyM: Double = PositionEstimator.signFixM) {
        fixBuildingId = buildingId
        fixFloorId = floorId
        let p = meters(lat: lat, lng: lng)
        x = p.x
        y = p.y
        variance = accuracyM * accuracyM
        hasState = true
        diagnostics.lastFixName = name
        diagnostics.lastFixAt = Date()
        diagnostics.stepsSinceFix = 0
        diagnostics.metersSinceFix = 0
        diagnostics.arMetersSinceFix = 0
        altitudeAtFix = relativeAltitude
        levelDelta = 0
        publish()
    }

    func useGPS(_ location: CLLocation) {
        let h = location.horizontalAccuracy
        guard h > 0, h <= 100, -location.timestamp.timeIntervalSinceNow < 10,
              location.timestamp != lastGPSTimestamp else { return }
        diagnostics.gpsAccuracyM = h
        // Consecutive fixes share most of their error; taking each one as new evidence would make the
        // filter far too sure of itself. Use one every couple of seconds.
        if let last = lastGPSProcessedAt, Date().timeIntervalSince(last) < Self.gpsMinGap { return }
        lastGPSProcessedAt = Date()
        lastGPSTimestamp = location.timestamp
        // Indoors GPS is off by tens of meters and drags a good step-counted track around with it.
        // Once there's any estimate (GPS's own first guess, the red button or a sign), steps beat it indoors.
        diagnostics.gpsIgnoredIndoors = mode != .gps && hasState && estimate?.buildingId != nil
        if diagnostics.gpsIgnoredIndoors {
            diagnostics.gpsWeight = 0
            diagnostics.gpsOutlier = false
            return
        }

        let z = meters(lat: location.coordinate.latitude, lng: location.coordinate.longitude)
        var r = pow(max(h, 5) * Self.gpsInflation, 2)
        guard hasState else {
            x = z.x
            y = z.y
            variance = r
            hasState = true
            diagnostics.gpsWeight = 1
            lastGPSUsedAt = Date()
            publish()
            return
        }
        let dx = z.x - x, dy = z.y - y
        let distance2 = dx * dx + dy * dy
        // Soft outlier rejection: a fix far outside both radii counts for much less, not nothing,
        // so a genuinely wrong estimate still gets dragged back over a few fixes.
        let gate = 9 * (variance + r)
        diagnostics.gpsOutlier = distance2 > gate
        if distance2 > gate { r *= distance2 / gate }
        let k = variance / (variance + r)
        x += k * dx
        y += k * dy
        variance *= 1 - k
        diagnostics.gpsWeight = k
        if k > 0.05 { lastGPSUsedAt = Date() }
        publish()
    }

    func useHeading(_ newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        let degrees = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        heading = (degrees, newHeading.headingAccuracy, Date())
        if newHeading.trueHeading >= 0 {
            declination = (newHeading.trueHeading - newHeading.magneticHeading + 540).truncatingRemainder(dividingBy: 360) - 180
        }
    }

    private func useMotion(_ data: CMDeviceMotion) {
        let g = data.gravity
        let field = data.magneticField
        // Core Location knows when the compass is disturbed (steel, wiring) or needs calibrating, but it
        // stops giving headings with the phone upright; then the magnetometer's own calibration has to do.
        let recentHeading = heading.flatMap { Date().timeIntervalSince($0.at) < 2 ? $0 : nil }
        let direction: Double?
        let compassTrusted: Bool
        if mode != .gps, field.accuracy != .uncalibrated, field.field.x != 0 || field.field.y != 0 || field.field.z != 0 {
            compassTrusted = recentHeading.map { $0.accuracy <= 35 } ?? (field.accuracy == .medium || field.accuracy == .high)
            // Held in front of you, in the way the screen is being read, anywhere from flat to nearly upright.
            let up = (x: screenUp.x, y: screenUp.y)
            let heldUp = Self.isHeldUp(gravity: (g.x, g.y, g.z), screenUp: up)
            diagnostics.phoneHeldUp = heldUp
            direction = heldUp ? Self.facing(gravity: (g.x, g.y, g.z), magnetic: (field.field.x, field.field.y, field.field.z),
                                             screenUp: up).map { $0 + declination } : nil
        } else {
            // No magnetometer through Core Motion: Core Location's heading, which only means something
            // with the screen facing up (within ~60°).
            let heldUp = g.z < -0.5
            diagnostics.phoneHeldUp = heldUp
            direction = heldUp ? recentHeading?.degrees : nil
            compassTrusted = recentHeading.map { $0.accuracy <= 35 } ?? false
        }
        if let direction { facing = (direction, compassTrusted, Date()) }
        if mode != .gps {
            let n = max((g.x * g.x + g.y * g.y + g.z * g.z).squareRoot(), 0.5)
            let a = data.userAcceleration
            // Acceleration along "up", in g: each step is one bounce.
            let vertical = -(a.x * g.x + a.y * g.y + a.z * g.z) / n
            if stepDetector.add(vertical, at: data.timestamp) { step() }
        }
        let usable = direction != nil && compassTrusted
        diagnostics.compassUsable = usable
        headingSum.total += 1
        if usable, let direction {
            let radians = direction * .pi / 180
            headingSum.sin += sin(radians)
            headingSum.cos += cos(radians)
            headingSum.usable += 1
        }
    }

    /// In hand and being looked at: the screen tilted back toward the player at least a little (not upright
    /// in a pocket, not face down), and level side to side in the orientation the screen is being read in.
    static func isHeldUp(gravity g: (x: Double, y: Double, z: Double), screenUp: (x: Double, y: Double)) -> Bool {
        let n = (g.x * g.x + g.y * g.y + g.z * g.z).squareRoot()
        guard n > 0.5 else { return false }
        // Gravity points down, so "up" in the phone's axes is -g.
        let upZ = -g.z / n
        let upAlongTop = -(g.x * screenUp.x + g.y * screenUp.y) / n
        // The screen's right edge: top × out-of-screen.
        let upAlongRight = -(g.x * screenUp.y - g.y * screenUp.x) / n
        return upZ > 0.1 && upAlongTop > -0.3 && abs(upAlongRight) < 0.5
    }

    /// The way the player faces, degrees clockwise from magnetic north, from the phone's gravity and
    /// magnetic field (both in the phone's axes). Facing = the screen's top plus straight out the back: flat,
    /// the back points at the floor and the top points ahead; upright, the top points at the sky and the back
    /// points ahead; in between both lean forward. Their sum, flattened, is always ahead.
    static func facing(gravity g: (x: Double, y: Double, z: Double), magnetic m: (x: Double, y: Double, z: Double),
                       screenUp: (x: Double, y: Double)) -> Double? {
        let gn = (g.x * g.x + g.y * g.y + g.z * g.z).squareRoot()
        guard gn > 0.5 else { return nil }
        let up = (x: -g.x / gn, y: -g.y / gn, z: -g.z / gn)
        func flatten(_ v: (x: Double, y: Double, z: Double)) -> (x: Double, y: Double, z: Double) {
            let d = v.x * up.x + v.y * up.y + v.z * up.z
            return (v.x - d * up.x, v.y - d * up.y, v.z - d * up.z)
        }
        let north = flatten(m)
        // East = north × up.
        let east = (x: north.y * up.z - north.z * up.y, y: north.z * up.x - north.x * up.z, z: north.x * up.y - north.y * up.x)
        let ahead = flatten((x: screenUp.x, y: screenUp.y, z: -1))
        let a = ahead.x * east.x + ahead.y * east.y + ahead.z * east.z
        let b = ahead.x * north.x + ahead.y * north.y + ahead.z * north.z
        guard (a * a + b * b).squareRoot() > 1e-6 else { return nil }
        return (atan2(a, b) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    /// The top of the screen as the player sees it, in the phone's axes (x right, y top in portrait).
    /// Interface and device orientation name landscape the opposite way round.
    private func updateScreenUp() {
        let orientation = MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.interfaceOrientation
        }
        screenUp = switch orientation {
        case .landscapeRight: (1, 0)
        case .landscapeLeft: (-1, 0)
        case .portraitUpsideDown: (0, -1)
        default: (0, 1)
        }
    }

    private func usePedometer(_ data: CMPedometerData) {
        let steps = data.numberOfSteps.intValue
        let total = data.distance?.doubleValue ?? Double(steps) * 0.7
        defer {
            lastPedometerDistance = total
            lastPedometerSteps = steps
            headingSum = (0, 0, 0, 0)
        }
        if mode != .gps {
            // Steps are counted one by one in `useMotion`; the pedometer's own distance gives the stride.
            if data.distance != nil, steps >= 10 {
                diagnostics.strideM = min(max(total / Double(steps), 0.45), 0.95)
            }
            return
        }
        guard let lastDistance = lastPedometerDistance, let lastSteps = lastPedometerSteps else { return }
        let walked = max(0, total - lastDistance)
        guard walked > 0.05 else { return }
        lastStepAt = Date()
        diagnostics.stepsSinceFix += max(0, steps - lastSteps)
        diagnostics.metersSinceFix += walked
        guard hasState else { return }
        // The camera already measured this walk.
        if mode == .ar, let arTrackingAt, Date().timeIntervalSince(arTrackingAt) < 3 { return }

        let sigma = variance.squareRoot()
        let compassShare = headingSum.total > 0 ? Double(headingSum.usable) / Double(headingSum.total) : 0
        if compassShare >= 0.6, headingSum.usable > 0 {
            let direction = atan2(headingSum.sin, headingSum.cos) // clockwise from north
            x += walked * sin(direction)
            y += walked * cos(direction)
            variance = pow(sigma + Self.compassStepError * walked, 2)
            lastCompassMoveAt = Date()
        } else {
            // Direction unknown: the true position is somewhere within `walked` of the old one.
            variance = pow(sigma + Self.pocketStepError * walked, 2)
        }
        publish()
    }

    /// Steps and AR modes: one step, the way the player faces (or faced a moment ago).
    private func step() {
        let stride = diagnostics.strideM
        lastStepAt = Date()
        diagnostics.stepsSinceFix += 1
        diagnostics.metersSinceFix += stride
        guard hasState else { return }
        // The camera already measured this walk.
        if mode == .ar, let arTrackingAt, Date().timeIntervalSince(arTrackingAt) < 3 { return }
        let sigma = variance.squareRoot()
        let age = facing.map { Date().timeIntervalSince($0.at) } ?? .infinity
        if let facing, age < Self.facingMemory {
            let radians = facing.degrees * .pi / 180
            x += stride * sin(radians)
            y += stride * cos(radians)
            let current = age < 0.5
            let error = current && facing.trusted ? Self.compassStepError : Self.unsureStepError
            variance = pow(sigma + error * stride, 2)
            lastCompassMoveAt = Date()
            diagnostics.lastStepDirection = !current ? "last facing" : facing.trusted ? "compass" : "compass (unsure)"
        } else {
            // Direction unknown: the true position is somewhere within the steps walked of the old one.
            variance = pow(sigma + Self.pocketStepError * stride, 2)
            diagnostics.lastStepDirection = "no direction"
        }
        publish()
    }

    /// AR mode: ARKit tracked the phone moving this far (meters east and north).
    func useARMove(east: Double, north: Double) {
        guard mode == .ar, hasState else { return }
        let moved = (east * east + north * north).squareRoot()
        x += east
        y += north
        variance = pow(variance.squareRoot() + Self.arMoveError * moved, 2)
        arTrackingAt = Date()
        lastARMoveAt = Date()
        diagnostics.arMetersSinceFix += moved
        publish()
    }

    /// AR mode: whether the camera is tracking right now (steps fill in when it isn't).
    func useARState(_ state: ARPositionTracker.State) {
        if state == .tracking { arTrackingAt = Date() }
        diagnostics.arState = mode == .ar ? state.label : nil
    }

    private func useAltitude(_ meters: Double) {
        relativeAltitude = meters
        if altitudeAtFix == nil { altitudeAtFix = meters }
        guard let base = altitudeAtFix else { return }
        let change = meters - base
        diagnostics.altitudeSinceFixM = change
        // Hysteresis so standing near a floor boundary doesn't flicker.
        let candidate = Int((change / Self.floorHeightM).rounded())
        if candidate != levelDelta, abs(change - Double(candidate) * Self.floorHeightM) < Self.floorHeightM * 0.3 {
            levelDelta = candidate
            publish()
        }
    }

    private func tick() {
        updateScreenUp()
        let now = Date()
        let dt = now.timeIntervalSince(lastTick)
        lastTick = now
        guard hasState else { return }
        let pedometerWorks = diagnostics.stepsAvailable && CMPedometer.authorizationStatus() == .authorized
        if pedometerWorks {
            // Steps arrive in batches while walking; between them (or standing still) drift slowly.
            variance += 0.05 * dt
        } else {
            // No step counter: assume they might be walking.
            variance = pow(variance.squareRoot() + 0.8 * dt, 2)
        }
        publish()
    }

    // MARK: - Output

    private func publish() {
        guard hasState, let origin else { return }
        variance = min(max(variance, Self.minAccuracyM * Self.minAccuracyM), Self.maxAccuracyM * Self.maxAccuracyM)
        var coordinate = Self.coordinate(origin: origin, x: x, y: y)
        var room: POCRoom?
        diagnostics.snappedToMap = false

        // Which building and floor: the building we're in (campus map), and the floor counted by the barometer
        // from the last sign scanned in that building. Elsewhere the floor isn't known, so no room or snapping.
        let (building, floor) = MainActor.assumeIsolated { () -> (CampusBuilding?, CampusFloor?) in
            guard let campus, let building = campus.building(at: coordinate) else { return (nil, nil) }
            // Count floors from the last sign scanned in this building, else from the play area's floor.
            let base = building.id == fixBuildingId ? building.floorIndex(fixFloorId)
                : building.id == playArea?.buildingId ? building.floorIndex(playArea?.floorId) : nil
            guard let base else { return (building, nil) }
            let index = min(max(base + levelDelta, 0), building.floors.count - 1)
            return (building, building.floors[index])
        }
        if let building, let floor {
            let plan = MainActor.assumeIsolated { campus?.index(building, floor) }
            room = plan?.room(containing: coordinate)
            if room == nil, let nearest = plan?.nearestInside(to: coordinate),
               nearest.distanceM <= min(variance.squareRoot(), 8) {
                // Just outside a room and within our uncertainty: they're in the room, not the wall.
                coordinate = nearest.coordinate
                let p = meters(lat: coordinate.latitude, lng: coordinate.longitude)
                x = p.x
                y = p.y
                room = plan?.room(containing: coordinate)
                diagnostics.snappedToMap = true
            }
        }

        let now = Date()
        func recent(_ date: Date?, _ seconds: TimeInterval) -> Bool { date.map { now.timeIntervalSince($0) < seconds } ?? false }
        var sources: [String] = []
        if recent(diagnostics.lastFixAt, 120) { sources.append("sign") }
        if recent(lastStepAt, 20) { sources.append("steps") }
        if recent(lastCompassMoveAt, 20) { sources.append("compass") }
        if recent(lastARMoveAt, 20) { sources.append("ar") }
        if recent(lastGPSUsedAt, 20) { sources.append("gps") }
        if room != nil { sources.append("map") }
        if levelDelta != 0 { sources.append("baro") }

        let next = Estimate(
            lat: coordinate.latitude,
            lng: coordinate.longitude,
            accuracyM: (variance.squareRoot() * 10).rounded() / 10,
            roomId: room?.roomID,
            room: room.map { r in building.map { r.label.hasPrefix("\($0.id) ") } == true ? r.label : "\(r.roomID) \(r.label)" },
            buildingId: building?.id,
            floorId: floor?.id,
            place: building.map { b in [b.id, floor?.name].compactMap { $0 }.joined(separator: " · ") },
            levelDelta: levelDelta,
            sources: sources,
            updatedAt: now
        )
        // Skip identical estimates (other than the timestamp) to avoid redrawing the map every second.
        if var old = estimate {
            old.updatedAt = now
            if old == next { return }
        }
        estimate = next
    }

    // MARK: - Geometry

    private func meters(lat: Double, lng: Double) -> (x: Double, y: Double) {
        if origin == nil { origin = CLLocationCoordinate2D(latitude: lat, longitude: lng) }
        let o = origin!
        return ((lng - o.longitude) * cos(o.latitude * .pi / 180) * 111_320, (lat - o.latitude) * 111_320)
    }

    private static func coordinate(origin o: CLLocationCoordinate2D, x: Double, y: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: o.latitude + y / 111_320,
                               longitude: o.longitude + x / (cos(o.latitude * .pi / 180) * 111_320))
    }
}

/// Room lookup on Martin's SUB floor plan (lon/lat polygons).
struct FloorPlanIndex {
    private struct Entry {
        let room: POCRoom
        let ring: [CGPoint]
        let bounds: CGRect
        let area: Double
    }

    private let entries: [Entry]

    init(rooms: [POCRoom]) {
        entries = rooms.compactMap { room in
            guard let ring = room.rings.first, ring.count >= 3 else { return nil }
            let xs = ring.map(\.x), ys = ring.map(\.y)
            let bounds = CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
            var area = 0.0
            for i in ring.indices {
                let a = ring[i], b = ring[(i + 1) % ring.count]
                area += Double(a.x * b.y - b.x * a.y)
            }
            return Entry(room: room, ring: ring, bounds: bounds, area: abs(area) / 2)
        }
    }

    var isEmpty: Bool { entries.isEmpty }

    /// The most specific room containing the point: rooms over corridors, then the smallest.
    func room(containing c: CLLocationCoordinate2D) -> POCRoom? {
        let p = CGPoint(x: c.longitude, y: c.latitude)
        return entries
            .filter { $0.bounds.insetBy(dx: -1e-7, dy: -1e-7).contains(p) && Self.contains($0.ring, p) }
            .max { a, b in a.room.priority != b.room.priority ? a.room.priority < b.room.priority : a.area > b.area }?
            .room
    }

    /// The closest point just inside any room, with its distance in meters.
    func nearestInside(to c: CLLocationCoordinate2D) -> (coordinate: CLLocationCoordinate2D, distanceM: Double)? {
        let kx = cos(c.latitude * .pi / 180) * 111_320, ky = 111_320.0
        func local(_ q: CGPoint) -> (Double, Double) { ((Double(q.x) - c.longitude) * kx, (Double(q.y) - c.latitude) * ky) }
        var best: (x: Double, y: Double, d: Double, entry: Entry)?
        for entry in entries {
            for i in entry.ring.indices {
                let (ax, ay) = local(entry.ring[i]), (bx, by) = local(entry.ring[(i + 1) % entry.ring.count])
                let ex = bx - ax, ey = by - ay
                let len2 = ex * ex + ey * ey
                let t = len2 > 0 ? max(0, min(1, -(ax * ex + ay * ey) / len2)) : 0
                let px = ax + t * ex, py = ay + t * ey
                let d = (px * px + py * py).squareRoot()
                if best == nil || d < best!.d { best = (px, py, d, entry) }
            }
        }
        guard let best else { return nil }
        // Step half a meter past the wall, toward the room's middle, so the point is inside.
        let (cx, cy) = local(best.entry.room.center)
        let tx = cx - best.x, ty = cy - best.y
        let tl = max((tx * tx + ty * ty).squareRoot(), 0.001)
        let step = min(0.5, tl)
        let fx = best.x + tx / tl * step, fy = best.y + ty / tl * step
        return (CLLocationCoordinate2D(latitude: c.latitude + fy / ky, longitude: c.longitude + fx / kx), best.d)
    }

    private static func contains(_ ring: [CGPoint], _ p: CGPoint) -> Bool {
        var inside = false
        var j = ring.count - 1
        for i in ring.indices {
            let a = ring[i], b = ring[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
            j = i
        }
        return inside
    }
}

/// Spots steps one at a time from vertical acceleration (in g, gravity removed): each step is a bounce up
/// past a threshold. Smoothed so hand jitter doesn't count, with a short refractory time so one bounce is
/// one step, and it re-arms only once the bounce has come back down.
struct StepDetector {
    private var smoothed = 0.0
    private var armed = true
    private var lastStepAt: TimeInterval = -.infinity

    static let threshold = 0.09
    static let rearm = 0.0
    static let minInterval: TimeInterval = 0.3

    /// True when this sample completes a step.
    mutating func add(_ vertical: Double, at time: TimeInterval) -> Bool {
        smoothed += 0.3 * (vertical - smoothed)
        if !armed {
            if smoothed < Self.rearm { armed = true }
            return false
        }
        guard smoothed > Self.threshold, time - lastStepAt >= Self.minInterval else { return false }
        armed = false
        lastStepAt = time
        return true
    }
}
