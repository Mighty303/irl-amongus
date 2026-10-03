import SwiftUI

/// Main play screen. Crewmate and impostor screens are deliberately identical at a glance;
/// the impostor-only kill button appears only when the server says a target is in range.
struct PlayingView: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    @State private var scanningCheckpoint = false
    @State private var scanningPlayer = false
    @State private var showingMyQR = false
    @State private var showingMap = false
    @State private var activeTask: GameTask?
    @State private var peekRole = false

    private var me: Me { state.me }
    private var isImpostor: Bool { me.role == .impostor }
    private var lightsOut: Bool { state.sabotage?.kind == "lights" && !isImpostor && me.alive }

    var body: some View {
        NavigationStack {
            List {
                if !me.alive {
                    Section {
                        Text("👻 You are a ghost").font(.title2.bold())
                        Text(state.settings.ghostTasks ? "Keep doing tasks to help the crew. You can't vote, report, or talk about the game." : "You can't vote, report, or talk about the game.")
                            .font(.caption)
                    }
                }

                if let sabotage = state.sabotage { SabotageSection(state: state, sabotage: sabotage) }

                if let bodyId = me.nearbyBodies.first, let body = state.player(bodyId) {
                    Section {
                        Button {
                            Task { await store.perform("report_body", ["bodyId": bodyId]) }
                        } label: {
                            Text("💀 REPORT \(body.name.uppercased())'S BODY")
                                .font(.title2.weight(.black)).frame(maxWidth: .infinity).padding()
                        }
                        .buttonStyle(.borderedProminent).tint(.red)
                    }
                }

                if isImpostor && me.alive { KillSection(state: state) }

                Section("Crew task progress") {
                    ProgressView(value: state.taskProgress.fraction)
                    Text("\(state.taskProgress.done) / \(state.taskProgress.total) tasks").font(.caption)
                }

                Section {
                    Button("📷 Scan station sign") { scanningCheckpoint = true }.font(.headline)
                    if let cp = me.lastCheckpoint, let station = state.station(cp.stationId) {
                        Text("Last check-in: \(station.name) · \(Date(timeIntervalSince1970: cp.at / 1000).formatted(date: .omitted, time: .shortened)) via \(cp.method)")
                            .font(.caption)
                    } else {
                        Text("Not checked in anywhere yet").font(.caption).foregroundStyle(.secondary)
                    }
                    Button("🗺 Mini-map") { showingMap = true }
                    if me.alive, isAtEmergencyStation {
                        Button("🚨 Call emergency meeting (\(me.emergencyLeft) left)") {
                            Task { await store.perform("call_emergency") }
                        }
                        .foregroundStyle(.red)
                        .disabled(me.emergencyLeft == 0)
                    }
                }

                Section(isImpostor ? "Tasks (fake: pretend to do these)" : "Your tasks") {
                    ForEach(me.tasks) { task in
                        Button { activeTask = task } label: { TaskRow(state: state, task: task) }
                            .disabled(task.completed)
                    }
                }

                Section {
                    if state.settings.qrFallback {
                        Button("Show my player QR") { showingMyQR = true }
                        Button("Scan a player QR") { scanningPlayer = true }
                    }
                    if isImpostor { SabotageButtons(state: state) }
                    NavigationLink("Diagnostics") { DebugView() }
                    if state.isHost {
                        Button("Host: end game / back to lobby", role: .destructive) { Task { await store.perform("restart") } }
                    }
                } footer: {
                    Text("Hold the eye button to peek at your role.")
                }
            }
            .navigationTitle("IRL Among Us")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: peekRole ? "eye.fill" : "eye.slash")
                        .onLongPressGesture(minimumDuration: 0.2, pressing: { peekRole = $0 }, perform: {})
                }
                ToolbarItem(placement: .topBarLeading) {
                    if peekRole {
                        Text(me.role == .impostor ? "IMPOSTOR" : "CREWMATE").font(.caption.bold())
                            .foregroundStyle(me.role == .impostor ? .red : .cyan)
                    }
                }
            }
            .overlay {
                if lightsOut {
                    // Lights sabotage: crewmate screens go mostly dark until someone fixes Electrical.
                    Color.black.opacity(0.88).ignoresSafeArea().allowsHitTesting(false)
                        .overlay(Text("💡 Lights out. Fix at Electrical").foregroundStyle(.white.opacity(0.6)).allowsHitTesting(false))
                }
            }
            .sheet(isPresented: $scanningCheckpoint) { CheckpointScannerView(state: state) }
            .sheet(item: $activeTask) { task in TaskSheet(task: task) }
            .sheet(isPresented: $showingMap) { MiniMapView(state: state) }
            .sheet(isPresented: $showingMyQR) {
                VStack(spacing: 16) {
                    Text(me.name).font(.title.bold())
                    QRCodeImage(payload: QRPayload.player(qrToken: me.qrToken).string, size: 260)
                    Text("Fallback when Bluetooth is unreliable").font(.caption)
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $scanningPlayer) {
                QRScanSheet(title: "Scan player QR") { payload in
                    guard case let .player(token)? = QRPayload(payload) else { return }
                    scanningPlayer = false
                    Task { await store.handlePlayerQR(token) }
                }
            }
        }
    }

    private var isAtEmergencyStation: Bool {
        guard let cp = me.lastCheckpoint, state.station(cp.stationId)?.kind == .emergency else {
            return state.settings.devSkipCheckpoint && state.stations.contains { $0.kind == .emergency }
        }
        return store.serverNow() - cp.at < Double(state.settings.checkpointTtlSec) * 1000
    }
}

struct TaskRow: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let task: GameTask

    var body: some View {
        HStack {
            Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(task.completed ? .green : .secondary)
            VStack(alignment: .leading) {
                Text(title).foregroundStyle(.primary)
                if let station = state.station(task.currentStationId) {
                    let distance = store.location.distance(to: station).map { " · \(SignGuide.format($0))" } ?? ""
                    Text("📍 \(station.name)\(distance)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var title: String {
        guard task.type == .delivery else { return task.type.label }
        return task.step == 0 ? "Delivery: pick up package" : "Delivery: drop off package"
    }
}

private struct KillSection: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let targets = state.me.killTargets.compactMap { state.player($0) }
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let cooldown = store.secondsUntil(state.me.killCooldownUntil) ?? 0
            if !targets.isEmpty && cooldown == 0 {
                Section {
                    ForEach(targets) { t in
                        // Discreet: looks like an ordinary list row.
                        Button("Kill \(t.name)") { Task { await store.perform("kill", ["targetId": t.id]) } }
                            .foregroundStyle(.primary)
                    }
                }
            } else if cooldown > 0 {
                Section { Text("cd \(cooldown)s").font(.caption2).foregroundStyle(.tertiary) }
            }
        }
    }
}

private struct SabotageButtons: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let cooldown = store.secondsUntil(state.me.sabotageAvailableAt) ?? 0
            Menu(cooldown > 0 ? "Sabotage (\(cooldown)s)" : "Sabotage") {
                Button("☢️ Reactor") { Task { await store.perform("sabotage", ["kind": "reactor"]) } }
                Button("💡 Lights") { Task { await store.perform("sabotage", ["kind": "lights"]) } }
            }
            .disabled(cooldown > 0 || state.sabotage != nil)
        }
    }
}

private struct SabotageSection: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let sabotage: SabotageView

    var body: some View {
        Section {
            HStack {
                Text(sabotage.kind == "reactor" ? "☢️ REACTOR MELTDOWN" : "💡 LIGHTS SABOTAGED").font(.headline)
                Spacer()
                if sabotage.deadline != nil { Countdown(deadline: sabotage.deadline, font: .title2.monospaced().bold()) }
            }
            ForEach(sabotage.stations, id: \.stationId) { fix in
                let station = state.station(fix.stationId)
                HStack {
                    Text("\(fix.active ? "✅" : "❌") \(station?.name ?? "?")")
                    Spacer()
                    if state.me.alive, state.me.lastCheckpoint?.stationId == fix.stationId || state.settings.devSkipCheckpoint {
                        Button(sabotage.kind == "reactor" ? "Activate" : "Fix lights") {
                            Task { await store.perform("fix_sabotage", ["stationId": fix.stationId]) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            if sabotage.kind == "reactor" {
                Text("Both stations must be activated within \(state.settings.reactorWindowSec)s of each other. Scan the sign at a reactor first.")
                    .font(.caption)
            }
        }
        .listRowBackground(Color.orange.opacity(0.25))
    }
}
