import ARKit
import SwiftUI

struct ARWalkingPOCView: View {
    @State private var session = ARWalkingSession()
    @State private var showingMapSetup = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if !session.simulated {
                WalkingCamera(session: session).ignoresSafeArea()
            } else {
                LinearGradient(colors: [.gray.opacity(0.3), .black], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            }
            VStack(spacing: 6) {
                header
                Spacer(minLength: 0)
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 16) {
                    minimap
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom, spacing: 10) {
                        diagnostics
                        actions
                    }
                }
                mapControls
                if session.simulated { simulationControls }
                Text(session.simulated ? "SIMULATION · synthetic movement, not a camera accuracy test"
                     : (session.mapped ? "Measured-map POC · rescan the fixed marker to correct alignment" : "One-room POC · keep the camera facing ahead · task positions are local to this session"))
                    .font(.caption2).foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.black.opacity(0.7), in: Capsule())
            }
            .padding(12)
            if session.gate.task == nil {
                Image(systemName: "plus").font(.system(size: 32, weight: .light))
                    .allowsHitTesting(false)
            }
            if session.taskOpen { taskPanel }
        }
        .foregroundStyle(.white)
        .sheet(isPresented: $showingMapSetup) {
            ARMapSetupView(layout: session.layout, save: { session.applyLayout($0) })
        }
        .onAppear { OrientationDelegate.requestLandscape() }
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
            VStack(alignment: .leading, spacing: 4) {
                Text("TOTAL TASKS").font(.caption2.bold())
                ProgressView(value: Double(session.completedCount), total: session.mapped ? 3 : 1).tint(.green).frame(width: 110)
            }
            .padding(10).background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
            Text(session.status)
                .font(.callout.bold()).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(10)
                .background((session.tracking ? Color.black : Color.orange).opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier("arWalking.status")
            Button("Reset") { session.reset() }.buttonStyle(.bordered)
                .accessibilityIdentifier("arWalking.reset")
            if !session.simulated {
                Button("Simulation") { session.simulate() }.buttonStyle(.bordered)
                    .accessibilityIdentifier("arWalking.simulation")
            }
        }
    }

    private var diagnostics: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if let distance = session.gate.distance {
                Text(String(format: "Task · %.1f m", distance))
                    .accessibilityIdentifier("arWalking.distance")
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
                          completed: session.completedTasks, tracking: session.tracking && session.aligned)
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
                    }.tint(.yellow).accessibilityIdentifier("arWalking.taskSelection")
                    Button("Rescan") { session.alignMap() }
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
        session.attach(view)
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: ()) {
        uiView.session.pause()
        uiView.session.delegate = nil
    }
}
