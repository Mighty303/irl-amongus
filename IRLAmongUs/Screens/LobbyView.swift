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

                Section("Players (\(state.players.count))") {
                    ForEach(state.players) { p in
                        HStack {
                            Circle().fill(p.connected ? .green : .gray).frame(width: 8, height: 8)
                            Text(p.name + (p.id == state.me.id ? " (you)" : ""))
                            if p.isHost { Image(systemName: "crown.fill").foregroundStyle(.yellow) }
                            Spacer()
                            if state.isHost && p.id != state.me.id {
                                Button("Kick", role: .destructive) { Task { await store.perform("kick", ["playerId": p.id]) } }
                                    .buttonStyle(.borderless)
                            }
                        }
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
                    if state.isHost { Button("Add station (photograph a sign)") { addingStation = true } }
                } header: {
                    Text("Map: \(state.mapId) · \(state.stations.count) stations")
                } footer: {
                    Text("Stations persist on the server, so you only set up a venue once. Needs ≥1 task station. Add a meeting station so meetings wait for everyone to gather. Swipe for the fallback QR.")
                }

                if state.isHost {
                    SettingsSection(settings: state.settings)
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
                Text([station.kind.rawValue, station.taskType?.rawValue, station.lat != nil ? "GPS" : nil, station.signText.map { "“\($0)”" }]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct SettingsSection: View {
    @Environment(GameStore.self) private var store
    let settings: Settings

    var body: some View {
        Section("Host settings") {
            stepper("Impostors", \.impostors, "impostors", 1...3)
            stepper("Min players", \.minPlayers, "minPlayers", 2...12)
            stepper("Tasks per player", \.tasksPerPlayer, "tasksPerPlayer", 1...8)
            stepper("Kill cooldown (s)", \.killCooldownSec, "killCooldownSec", 0...120, step: 5)
            stepper("Discussion (s)", \.discussionSec, "discussionSec", 0...300, step: 15)
            stepper("Voting (s)", \.votingSec, "votingSec", 10...300, step: 15)
            stepper("Emergency meetings", \.emergencyMeetingsPerPlayer, "emergencyMeetingsPerPlayer", 0...5)
            stepper("Kill RSSI ≥ (dBm)", \.killRssiThreshold, "killRssiThreshold", -100...(-30))
            stepper("Report RSSI ≥ (dBm)", \.reportRssiThreshold, "reportRssiThreshold", -100...(-30))
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

    private func toggle(_ label: String, _ path: KeyPath<Settings, Bool>, _ key: String) -> some View {
        Toggle(label, isOn: Binding(get: { settings[keyPath: path] }, set: { store.updateSetting(key, $0) }))
    }
}
