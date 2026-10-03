import SwiftUI

struct LobbyView: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var addingStation = false
    @State private var qrStation: Station?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        Text(state.code).font(.system(size: 56, weight: .black, design: .monospaced))
                        QRCodeImage(payload: QRPayload.join(code: state.code, server: store.serverURLString).string, size: 180)
                        Text("Scan in the IRL Among Us app or the iPhone Camera").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                Section {
                    ForEach(state.players) { p in
                        HStack {
                            Circle().fill(p.connected ? .green : .gray).frame(width: 8, height: 8)
                            Text(p.name + (p.id == state.me.id ? " (you)" : ""))
                            if p.isHost { Image(systemName: "crown.fill").foregroundStyle(.yellow) }
                            if p.isBot == true { Image(systemName: "cpu").foregroundStyle(.secondary) }
                            Spacer()
                            if state.isHost && p.id != state.me.id {
                                Button("Kick", role: .destructive) { Task { await store.perform("kick", ["playerId": p.id]) } }
                                    .buttonStyle(.borderless)
                            }
                        }
                    }
                    if state.isHost {
                        Button("Add bot") { Task { await store.perform("add_bot") } }
                    }
                } header: {
                    Text("Players (\(state.players.count))")
                } footer: {
                    if state.isHost {
                        Text("Bots acknowledge their role, gather at meetings and vote skip. They never kill, so pick a human impostor in the settings below.")
                    }
                }

                Section {
                    ForEach(state.stations) { s in
                        StationRow(station: s)
                            .swipeActions {
                                if state.isHost {
                                    Button("Delete", role: .destructive) { Task { await store.perform("delete_station", ["stationId": s.id]) } }
                                }
                                Button("QR") { qrStation = s }
                            }
                    }
                    if state.isHost { Button("Add a sign (photograph it)") { addingStation = true } }
                } header: {
                    Text("Map: \(state.mapId) · \(state.stations.count) signs")
                } footer: {
                    Text("Signs are saved on the server, so you set up a venue once. Each game assigns random tasks to the \"Sign (tasks)\" signs; add a meeting point so meetings wait for everyone to gather. Swipe for the fallback QR.")
                }

                if state.isHost {
                    SettingsSection(settings: state.settings, players: state.players)
                    Section {
                        Button("Start game") { Task { await store.perform("start_game") } }
                            .font(.headline)
                    }
                } else {
                    Section { Text("Waiting for the host to start…").foregroundStyle(.secondary) }
                }

                Section {
                    NavigationLink("Diagnostics (BLE / camera / GPS)") { DebugView() }
                    Button("Leave lobby", role: .destructive) { store.leave() }
                }
            }
            .navigationTitle("Lobby")
            .sheet(isPresented: $addingStation) { StationEditorView() }
            .sheet(item: $qrStation) { s in
                VStack(spacing: 16) {
                    Text(s.name).font(.title.bold())
                    QRCodeImage(payload: QRPayload.station(id: s.id).string, size: 260)
                    Text("Fallback check-in QR. Print it and tape it next to the sign.").font(.caption)
                }
                .presentationDetents([.medium])
            }
        }
    }
}

struct StationRow: View {
    @Environment(GameStore.self) private var store
    let station: Station

    var body: some View {
        HStack {
            if let photoId = station.photoId, let base = store.serverURL {
                AsyncImage(url: base.appendingPathComponent("photos/\(photoId).jpg")) { image in
                    image.resizable().scaledToFill()
                } placeholder: { Color.gray.opacity(0.3) }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            VStack(alignment: .leading) {
                Text(station.name).font(.headline)
                Text([station.kind.label, station.lat != nil ? "GPS" : nil, station.signText.map { "“\($0)”" }]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct SettingsSection: View {
    @Environment(GameStore.self) private var store
    let settings: Settings
    let players: [PlayerView]

    var body: some View {
        Section("Players & tasks") {
            stepper("Impostors", \.impostors, "impostors", 1...3)
            Picker("Impostor", selection: Binding(
                get: { settings.forcedImpostorIds.first ?? "" },
                set: { store.updateSetting("forcedImpostorIds", $0.isEmpty ? [String]() : [$0]) }
            )) {
                Text("Random").tag("")
                ForEach(players) { Text($0.name).tag($0.id) }
            }
            stepper("Min players", \.minPlayers, "minPlayers", 2...12)
            stepper("Tasks per player", \.tasksPerPlayer, "tasksPerPlayer", 1...8)
            ForEach(TaskType.allCases) { type in
                Toggle(type.label, isOn: Binding(
                    get: { settings.taskTypes.contains(type) },
                    set: { on in
                        var types = settings.taskTypes.filter { $0 != type }
                        if on { types.append(type) }
                        store.updateSetting("taskTypes", types.map(\.rawValue))
                    }
                ))
            }
        }
        Section {
            meters("Kill distance", \.killDistanceM, "killDistanceM")
            meters("Report distance", \.reportDistanceM, "reportDistanceM")
            Stepper("RSSI at 1 m: \(Int(settings.rssiAt1m)) dBm",
                    value: Binding(get: { settings.rssiAt1m }, set: { store.updateSetting("rssiAt1m", $0.rounded()) }),
                    in: -100...(-30), step: 1)
            Stepper(String(format: "Indoor factor: %.1f", settings.pathLossExponent),
                    value: Binding(get: { settings.pathLossExponent },
                                   set: { store.updateSetting("pathLossExponent", ($0 * 10).rounded() / 10) }),
                    in: 1.5...4, step: 0.1)
        } header: {
            Text("Bluetooth range")
        } footer: {
            Text("Approximate: phones only measure signal strength. Calibrate \"RSSI at 1 m\" with the Bluetooth proximity test (Developer Mode) and two phones 1 m apart. Raise the indoor factor if kills trigger from too far away.")
        }
        Section("Timers (seconds)") {
            stepper("Role reveal", \.roleRevealSec, "roleRevealSec", 3...60, step: 1)
            stepper("Gather for meeting", \.gatherTimeoutSec, "gatherTimeoutSec", 0...300, step: 15)
            stepper("Discussion", \.discussionSec, "discussionSec", 0...300, step: 15)
            stepper("Voting", \.votingSec, "votingSec", 10...300, step: 15)
            stepper("Results screen", \.resultSec, "resultSec", 2...30, step: 1)
            stepper("Kill cooldown", \.killCooldownSec, "killCooldownSec", 0...120, step: 5)
            stepper("Emergency cooldown", \.emergencyCooldownSec, "emergencyCooldownSec", 0...120, step: 5)
            stepper("Sabotage cooldown", \.sabotageCooldownSec, "sabotageCooldownSec", 0...180, step: 5)
            stepper("Reactor meltdown", \.reactorSec, "reactorSec", 15...180, step: 5)
            stepper("Upload task", \.uploadSec, "uploadSec", 3...30, step: 1)
        }
        Section("Rules") {
            stepper("Emergency meetings", \.emergencyMeetingsPerPlayer, "emergencyMeetingsPerPlayer", 0...5)
            toggle("Anonymous votes", \.anonymousVotes, "anonymousVotes")
            toggle("Reveal role on ejection", \.revealRoleOnEject, "revealRoleOnEject")
            toggle("Player/station QR fallback", \.qrFallback, "qrFallback")
            toggle("Ghosts can do tasks", \.ghostTasks, "ghostTasks")
            toggle("DEV: skip BLE proximity", \.devSkipProximity, "devSkipProximity")
            toggle("DEV: skip checkpoint check", \.devSkipCheckpoint, "devSkipCheckpoint")
        }
    }

    private func stepper(_ label: String, _ path: KeyPath<Settings, Int>, _ key: String, _ range: ClosedRange<Int>, step: Int = 1) -> some View {
        Stepper("\(label): \(settings[keyPath: path])",
                value: Binding(get: { settings[keyPath: path] }, set: { store.updateSetting(key, $0) }),
                in: range, step: step)
    }

    private func meters(_ label: String, _ path: KeyPath<Settings, Double>, _ key: String) -> some View {
        let dbm = BLEDistance.rssi(atMeters: settings[keyPath: path], rssiAt1m: settings.rssiAt1m, exponent: settings.pathLossExponent)
        return Stepper(String(format: "%@: ~%.1f m (≥ %d dBm)", label, settings[keyPath: path], Int(dbm.rounded())),
                       value: Binding(get: { settings[keyPath: path] }, set: { store.updateSetting(key, $0) }),
                       in: 0.5...15, step: 0.5)
    }

    private func toggle(_ label: String, _ path: KeyPath<Settings, Bool>, _ key: String) -> some View {
        Toggle(label, isOn: Binding(get: { settings[keyPath: path] }, set: { store.updateSetting(key, $0) }))
    }
}
