import ARKit
import AVFoundation
import Observation
import SceneKit
import UIKit

/// One-room, one-task experiment. ARKit measures relative movement; no GPS or network is used.
@MainActor @Observable
final class ARWalkingSession: NSObject, @preconcurrency ARSessionDelegate {
    private(set) var gate = NearbyTaskGate()
    private(set) var status = "Starting camera…"
    private(set) var tracking = false
    private(set) var completed = false
    private(set) var taskOpen = false
    private(set) var origin: SIMD2<Float>?
    private(set) var heading: Float = 0
    private(set) var simulated = false
    private(set) var needsSettings = false
    private(set) var canPlace = false

    @ObservationIgnored weak var view: ARSCNView?
    @ObservationIgnored private var anchorID: UUID?
    @ObservationIgnored private var marker: SCNNode?
    @ObservationIgnored private var lastProcessed: TimeInterval = 0
    @ObservationIgnored private var lastFrameAt: Date?
    @ObservationIgnored private var previousPose: (point: SIMD2<Float>, time: Double)?
    @ObservationIgnored private var simulationTime = 0.0
    @ObservationIgnored private var active = false
    @ObservationIgnored private var resetRequired = false

    func attach(_ view: ARSCNView) {
        self.view = view
        view.session.delegate = self
        view.session.delegateQueue = .main
        view.scene = SCNScene()
        view.automaticallyUpdatesLighting = true
        active = true
        Task { await requestCamera() }
    }

    private func requestCamera() async {
        guard ARWorldTrackingConfiguration.isSupported else {
            status = "Camera tracking needs a supported physical device. Try Simulation."
            return
        }
        let authorized: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: authorized = true
        case .notDetermined: authorized = await AVCaptureDevice.requestAccess(for: .video)
        default: authorized = false
        }
        guard active, !simulated else { return }
        guard authorized else {
            needsSettings = true
            status = "Allow camera access in Settings, then retry."
            return
        }
        needsSettings = false
        run()
    }

    private func run() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.planeDetection = [.horizontal]
        view?.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        status = "Move the camera slowly to find the floor"
        resetRequired = false
    }

    func reset() {
        gate = NearbyTaskGate()
        origin = nil
        marker?.removeFromParentNode()
        marker = nil
        anchorID = nil
        completed = false
        taskOpen = false
        previousPose = nil
        lastProcessed = 0
        lastFrameAt = nil
        canPlace = false
        tracking = false
        if simulated {
            simulationTime = 0
            tracking = true
            canPlace = true
            status = "Simulation · place a task to begin"
        } else if active {
            Task { await requestCamera() }
        }
    }

    func stop() {
        active = false
        view?.session.pause()
        pause("Tracking paused")
    }

    func resume() {
        guard !simulated else { return }
        active = true
        // A fresh coordinate system must never silently inherit the old task coordinates.
        reset()
    }

    func placeTask() {
        guard tracking, !completed, gate.task == nil else { return }
        if simulated {
            gate.placeTask(SIMD2(0, -4))
            origin = .zero
            sampleSimulation(.zero)
            status = "Simulation · walk toward the task"
            return
        }
        guard let view, let frame = view.session.currentFrame,
              case .normal = frame.camera.trackingState,
              Date().timeIntervalSince(lastFrameAt ?? .distantPast) < 0.5,
              let hit = floorHit(in: view) else {
            status = "Aim the centre at a clear floor surface, then try again"
            return
        }
        let transform = hit.worldTransform
        let anchor = ARAnchor(name: "walking-poc-task", transform: transform)
        anchorID = anchor.identifier
        view.session.add(anchor: anchor)
        gate.placeTask(SIMD2(transform.columns.3.x, transform.columns.3.z))
        origin = SIMD2(frame.camera.transform.columns.3.x, frame.camera.transform.columns.3.z)
        let ring = SCNTorus(ringRadius: 0.18, pipeRadius: 0.025)
        ring.firstMaterial?.diffuse.contents = UIColor.systemYellow
        ring.firstMaterial?.emission.contents = UIColor.systemYellow
        let node = SCNNode(geometry: ring)
        node.simdPosition = SIMD3(transform.columns.3.x, transform.columns.3.y + 0.035, transform.columns.3.z)
        view.scene.rootNode.addChildNode(node)
        marker = node
        status = "Task placed · walk toward the yellow marker"
    }

    private func floorHit(in view: ARSCNView) -> ARRaycastResult? {
        let centre = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        guard let query = view.raycastQuery(from: centre, allowing: .existingPlaneGeometry, alignment: .horizontal),
              let hit = view.session.raycast(query).first,
              let frame = view.session.currentFrame,
              hit.worldTransform.columns.3.y < frame.camera.transform.columns.3.y - 0.4 else { return nil }
        return hit
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard active, !simulated, frame.timestamp - lastProcessed >= 0.08 else { return }
        lastProcessed = frame.timestamp
        lastFrameAt = Date()
        guard case .normal = frame.camera.trackingState else {
            let message: String
            switch frame.camera.trackingState {
            case .limited(.excessiveMotion): message = "Tracking paused · slow down and hold the camera steady"
            case .limited(.insufficientFeatures): message = "Tracking paused · point toward a well-lit, detailed area"
            case .limited(.relocalizing): message = "Reconnecting · look at the area where you placed the task"
            default: message = "Finding the floor · move the camera slowly"
            }
            pause(message)
            return
        }
        guard !resetRequired else { return }
        tracking = true
        canPlace = view.map { floorHit(in: $0) != nil } ?? false
        let transform = frame.camera.transform
        let point = SIMD2(transform.columns.3.x, transform.columns.3.z)
        if let old = previousPose, frame.timestamp - old.time < 0.35,
           simd_distance(point, old.point) / Float(frame.timestamp - old.time) > 8 {
            resetRequired = true
            pause("Position changed unexpectedly · reset and place the task again")
            return
        }
        previousPose = (point, frame.timestamp)
        if let anchorID, let anchor = frame.anchors.first(where: { $0.identifier == anchorID }) {
            // Keep the marker and interaction point consistent with ARKit's refined anchor pose.
            let task = SIMD2(anchor.transform.columns.3.x, anchor.transform.columns.3.z)
            if let prior = gate.task, simd_distance(prior, task) > 0.1 {
                gate.placeTask(task)
            }
            marker?.simdPosition = SIMD3(task.x, anchor.transform.columns.3.y + 0.035, task.y)
        }
        heading = atan2(-transform.columns.2.x, transform.columns.2.z)
        gate.update(position: point, at: frame.timestamp, tracking: true)
        if gate.task == nil { status = canPlace ? "Aim at the floor and place a task" : "Point down toward a clear floor surface" }
        else if completed { status = "Task completed · reset to test another route" }
        else if gate.ready { status = "Stopped nearby · tap Use" }
        else if gate.distance.map({ $0 <= NearbyTaskGate.interactionRadius }) == true { status = "Stop briefly to use the task" }
        else { status = "Walk toward the task" }
    }

    private func pause(_ message: String) {
        tracking = false
        canPlace = false
        previousPose = nil
        gate.pause()
        taskOpen = false
        status = message
    }

    func checkFreshness() {
        guard !simulated, tracking, let lastFrameAt,
              Date().timeIntervalSince(lastFrameAt) > 0.5 else { return }
        pause("Tracking paused · waiting for the camera")
    }

    func sessionWasInterrupted(_ session: ARSession) {
        resetRequired = true
        pause("Camera interrupted · reset and place the task again")
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        status = "Camera interrupted · reset and place the task again"
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        resetRequired = true
        pause("Camera tracking failed · tap Reset to retry")
    }

    func openTask() {
        checkFreshness()
        guard tracking, gate.ready, !completed else { return }
        taskOpen = true
    }

    func completeTask() {
        checkFreshness()
        guard taskOpen, tracking, gate.ready else { taskOpen = false; return }
        completed = true
        taskOpen = false
        status = "Task completed · reset to test another route"
        Haptics.success()
    }

    func closeTask() { taskOpen = false }

    func simulate() {
        simulated = true
        view?.session.pause()
        reset()
    }

    private func sampleSimulation(_ point: SIMD2<Float>) {
        simulationTime += 0.1
        gate.update(position: point, at: simulationTime, tracking: tracking)
    }

    func simulateWalk() {
        guard gate.task != nil, tracking else { return }
        let start = gate.position ?? .zero
        let end = SIMD2<Float>(0, -2.5)
        for step in 1...15 { sampleSimulation(start + (end - start) * Float(step) / 15) }
        status = "Simulation · stop briefly to use the task"
    }

    func simulateRunPast() {
        guard gate.task != nil, tracking else { return }
        gate.pause()
        sampleSimulation(.zero)
        for step in 1...20 { sampleSimulation(SIMD2(0, -Float(step) * 0.4)) }
        status = "Simulation · ran past; task stayed locked"
    }

    func simulateStop() {
        guard let point = gate.position, tracking else { return }
        for _ in 0..<8 { sampleSimulation(point) }
        status = gate.ready ? "Simulation · stopped nearby; tap Use" : "Simulation · outside interaction range"
    }

    func simulateTrackingLoss() { pause("Tracking paused · last position held") }
    func simulateRecovery() {
        tracking = true
        canPlace = true
        gate.pause()
        status = "Simulation · recovered; stop again before using"
    }
}
