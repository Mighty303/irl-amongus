import ARKit
import AVFoundation
import Observation
import SceneKit
import UIKit

/// Local floor-placement and measured-map experiments. ARKit measures relative movement; no GPS or network is used.
@MainActor @Observable
final class ARWalkingSession: NSObject, @preconcurrency ARSessionDelegate {
    private(set) var gate = NearbyTaskGate()
    private(set) var status = "Starting camera…"
    private(set) var tracking = false
    private var floorCompleted = false
    private(set) var layout = ARMapLayout.load()
    private(set) var mapped = false
    private(set) var aligned = false
    private(set) var markerDetected = false
    private(set) var completedTasks: Set<String> = []
    private(set) var selectedTaskID = "electrical"
    private(set) var mapPosition: SIMD2<Float>?
    var selectedTask: ARMapTask? { layout.tasks.first { $0.id == selectedTaskID } }
    var completed: Bool { mapped ? completedTasks.contains(selectedTaskID) : floorCompleted }
    var completedCount: Int { mapped ? completedTasks.count : (floorCompleted ? 1 : 0) }
    @ObservationIgnored private var alignment: ARMapAlignment?
    @ObservationIgnored private var beaconNodes: [String: SCNNode] = [:]
    private(set) var taskOpen = false
    private(set) var origin: SIMD2<Float>?
    private(set) var heading: Float = 0
    private(set) var simulated = false
    private(set) var needsSettings = false
    private(set) var canPlace = false

    @ObservationIgnored var onMove: ((Double, Double) -> Void)?
    @ObservationIgnored var onTrackingState: ((ARPositionTracker.State) -> Void)?
    @ObservationIgnored private var tracker: ARPositionTracker?
    @ObservationIgnored private var ownsCamera = false
    @ObservationIgnored weak var view: WalkingSceneView?
    @ObservationIgnored private var anchorID: UUID?
    @ObservationIgnored private var marker: SCNNode?
    @ObservationIgnored private var lastProcessed: TimeInterval = 0
    @ObservationIgnored private var lastFrameAt: Date?
    @ObservationIgnored private var previousPose: (point: SIMD2<Float>, time: Double)?
    @ObservationIgnored private var simulationTime = 0.0
    @ObservationIgnored private var active = false
    @ObservationIgnored private var resetRequired = false

    func attach(_ view: WalkingSceneView) {
        self.view = view
        let tracker = ARPositionTracker(session: view.session)
        tracker.onFrame = { [weak self] frame in
            guard let self, let view = self.view else { return }
            self.session(view.session, didUpdate: frame)
        }
        tracker.onMove = { [weak self] east, north in self?.onMove?(east, north) }
        tracker.onState = { [weak self] state in
            guard let self else { return }
            self.onTrackingState?(state)
            if case .paused(let why) = state { self.resetRequired = true; self.pause(why) }
        }
        self.tracker = tracker
        view.prepareScene()
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
        if !ownsCamera {
            ownsCamera = true
            CameraUsage.backCameraStarted()
            // Let GameStore's camera-usage observer pause its headless tracker before this session starts.
            await Task.yield()
        }
        guard active, !simulated else { return }
        run()
    }

    private func run() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        configuration.planeDetection = [.horizontal]
        if mapped {
            guard let cgImage = UIImage(named: "ARAlignmentMarker")?.cgImage else {
                status = "Alignment marker image is missing"
                return
            }
            let reference = ARReferenceImage(cgImage, orientation: .up, physicalWidth: CGFloat(layout.markerWidthM))
            reference.name = "walking-map-origin"
            configuration.detectionImages = [reference]
            configuration.maximumNumberOfTrackedImages = 1
        }
        tracker?.stop()
        tracker?.start(configuration: configuration)
        status = mapped ? "Point at the printed ALIGN marker" : "Move the camera slowly to find the floor"
        resetRequired = false
    }

    func reset() {
        gate = NearbyTaskGate()
        origin = nil
        marker?.removeFromParentNode()
        marker = nil
        anchorID = nil
        floorCompleted = false
        completedTasks = []
        aligned = false
        markerDetected = false
        alignment = nil
        mapPosition = nil
        beaconNodes.values.forEach { $0.removeFromParentNode() }
        beaconNodes = [:]
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
            status = mapped ? "Simulation · scan marker to align preset tasks" : "Simulation · place a task to begin"
        } else if active {
            Task { await requestCamera() }
        }
    }

    func stop() {
        active = false
        tracker?.stop()
        if ownsCamera { ownsCamera = false; CameraUsage.backCameraStopped() }
        pause("Tracking paused")
    }

    func resume() {
        guard !simulated else { return }
        active = true
        // A fresh coordinate system must never silently inherit the old task coordinates.
        reset()
    }

    func placeTask() {
        guard !mapped, tracking, !completed, gate.task == nil else { return }
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
        view.scene?.rootNode.addChildNode(node)
        marker = node
        status = "Task placed · walk toward the yellow marker"
    }

    private func floorHit(in view: WalkingSceneView) -> ARRaycastResult? {
        guard let frame = view.session.currentFrame else { return nil }
        let transform = frame.camera.transform
        let query = ARRaycastQuery(
            origin: SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z),
            direction: -SIMD3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z),
            allowing: .existingPlaneGeometry, alignment: .horizontal)
        guard let hit = view.session.raycast(query).first,
              hit.worldTransform.columns.3.y < frame.camera.transform.columns.3.y - 0.4 else { return nil }
        return hit
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard active, !simulated else { return }
        view?.present(frame)
        guard frame.timestamp - lastProcessed >= 0.08 else { return }
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
        markerDetected = frame.anchors.contains { ($0 as? ARImageAnchor)?.isTracked == true }
        beaconNodes.values.forEach { $0.isHidden = false }
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
        if mapped {
            guard let alignment else {
                status = markerDetected ? "Marker found · tap Align map" : "Point at the printed ALIGN marker"
                return
            }
            let camera = SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            mapPosition = alignment.mapPoint(camera)
            let forward = SIMD3(-transform.columns.2.x, -transform.columns.2.y, -transform.columns.2.z)
            heading = atan2(simd_dot(forward, alignment.right), simd_dot(forward, alignment.awayFromWall))
        } else {
            heading = atan2(-transform.columns.2.x, transform.columns.2.z)
        }
        gate.update(position: point, at: frame.timestamp, tracking: true)
        if mapped { updateMappedStatus(); return }
        if gate.task == nil { status = canPlace ? "Aim at the floor and place a task" : "Point down toward a clear floor surface" }
        else if completed { status = "Task completed · reset to test another route" }
        else if gate.ready { status = "Stopped nearby · tap Use" }
        else if gate.distance.map({ $0 <= NearbyTaskGate.interactionRadius }) == true { status = "Stop briefly to use the task" }
        else { status = "Walk toward the task" }
    }

    private func pause(_ message: String) {
        tracking = false
        canPlace = false
        markerDetected = false
        beaconNodes.values.forEach { $0.isHidden = true }
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
        if mapped {
            completedTasks.insert(selectedTaskID)
            refreshBeaconColours()
        } else { floorCompleted = true }
        taskOpen = false
        status = mapped ? "\(selectedTask?.name ?? "Task") completed · choose another beacon" : "Task completed · reset to test another route"
        Haptics.success()
    }

    func closeTask() { taskOpen = false }

    func setMapped(_ enabled: Bool) {
        guard mapped != enabled else { return }
        mapped = enabled
        reset()
    }

    func applyLayout(_ value: ARMapLayout, persist: Bool = true) {
        guard value.isValid else { return }
        layout = value
        if persist { layout.save() }
        if selectedTask == nil { selectedTaskID = value.tasks[0].id }
        if mapped { reset() }
    }

    /// Live games take completion from the server, never from the local POC panel.
    func updateCompletedStations(_ ids: Set<String>) {
        completedTasks = ids.intersection(Set(layout.tasks.map(\.id)))
        refreshBeaconColours()
    }

    func alignMap() {
        guard mapped, tracking, !resetRequired else { return }
        let transform: simd_float4x4
        if simulated {
            transform = simd_float4x4(columns: (
                SIMD4(1, 0, 0, 0), SIMD4(0, 0, 1, 0), SIMD4(0, -1, 0, 0),
                SIMD4(0, layout.markerCentreHeightM, 0, 1)))
        } else {
            checkFreshness()
            guard tracking, let frame = view?.session.currentFrame,
                  case .normal = frame.camera.trackingState,
                  let image = frame.anchors.compactMap({ $0 as? ARImageAnchor }).first(where: { $0.isTracked }) else {
                status = "Keep the entire printed ALIGN marker visible, then retry"
                return
            }
            transform = image.transform
        }
        guard let value = ARMapAlignment(markerTransform: transform, centreHeight: layout.markerCentreHeightM) else {
            status = "Mount the marker upright on a vertical wall, then retry"
            return
        }
        alignment = value
        aligned = true
        origin = SIMD2(value.floorOrigin.x, value.floorOrigin.z)
        previousPose = nil
        taskOpen = false
        beaconNodes.values.forEach { $0.removeFromParentNode() }
        beaconNodes = [:]
        for task in layout.tasks {
            let node = makeBeacon(task)
            node.simdPosition = value.worldPoint(task.point)
            view?.scene?.rootNode.addChildNode(node)
            beaconNodes[task.id] = node
        }
        selectTask(selectedTaskID)
        if simulated {
            let start = value.worldPoint(mapPosition ?? SIMD2(0, 1), height: 1.5)
            sampleSimulation(SIMD2(start.x, start.z))
        }
        status = "Map aligned · walk toward a task beacon"
    }

    func selectTask(_ id: String) {
        guard let task = layout.tasks.first(where: { $0.id == id }) else { return }
        selectedTaskID = id
        taskOpen = false
        if let alignment {
            let point = alignment.worldPoint(task.point)
            gate.placeTask(SIMD2(point.x, point.z))
        }
        refreshBeaconColours()
    }

    private func makeBeacon(_ task: ARMapTask) -> SCNNode {
        let node = SCNNode()
        let ring = SCNNode(geometry: SCNTorus(ringRadius: 0.25, pipeRadius: 0.025))
        ring.position.y = 0.04
        let beam = SCNNode(geometry: SCNCylinder(radius: 0.035, height: 0.9))
        beam.position.y = 0.5
        let orb = SCNNode(geometry: SCNSphere(radius: 0.11))
        orb.position.y = 1.05
        let text = SCNText(string: task.name, extrusionDepth: 0)
        text.font = .boldSystemFont(ofSize: 10)
        text.flatness = 0.2
        let label = SCNNode(geometry: text)
        let bounds = text.boundingBox
        label.pivot = SCNMatrix4MakeTranslation((bounds.min.x + bounds.max.x) / 2, bounds.min.y, 0)
        label.scale = SCNVector3(0.025, 0.025, 0.025)
        label.position.y = 1.25
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        label.constraints = [billboard]
        for child in [ring, beam, orb, label] { node.addChildNode(child) }
        return node
    }

    private func refreshBeaconColours() {
        for (id, node) in beaconNodes {
            let colour: UIColor = completedTasks.contains(id) ? .systemGreen : (id == selectedTaskID ? .systemYellow : .systemCyan)
            for child in node.childNodes {
                child.geometry?.firstMaterial?.diffuse.contents = colour
                child.geometry?.firstMaterial?.emission.contents = colour
                child.geometry?.firstMaterial?.lightingModel = .constant
            }
        }
    }

    private func updateMappedStatus() {
        let name = selectedTask?.name ?? "Task"
        if completed { status = "\(name) completed · choose another beacon" }
        else if gate.ready { status = "\(name) · stopped nearby; tap Use" }
        else if gate.distance.map({ $0 <= NearbyTaskGate.interactionRadius }) == true { status = "\(name) · stop briefly to use" }
        else { status = "Walk toward \(name)" }
    }

    func simulate() {
        simulated = true
        tracker?.stop()
        if ownsCamera { ownsCamera = false; CameraUsage.backCameraStopped() }
        reset()
    }

    private func sampleSimulation(_ point: SIMD2<Float>) {
        simulationTime += 0.1
        gate.update(position: point, at: simulationTime, tracking: tracking)
        if mapped, let alignment { mapPosition = alignment.mapPoint(SIMD3(point.x, alignment.floorOrigin.y + 1.5, point.y)) }
    }

    func simulateWalk() {
        guard gate.task != nil, tracking else { return }
        let start = gate.position ?? .zero
        let end = mapped ? (gate.task! - SIMD2<Float>(0, 1.5)) : SIMD2<Float>(0, -2.5)
        let steps = max(1, Int(ceil(simd_distance(start, end) / 0.15)))
        for step in 1...steps { sampleSimulation(start + (end - start) * Float(step) / Float(steps)) }
        status = "Simulation · stop briefly to use the task"
    }

    func simulateRunPast() {
        guard gate.task != nil, tracking else { return }
        gate.pause()
        let start = mapped ? gate.task! - SIMD2<Float>(0, 4) : .zero
        sampleSimulation(start)
        for step in 1...20 {
            sampleSimulation(start + SIMD2(0, (mapped ? 1 : -1) * Float(step) * 0.4))
        }
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
