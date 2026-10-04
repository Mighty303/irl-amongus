import SwiftUI

private enum LobbySettingsCategory: String, CaseIterable, Identifiable {
    case game = "Game", tasks = "Tasks", timers = "Timers", signs = "Signs", players = "Players", advanced = "Advanced"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .game: "gearshape.fill"
        case .tasks: "checklist"
        case .timers: "stopwatch"
        case .signs: "signpost.right"
        case .players: "person.2.fill"
        case .advanced: "wrench.and.screwdriver"
        }
    }
}

private enum LobbySettingsDestination: Hashable {
    case savedGames, diagnostics
}

/// Live lobby settings: changes still go straight to the server, with no separate Apply step.
struct LobbyView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let state: GameState
    var onClose: (() -> Void)? = nil
    @State private var category: LobbySettingsCategory = .game
    @State private var addingStation = false
    @State private var addingMySign = false
    @State private var qrStation: Station?
    @State private var showingSpecialSigns = false

    private var current: GameState { store.state ?? state }
    private static let accent = Color(red: 0.22, green: 0.63, blue: 0.62)
    private static let panel = Color(red: 0.045, green: 0.065, blue: 0.08)
    private static let well = Color(red: 0.075, green: 0.10, blue: 0.12)

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let landscape = geometry.size.width > geometry.size.height
                ZStack {
                    Color.black.opacity(0.8).ignoresSafeArea()
                    VStack(spacing: 8) {
                        header
                        if landscape {
                            HStack(alignment: .top, spacing: 12) {
                                sidebar.frame(width: geometry.size.width < 760 ? 116 : 154)
                                VStack(spacing: 8) {
                                    content(twoColumns: true)
                                    footer
                                }
                            }
                            .frame(maxHeight: .infinity)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(LobbySettingsCategory.allCases) { categoryButton($0) }
                                }
                            }
                            content(twoColumns: false)
                            footer
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: 1060, maxHeight: 620)
                    .foregroundStyle(.white)
                    .background(Self.panel, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.3), lineWidth: 1.5))
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LobbySettingsDestination.self) { destination in
                Group {
                    switch destination {
                    case .savedGames: GamesetsView()
                    case .diagnostics: DebugView()
                    }
                }
                .toolbar(.visible, for: .navigationBar)
            }
            .sheet(isPresented: $addingStation) { StationEditorView() }
            .fullScreenCover(isPresented: $showingSpecialSigns) {
                SpecialSignsView.lobby(store: store, stations: store.state?.stations ?? []) { showingSpecialSigns = false }
                    .presentationBackground(.clear)
            }
            .sheet(isPresented: $addingMySign) {
                StationEditorView(signOnly: true, title: "Sign \(current.mySigns.count + 1) of \(current.requiredSigns)",
                                  fallbackName: "Sign \(current.mySigns.count + 1)")
            }
            .sheet(item: $qrStation) { station in
                VStack(spacing: 16) {
                    Text(station.name).font(.title.bold())
                    QRCodeImage(payload: QRPayload.station(id: station.id).string, size: 220)
                    Text("Fallback check-in QR. Print it and tape it next to the sign.").font(.caption)
                    Button("Done") { qrStation = nil }.frame(minHeight: 44)
                }
                .padding()
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("settings.panel")
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("LOBBY SETTINGS")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 0) {
                Text("ROOM CODE").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                Text(current.code).font(.system(size: 17, weight: .bold, design: .monospaced))
            }
            Button {
                if let onClose { onClose() } else { dismiss() }
            } label: {
                Label("DONE", systemImage: "checkmark")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 16).frame(minHeight: 44)
            }
            .buttonStyle(SettingsActionStyle(filled: true))
            .accessibilityIdentifier("settings.done")
            .accessibilityLabel("Done with lobby settings")
            .opacity(onClose == nil ? 0 : 1)
            .disabled(onClose == nil)
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(spacing: 1) {
                ForEach(LobbySettingsCategory.allCases) { categoryButton($0) }
            }
        }
        .accessibilityIdentifier("settings.categories")
    }

    private func categoryButton(_ item: LobbySettingsCategory) -> some View {
        Button { category = item } label: {
            Label(item.rawValue, systemImage: item.icon)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 10)
                .contentShape(Rectangle())
                .background(category == item ? Self.accent.opacity(0.7) : .clear, in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.category.\(item.rawValue.lowercased())")
        .accessibilityAddTraits(category == item ? .isSelected : [])
    }

    private func content(twoColumns: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                switch category {
                case .game: gameSettings(twoColumns: twoColumns)
                case .tasks: taskSettings(twoColumns: twoColumns)
                case .timers: timerSettings(twoColumns: twoColumns)
                case .signs: signSettings
                case .players: playerSettings
                case .advanced: advancedSettings(twoColumns: twoColumns)
                }
            }
            .padding(2)
        }
        .id(category)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("settings.content")
    }

    private func columns(_ two: Bool) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6, alignment: .top), count: two ? 2 : 1)
    }

    private func gameSettings(twoColumns: Bool) -> some View {
        LazyVGrid(columns: columns(twoColumns), spacing: 6) {
            if current.settings.mapBuildingId != nil {
                settingCard("Play area") { PlayAreaPicker(state: current) }
            }
            integer("Impostors", \.impostors, "impostors", 1...3)
            integer("Minimum players", \.minPlayers, "minPlayers", 2...12)
            if store.demoModeEnabled {
                settingCard("Demo mode") { DemoSignsControl(state: current) }
            }
            if current.settings.signsPerPlayer != nil {
                let perPlayer = current.settings.signsPerPlayer ?? 0
                numberCard("Signs per player", value: "\(perPlayer)", key: "signsPerPlayer",
                           canDecrease: perPlayer > 0, canIncrease: perPlayer < 10,
                           decrease: { store.updateSetting("signsPerPlayer", perPlayer - 1) },
                           increase: { store.updateSetting("signsPerPlayer", perPlayer + 1) },
                           detail: current.gameset == nil ? nil : "The saved game's signs count toward this; players split the rest")
            }
            integer("Tasks per player", \.tasksPerPlayer, "tasksPerPlayer", 1...8)
            if current.isHost { // nobody else can see who it is, so nobody else picks it
                settingCard("Choose impostor") {
                    Picker("Choose impostor", selection: Binding(
                        get: { current.settings.forcedImpostorIds.first ?? "" },
                        set: { store.updateSetting("forcedImpostorIds", $0.isEmpty ? [String]() : [$0]) }
                    )) {
                        Text("Random").tag("")
                        ForEach(current.players) { Text($0.name).tag($0.id) }
                    }
                    .pickerStyle(.menu).tint(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 7))
                    .disabled(!store.isSynced)
                    .accessibilityIdentifier("settings.forcedImpostorIds")
                }
            }
            toggle("Anonymous votes", \.anonymousVotes, "anonymousVotes")
        }
    }

    private func taskSettings(twoColumns: Bool) -> some View {
        LazyVGrid(columns: columns(twoColumns), spacing: 6) {
            ForEach(TaskType.allCases) { type in
                settingCard(type.label) {
                    Toggle(type.label, isOn: Binding(
                        get: { current.settings.taskTypes.contains(type) },
                        set: { on in
                            var types = current.settings.taskTypes.filter { $0 != type && $0 != .unknown }
                            if on { types.append(type) }
                            store.updateSetting("taskTypes", types.map(\.rawValue))
                        }
                    ))
                    .labelsHidden().tint(Self.accent).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .disabled(!store.isSynced)
                    .accessibilityIdentifier("settings.task.\(type.rawValue)")
                }
            }
            toggle("Ghosts can do tasks", \.ghostTasks, "ghostTasks")
        }
    }

    private func timerSettings(twoColumns: Bool) -> some View {
        LazyVGrid(columns: columns(twoColumns), spacing: 6) {
            integer("Role reveal", \.roleRevealSec, "roleRevealSec", 3...60, unit: "s")
            integer("Gather for meeting", \.gatherTimeoutSec, "gatherTimeoutSec", 0...300, step: 15, unit: "s")
            integer("Discussion", \.discussionSec, "discussionSec", 0...300, step: 15, unit: "s")
            integer("Voting", \.votingSec, "votingSec", 10...300, step: 15, unit: "s")
            integer("Results screen", \.resultSec, "resultSec", 2...30, unit: "s")
            integer("Kill cooldown", \.killCooldownSec, "killCooldownSec", 0...120, step: 5, unit: "s")
            integer("Emergency cooldown", \.emergencyCooldownSec, "emergencyCooldownSec", 0...120, step: 5, unit: "s")
            integer("Sabotage cooldown", \.sabotageCooldownSec, "sabotageCooldownSec", 0...180, step: 5, unit: "s")
            integer("Reactor meltdown", \.reactorSec, "reactorSec", 15...180, step: 5, unit: "s")
            integer("Upload task", \.uploadSec, "uploadSec", 3...30, unit: "s")
        }
    }

    private var signSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSavedGameCard(state: current)
            if current.requiredSigns > 0 {
                settingCard("My signs · \(min(current.mySigns.count, current.requiredSigns))/\(current.requiredSigns)") {
                    ForEach(current.mySigns) { StationRow(station: $0) }
                    if current.mySigns.count < current.requiredSigns {
                        action("Add my next sign", icon: "camera") { addingMySign = true }
                    }
                }
            }
            settingCard("Special signs") {
                ForEach(SpecialSignSlot.all) { slot in
                    let station = slot.station(in: current.stations)
                    HStack(spacing: 8) {
                        Image(systemName: slot.kind.icon).foregroundStyle(POCPinStyle(slot.kind).color).frame(width: 22)
                        Text(slot.title).font(.system(size: 14, weight: .semibold, design: .rounded))
                        Spacer(minLength: 4)
                        Text(station != nil ? "Set" : slot.required ? "Required" : "Optional")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(station != nil ? .green : slot.required ? .red : .white.opacity(0.5))
                    }
                    .frame(minHeight: 30)
                }
                action("Set up special signs", icon: "light.beacon.max") { showingSpecialSigns = true }.disabled(!store.isSynced)
                Text("The red button is needed to start; meetings gather there too. Reactor (two signs) and Lights enable sabotages; Security and Admin are optional rooms.")
                    .font(.caption).foregroundStyle(.white.opacity(0.6))
            }
            settingCard("Venue · \(current.mapId) · \(current.stations.count) signs") {
                ForEach(current.stations) { station in
                    HStack {
                        StationRow(station: station)
                        Spacer(minLength: 4)
                        Button { qrStation = station } label: { Image(systemName: "qrcode").frame(width: 44, height: 44) }
                            .accessibilityLabel("QR for \(station.name)")
                        if current.isHost || station.addedBy == current.me.id {
                            Button(role: .destructive) {
                                Task { await store.perform("delete_station", ["stationId": station.id]) }
                            } label: { Image(systemName: "trash").frame(width: 44, height: 44) }
                            .disabled(!store.isSynced)
                            .accessibilityLabel("Delete \(station.name)")
                        }
                    }
                }
                if current.stations.isEmpty {
                    Text("No venue signs yet.").font(.caption).foregroundStyle(.white.opacity(0.6))
                }
                if current.isHost { action("Add venue sign", icon: "camera") { addingStation = true }.disabled(!store.isSynced) }
                Text("Photograph signs to create task stations. Add a meeting point so everyone knows where to gather.")
                    .font(.caption).foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private var playerSettings: some View {
        settingCard("Players · \(current.players.count)") {
            ForEach(current.players) { player in
                HStack(spacing: 8) {
                    Circle().fill(player.connected ? .green : .gray).frame(width: 8, height: 8)
                    Text(player.name + (player.id == current.me.id ? " (you)" : ""))
                    if player.isHost { Image(systemName: "crown.fill").foregroundStyle(.yellow) }
                    if player.isBot == true { Image(systemName: "cpu").foregroundStyle(.white.opacity(0.5)) }
                    Spacer()
                    if current.isHost && player.id != current.me.id {
                        Button("Kick", role: .destructive) { Task { await store.perform("kick", ["playerId": player.id]) } }
                            .frame(minWidth: 44, minHeight: 44).disabled(!store.isSynced)
                            .accessibilityLabel("Kick \(player.name)")
                    }
                }
                .font(.system(size: 14, weight: .medium, design: .rounded)).frame(minHeight: 44)
            }
            if current.isHost {
                action("Add bot", icon: "plus") { Task { await store.perform("add_bot") } }
                    .disabled(!store.isSynced).accessibilityIdentifier("settings.addBot")
                Text("Bots gather at meetings and vote skip. They never kill; choose a human impostor when testing.")
                    .font(.caption).foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private func advancedSettings(twoColumns: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: columns(twoColumns), spacing: 6) {
                distance("Kill distance", \.killDistanceM, "killDistanceM")
                distance("Report distance", \.reportDistanceM, "reportDistanceM")
                decimal("RSSI at 1 m", \.rssiAt1m, "rssiAt1m", -100...(-30), step: 1, format: "%.0f dBm")
                decimal("Indoor factor", \.pathLossExponent, "pathLossExponent", 1.5...4, step: 0.1, format: "%.1f")
                integer("Emergency meetings", \.emergencyMeetingsPerPlayer, "emergencyMeetingsPerPlayer", 0...5)
                toggle("Reveal role on ejection", \.revealRoleOnEject, "revealRoleOnEject")
                toggle("QR fallback", \.qrFallback, "qrFallback")
                toggle("Skip BLE proximity (dev)", \.devSkipProximity, "devSkipProximity")
                toggle("Skip checkpoints (dev)", \.devSkipCheckpoint, "devSkipCheckpoint")
            }
            Text("Bluetooth range is approximate. Use diagnostics to calibrate two phones 1 m apart; raise the indoor factor if kills trigger from too far away.")
                .font(.caption).foregroundStyle(.white.opacity(0.6))
            NavigationLink(value: LobbySettingsDestination.diagnostics) {
                Label("Diagnostics · Bluetooth / camera / GPS", systemImage: "waveform.path.ecg")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(SettingsActionStyle())
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Label(store.isSynced ? "Anyone can change settings · they sync with the lobby" : "Reconnecting · changes paused",
                  systemImage: store.isSynced ? "wifi" : "wifi.slash")
            Spacer(minLength: 0)
            if onClose == nil {
                Button("Leave lobby", role: .destructive) { store.leave() }.frame(minHeight: 44)
                if current.isHost {
                    Button("Start game") { Task { await store.perform("start_game") } }
                        .frame(minHeight: 44)
                        .disabled(!store.isSynced || current.players.count < current.settings.minPlayers || !current.playersMissingSigns.isEmpty)
                }
            } else {
                Text(current.requiredSigns > 0 ? "Add your \(current.requiredSigns) sign\(current.requiredSigns == 1 ? "" : "s") before start" : "No signs for you to add")
            }
        }
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.6))
        .lineLimit(1).minimumScaleFactor(0.8)
    }

    private func settingCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 14, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.75)
            content()
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Self.well, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func numberCard(_ title: String, value: String, key: String, canDecrease: Bool, canIncrease: Bool,
                            decrease: @escaping () -> Void, increase: @escaping () -> Void, detail: String? = nil) -> some View {
        settingCard(title) {
            HStack(spacing: 6) {
                Button(action: decrease) { Image(systemName: "minus").frame(width: 44, height: 44) }
                    .buttonStyle(SettingsActionStyle()).disabled(!canDecrease || !store.isSynced)
                    .accessibilityLabel("Decrease \(title)").accessibilityIdentifier("settings.\(key).decrease")
                Text(value).font(.system(size: 20, weight: .heavy, design: .rounded))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .accessibilityIdentifier("settings.\(key).value")
                Button(action: increase) { Image(systemName: "plus").frame(width: 44, height: 44) }
                    .buttonStyle(SettingsActionStyle(filled: true)).disabled(!canIncrease || !store.isSynced)
                    .accessibilityLabel("Increase \(title)").accessibilityIdentifier("settings.\(key).increase")
            }
            if let detail {
                Text(detail).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private func integer(_ title: String, _ path: KeyPath<Settings, Int>, _ key: String, _ range: ClosedRange<Int>, step: Int = 1, unit: String = "") -> some View {
        let value = current.settings[keyPath: path]
        return numberCard(title, value: "\(value)\(unit)", key: key,
                          canDecrease: value > range.lowerBound, canIncrease: value < range.upperBound,
                          decrease: { store.updateSetting(key, max(range.lowerBound, value - step)) },
                          increase: { store.updateSetting(key, min(range.upperBound, value + step)) })
    }

    private func decimal(_ title: String, _ path: KeyPath<Settings, Double>, _ key: String, _ range: ClosedRange<Double>, step: Double, format: String) -> some View {
        let value = current.settings[keyPath: path]
        return numberCard(title, value: String(format: format, value), key: key,
                          canDecrease: value > range.lowerBound, canIncrease: value < range.upperBound,
                          decrease: { store.updateSetting(key, (max(range.lowerBound, value - step) * 10).rounded() / 10) },
                          increase: { store.updateSetting(key, (min(range.upperBound, value + step) * 10).rounded() / 10) })
    }

    private func distance(_ title: String, _ path: KeyPath<Settings, Double>, _ key: String) -> some View {
        let value = current.settings[keyPath: path]
        return numberCard(title, value: String(format: "~%.1f m", value), key: key,
                          canDecrease: value >= 0.5, canIncrease: true,
                          decrease: { store.updateSetting(key, max(0, value - 0.5)) },
                          increase: { store.updateSetting(key, value + 0.5) },
                          detail: "Signal threshold: ≥ \(Int(BLEDistance.rssi(atMeters: value, rssiAt1m: current.settings.rssiAt1m, exponent: current.settings.pathLossExponent).rounded())) dBm")
    }

    private func toggle(_ title: String, _ path: KeyPath<Settings, Bool>, _ key: String) -> some View {
        settingCard(title) {
            Toggle(title, isOn: Binding(get: { current.settings[keyPath: path] }, set: { store.updateSetting(key, $0) }))
                .labelsHidden().tint(Self.accent).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .disabled(!store.isSynced)
                .accessibilityLabel(title).accessibilityIdentifier("settings.\(key)")
        }
    }

    private func action(_ title: String, icon: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Label(title, systemImage: icon).font(.system(size: 14, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(SettingsActionStyle())
    }
}

private struct SettingsActionStyle: ButtonStyle {
    var filled = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white.opacity(enabled ? 1 : 0.35))
            .background(filled ? Color(red: 0.18, green: 0.50, blue: 0.50) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(filled ? 0.4 : 0.2), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
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


/// Keep saved-game selection alongside sign management, with the existing server API.
private struct SettingsSavedGameCard: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var games: [GameStore.GamesetSummary] = []
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SAVED GAME").font(.system(size: 14, weight: .bold, design: .rounded))
            Picker("Saved game", selection: Binding(
                get: { state.gameset?.id ?? "" },
                set: { id in
                    busy = true
                    Task { await store.useGameset(id.isEmpty ? nil : id); busy = false }
                }
            )) {
                Text("None · players photograph signs").tag("")
                ForEach(games) { Text("\($0.name) · \($0.signs) signs").tag($0.id) }
                if let current = state.gameset, !games.contains(where: { $0.id == current.id }) {
                    Text(current.name).tag(current.id)
                }
            }
            .pickerStyle(.menu).tint(.white).frame(minHeight: 44)
            .disabled(busy || !store.isSynced)
            NavigationLink(value: LobbySettingsDestination.savedGames) {
                Label("Manage saved games", systemImage: "folder")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(SettingsActionStyle())
            Text(state.gameset.map { "Using “\($0.name)”. Per-player sign requirements are off." }
                 ?? "Choose a saved game to reuse photographed signs, or None to have players add their own.")
                .font(.caption).foregroundStyle(.white.opacity(0.6))
        }
        .padding(10)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
        .task { games = (try? await store.gamesets()) ?? [] }
    }
}

/// Which SFU building and floor the game is on. The maps show that floor, positions assume it, and new
/// signs default to it. Anyone in the lobby can change it.
private struct PlayAreaPicker: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    private var building: CampusBuilding? { store.campus.building(state.playArea?.buildingId) }

    var body: some View {
        let buildings = store.campus.buildings.sorted { $0.name < $1.name }
        VStack(alignment: .leading, spacing: 4) {
            Picker("Building", selection: Binding(
                get: { state.playArea?.buildingId ?? "" },
                set: { id in
                    // A new building starts on its main floor.
                    let floor = store.campus.building(id)?.mainFloor.id ?? ""
                    Task { await store.perform("update_settings", ["mapBuildingId": id, "mapFloorId": id.isEmpty ? "" : floor]) }
                }
            )) {
                Text("Not set").tag("")
                ForEach(buildings) { Text("\($0.name) (\($0.id))").tag($0.id) }
            }
            .pickerStyle(.menu).tint(.white)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 7))
            .accessibilityIdentifier("settings.mapBuildingId")
            if let building {
                Picker("Floor", selection: Binding(
                    get: { state.playArea?.floorId ?? building.mainFloor.id },
                    set: { store.updateSetting("mapFloorId", $0) }
                )) {
                    // Top floor first, like a building directory.
                    ForEach(building.floors.reversed()) { Text($0.name).tag($0.id) }
                }
                .pickerStyle(.menu).tint(.white)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 7))
                .accessibilityIdentifier("settings.mapFloorId")
            }
            Text(store.campus.isFullCampus ? "Maps open on this floor." : "Downloading the SFU campus… (SUB only for now)")
                .font(.caption2).foregroundStyle(.white.opacity(0.6))
        }
        .disabled(!store.isSynced)
    }
}
