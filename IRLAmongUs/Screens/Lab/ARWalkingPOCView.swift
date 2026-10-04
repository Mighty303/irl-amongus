import ARKit
import SwiftUI

struct ARWalkingPOCView: View {
    @State private var session = ARWalkingSession()
    @State private var showingMapSetup = false
    @State private var showingSettings = false
    @State private var prepared = false
    @State private var showingTaskMenu = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                if !session.simulated {
                    WalkingCamera(session: session).frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                } else {
                    LinearGradient(colors: [.gray.opacity(0.3), .black], startPoint: .top, endPoint: .bottom)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                VStack(spacing: 8) {
                    header
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            minimap
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.7), lineWidth: 2))
                            trackingBadge
                        }
                        Spacer(minLength: 0)
                        VStack(spacing: 8) {
                            Button {} label: {
                                VStack(spacing: 3) {
                                    Image(systemName: "megaphone.fill").font(.system(size: 20))
                                    Text("REPORT").font(.system(size: 9, weight: .bold))
                                }
                                .frame(width: 56, height: 56)
                                .background(.black.opacity(0.6), in: Circle())
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                            }.disabled(true).opacity(0.35).accessibilityLabel("Report")
                            actions
                        }
                    }
                    Text(walkingHint)
                        .font(.caption.bold()).multilineTextAlignment(.center)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(.black.opacity(0.7), in: Capsule())
                        .accessibilityIdentifier("arWalking.status")
                    if session.simulated { simulationControls }
                }
                .padding(12)
                if session.gate.task == nil {
                    Image(systemName: "plus").font(.system(size: 32, weight: .light))
                        .allowsHitTesting(false)
                }
                if session.taskOpen { taskPanel }
                if showingTaskMenu {
                    Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { showingTaskMenu = false }
                    VStack(spacing: 12) {
                        Text("Choose next task").font(.headline)
                        ForEach(session.layout.tasks) { task in
                            Button {
                                session.selectTask(task.id)
                                showingTaskMenu = false
                            } label: {
                                Label(task.name, systemImage: session.completedTasks.contains(task.id) ? "checkmark.circle.fill" : "exclamationmark.circle")
                            }.accessibilityIdentifier("arWalking.select.\(task.id)")
                        }
                        Button("Close") { showingTaskMenu = false }
                    }
                    .buttonStyle(.bordered).padding(24)
                    .background(.black.opacity(0.95), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.6), lineWidth: 2))
                }
                if showingSettings {
                    Color.black.opacity(0.65).ignoresSafeArea()
                    settings
                        .frame(maxWidth: 600, maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(12)
                        .sheet(isPresented: $showingMapSetup) {
                            ARMapSetupView(layout: session.layout, save: { session.applyLayout($0) })
                        }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .foregroundStyle(.white)
        .onAppear {
            OrientationDelegate.requestLandscape()
            if !prepared { session.setMapped(true); prepared = true }
        }
        .onDisappear { session.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { session.resume() }
            else { session.stop() }
        }
        .onChange(of: session.gate.ready) { _, ready in
            if !ready { session.closeTask() }
        }
        .task {
            while !Task.isCancelled {
                session.checkFreshness()
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 8) {
                CrewmateView(color: .red, faceURL: nil, height: 38)
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL TASKS").font(.caption2.bold())
                    ProgressView(value: Double(session.completedCount), total: session.mapped ? 3 : 1)
                        .tint(.green).frame(width: 110)
                }
                .padding(8).background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.7), lineWidth: 2))
            }
            Spacer(minLength: 0)
            Button { showingTaskMenu = true } label: {
                VStack(spacing: 3) {
                    HStack(spacing: 4) {
                        Text("Next task ·")
                        Text(session.mapped ? (session.selectedTask?.name ?? "Task") : "Floor task").foregroundStyle(.yellow)
                    }.font(.callout.bold())
                    if let distance = session.gate.distance {
                        Text(String(format: "%.1f m away", distance)).font(.caption2.monospacedDigit())
                            .accessibilityIdentifier("arWalking.distance")
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(.black.opacity(0.8), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.7), lineWidth: 2))
            }
            .buttonStyle(.plain)
            .disabled(!session.mapped)
            .accessibilityIdentifier("arWalking.taskSelection")
            Spacer(minLength: 0)
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 25))
                    .frame(width: 46, height: 46)
                    .background(.black.opacity(0.7), in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Walking settings").accessibilityIdentifier("arWalking.settings")
            .accessibilityValue(showingSettings ? "Open" : "Closed")
        }
    }

    private var walkingHint: String {
        if session.simulated { return "SIMULATION · " + session.status.replacingOccurrences(of: "Simulation · ", with: "") }
        if !session.tracking || session.gate.task == nil { return session.status }
        if session.completed { return "Task completed · choose your next task above" }
        if session.gate.ready { return "Ready · tap Use" }
        if session.gate.distance.map({ $0 <= NearbyTaskGate.interactionRadius }) == true { return "Stop briefly to use this task" }
        return "Keep the camera facing ahead"
    }

    private var trackingBadge: some View {
        let active = session.tracking && (!session.mapped || session.aligned)
        return HStack(spacing: 5) {
            Circle().fill(active ? Color.cyan : Color.orange).frame(width: 8, height: 8)
            Text(active ? "Tracking" : (session.mapped && !session.aligned ? "Not aligned" : "Tracking paused"))
                .font(.caption.bold())
        }
        .foregroundStyle(active ? .cyan : .orange)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.black.opacity(0.8), in: Capsule())
        .overlay(Capsule().stroke(active ? .cyan : .orange, lineWidth: 1.5))
    }

    private var settings: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Task placement").font(.headline)
                    mapControls
                    HStack {
                        Button("Reset") { session.reset(); showingSettings = false }
                            .accessibilityIdentifier("arWalking.reset")
                        if !session.simulated {
                            Button("Simulation") { session.simulate(); showingSettings = false }
                                .accessibilityIdentifier("arWalking.simulation")
                        }
                    }.buttonStyle(.bordered)
                    Text("Tracking diagnostics").font(.headline)
                    diagnostics
                    Text("This POC uses a measured local map. Print the alignment marker and set its centre height in Map setup.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Main menu") { dismiss() }
                        .accessibilityIdentifier("arWalking.exit")
                }.padding(16)
            }
            .navigationTitle("Walking settings").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingSettings = false }
                        .accessibilityIdentifier("arWalking.settings.close")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var diagnostics: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if let distance = session.gate.distance {
                Text(String(format: "Task · %.1f m", distance))
                    .accessibilityIdentifier("arWalking.diagnosticDistance")
            }
            if let speed = session.gate.speed { Text(String(format: "Movement · %.1f m/s", speed)) }
            Text(session.tracking ? "Tracking" : "Last known position")
                .foregroundStyle(session.tracking ? .cyan : .orange)
            if session.mapped, let point = session.mapPosition {
                Text(String(format: "Map · %.1f right, %.1f away", point.x, point.y))
            } else if let position = session.gate.position, let origin = session.origin {
                Text(String(format: "From start · %.1f m", simd_distance(position, origin)))
            }
        }
        .font(.caption.monospacedDigit())
        .padding(8).background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder private var actions: some View {
        if session.needsSettings {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }.buttonStyle(.borderedProminent)
        } else if session.mapped && !session.aligned {
            Button("Align map") { session.alignMap() }
                .buttonStyle(.borderedProminent).tint(.cyan).foregroundStyle(.black)
                .disabled(!session.tracking || (!session.simulated && !session.markerDetected))
                .accessibilityIdentifier("arWalking.align")
        } else if session.gate.task == nil {
            Button("Place task here") { session.placeTask() }
                .buttonStyle(.borderedProminent).tint(.cyan).foregroundStyle(.black)
                .disabled(!session.tracking || !session.canPlace)
                .accessibilityIdentifier("arWalking.place")
        } else if session.completed {
            Label("Task completed", systemImage: "checkmark.circle.fill")
                .font(.headline).foregroundStyle(.green)
                .padding(12).background(.black.opacity(0.8), in: Capsule())
                .accessibilityIdentifier("arWalking.completed")
        } else {
            Button { session.openTask() } label: {
                VStack(spacing: 4) {
                    Image(systemName: "hand.raised.fill").font(.system(size: 30))
                    Text("USE").font(.headline)
                }
                .frame(width: 84, height: 84)
                .background(.black.opacity(0.75), in: Circle())
                .overlay(Circle().stroke(session.gate.ready && session.tracking ? .white : .gray, lineWidth: 3))
            }
            .disabled(!session.gate.ready || !session.tracking)
            .opacity(session.gate.ready && session.tracking ? 1 : 0.45)
            .accessibilityIdentifier("arWalking.use")
        }
    }

    @ViewBuilder private var minimap: some View {
        if session.mapped {
            ARMeasuredMap(layout: session.layout, player: session.mapPosition, selectedID: session.selectedTaskID,
                          completed: session.completedTasks, tracking: session.tracking && session.aligned, heading: session.heading)
                .frame(width: 160, height: 120)
                .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
        } else { floorMinimap }
    }

    private var mapControls: some View {
        HStack(spacing: 12) {
            Picker("Task placement", selection: Binding(get: { session.mapped }, set: { session.setMapped($0) })) {
                Text("Floor task").tag(false)
                Text("Preset map").tag(true)
            }.pickerStyle(.segmented).frame(width: 220)
                .accessibilityIdentifier("arWalking.mode")
            if session.mapped {
                Button("Map setup") { showingMapSetup = true }
                    .accessibilityIdentifier("arWalking.mapSetup")
                if session.aligned {
                    Picker("Task", selection: Binding(get: { session.selectedTaskID }, set: { session.selectTask($0) })) {
                        ForEach(session.layout.tasks) { task in Text(task.name).tag(task.id) }
                    }.tint(.yellow).accessibilityIdentifier("arWalking.settingTaskSelection")
                    Button("Rescan") { session.alignMap(); showingSettings = false }
                        .disabled(!session.tracking || (!session.simulated && !session.markerDetected))
                        .accessibilityIdentifier("arWalking.rescan")
                }
            }
        }
        .font(.caption).buttonStyle(.bordered)
        .padding(4).background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
    }

    private var floorMinimap: some View {
        VStack(spacing: 3) {
            Text("LOCAL MAP · 2 m GRID").font(.caption2.bold())
            Canvas { context, size in
                let origin = session.origin ?? .zero
                let player = (session.gate.position ?? origin) - origin
                let task = (session.gate.task ?? origin) - origin
                let extent = CGFloat(max(6, max(abs(player.x), abs(player.y), abs(task.x), abs(task.y)) + 2))
                let scale = min(size.width, size.height) / (2 * extent)
                func project(_ p: SIMD2<Float>) -> CGPoint {
                    CGPoint(x: size.width / 2 + CGFloat(p.x) * scale, y: size.height / 2 + CGFloat(p.y) * scale)
                }
                var grid = Path()
                for metres in stride(from: -Int(extent), through: Int(extent), by: 2) {
                    let x = size.width / 2 + CGFloat(metres) * scale
                    let y = size.height / 2 + CGFloat(metres) * scale
                    grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height))
                    grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(.white.opacity(0.16)), lineWidth: 1)
                let start = project(.zero)
                context.stroke(Path(ellipseIn: CGRect(x: start.x - 4, y: start.y - 4, width: 8, height: 8)),
                               with: .color(.white), lineWidth: 1)
                if session.gate.task != nil {
                    let centre = project(task)
                    let radius = CGFloat(NearbyTaskGate.interactionRadius) * scale
                    context.stroke(Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: 2 * radius, height: 2 * radius)),
                                   with: .color(.yellow.opacity(0.6)), lineWidth: 1)
                    context.fill(Path(ellipseIn: CGRect(x: centre.x - 5, y: centre.y - 5, width: 10, height: 10)),
                                 with: .color(session.completed ? .green : .yellow))
                }
                let centre = project(player)
                var arrow = Path()
                let angle = CGFloat(session.heading)
                for (index, p) in [CGPoint(x: 0, y: -9), CGPoint(x: -6, y: 7), CGPoint(x: 6, y: 7)].enumerated() {
                    let rotated = CGPoint(x: centre.x + p.x * cos(angle) - p.y * sin(angle),
                                          y: centre.y + p.x * sin(angle) + p.y * cos(angle))
                    if index == 0 { arrow.move(to: rotated) } else { arrow.addLine(to: rotated) }
                }
                arrow.closeSubpath()
                context.fill(arrow, with: .color(session.tracking ? .cyan : .gray))
            }
            .frame(width: 150, height: 100)
            Text(session.gate.nearby ? "Task nearby" : "YOU · cyan     TASK · yellow")
                .font(.caption2).foregroundStyle(session.gate.nearby ? .yellow : .white)
        }
        .padding(8).background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
    }

    private var simulationControls: some View {
        HStack {
            Button("Walk toward") { session.simulateWalk() }.accessibilityIdentifier("arWalking.walk")
            Button("Run past") { session.simulateRunPast() }.accessibilityIdentifier("arWalking.run")
            Button("Stop") { session.simulateStop() }.accessibilityIdentifier("arWalking.stop")
            Button(session.tracking ? "Lose tracking" : "Recover") {
                if session.tracking { session.simulateTrackingLoss() } else { session.simulateRecovery() }
            }.accessibilityIdentifier("arWalking.trackingToggle")
        }
        .font(.caption).buttonStyle(.bordered).background(.black.opacity(0.7), in: Capsule())
    }

    private var taskPanel: some View {
        VStack(spacing: 16) {
            Text(session.mapped ? (session.selectedTask?.name ?? "Nearby task") : "Nearby task").font(.title2.bold())
            Text("You stopped within 2 metres.\nTap the panel to complete this local test.")
                .multilineTextAlignment(.center)
            Button("Complete task") { session.completeTask() }
                .buttonStyle(.borderedProminent).tint(.green)
                .accessibilityIdentifier("arWalking.complete")
            Button("Close") { session.closeTask() }.buttonStyle(.bordered)
        }
        .padding(24).background(.black.opacity(0.95), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white, lineWidth: 2))
    }
}

private struct WalkingCamera: UIViewRepresentable {
    let session: ARWalkingSession

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.backgroundColor = .black
        view.clipsToBounds = true
        // Camera interaction uses HUD actions and raycasts, not SceneKit touch gestures.
        view.isUserInteractionEnabled = false
        session.attach(view)
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: ()) {
        uiView.session.pause()
        uiView.session.delegate = nil
    }
}
