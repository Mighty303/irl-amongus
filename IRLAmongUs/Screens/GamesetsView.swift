import PhotosUI
import SwiftUI

/// Settings from the main menu: saved games for demos, and how this phone finds its position.
struct AppSettingsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            List {
                Section {
                    Picker("Position", selection: $store.positionMode) {
                        ForEach(PositionMode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("settings.positionMode")
                } header: {
                    Text("Your position on the map")
                } footer: {
                    Text(store.positionMode.detail + " Applies on this phone only; switch any time, even mid-game, to compare.")
                }
                Section {
                    NavigationLink {
                        GamesetsView()
                    } label: {
                        Label("Games", systemImage: "square.stack.3d.up.fill")
                    }
                    .accessibilityIdentifier("settings.games")
                } footer: {
                    Text("Saved games are sets of signs photographed ahead of time, so a demo can start with no setup.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
        .preferredColorScheme(.dark)
    }
}

/// Saved games on the server. Anyone can browse; creating and editing need the team password.
struct GamesetsView: View {
    @Environment(GameStore.self) private var store
    @State private var games: [GameStore.GamesetSummary] = []
    @State private var loaded = false
    @State private var askingPassword = false
    @State private var afterUnlock: (() -> Void)?
    @State private var naming = false
    @State private var newName = ""

    var body: some View {
        List {
            Section {
                ForEach(games) { game in
                    NavigationLink {
                        GamesetDetailView(gamesetId: game.id, initialName: game.name)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(game.name).font(.headline)
                            Text("\(game.signs) signs · updated \(Date(timeIntervalSince1970: game.updatedAt / 1000).formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { games[$0].id }
                    whenUnlocked {
                        Task {
                            for id in ids { await store.editGamesets("gamesets/\(id)/delete") }
                            await refresh()
                        }
                    }
                }
                if loaded && games.isEmpty {
                    Text("No saved games yet. Tap + to make one.").foregroundStyle(.secondary)
                }
            } footer: {
                Text("The host picks a saved game in the lobby's settings to use its signs. Creating and editing games needs the team password.")
            }
        }
        .navigationTitle("Games")
        .toolbar {
            Button { whenUnlocked { naming = true } } label: { Label("New game", systemImage: "plus") }
                .accessibilityIdentifier("games.new")
        }
        .alert("New game", isPresented: $naming) {
            TextField("Name, e.g. SUB demo", text: $newName)
            Button("Create") { create() }
            Button("Cancel", role: .cancel) { newName = "" }
        }
        .gamesetPasswordPrompt(isPresented: $askingPassword) { afterUnlock?(); afterUnlock = nil }
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    private func whenUnlocked(_ action: @escaping () -> Void) {
        if store.canEditGamesets { action() } else { afterUnlock = action; askingPassword = true }
    }

    private func refresh() async {
        games = (try? await store.gamesets()) ?? games
        loaded = true
    }

    private func create() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        newName = ""
        guard !name.isEmpty else { return }
        Task {
            await store.editGamesets("gamesets", ["name": name])
            await refresh()
        }
    }
}

/// One saved game's signs: add by camera or import several from Photos (using each photo's saved location).
struct GamesetDetailView: View {
    @Environment(GameStore.self) private var store
    let gamesetId: String
    let initialName: String

    @State private var gameset: GameStore.Gameset?
    @State private var adding = false
    @State private var addingSpecial = false
    @State private var importItems: [PhotosPickerItem] = []
    @State private var importProgress: (done: Int, total: Int)?
    @State private var askingPassword = false
    @State private var afterUnlock: (() -> Void)?
    @State private var moving: Station?

    private var stations: [Station] { gameset?.stations ?? [] }
    private var signCount: Int { stations.filter { $0.kind == .task }.count }

    var body: some View {
        List {
            Section {
                ForEach(stations) { station in
                    Button { whenUnlocked { moving = station } } label: {
                        HStack(spacing: 12) {
                            Color(white: 0.2)
                                .overlay {
                                    if let photoId = station.photoId, let base = store.serverURL {
                                        AsyncImage(url: base.appendingPathComponent("photos/\(photoId).jpg")) { $0.resizable().scaledToFill() }
                                            placeholder: { ProgressView() }
                                    }
                                }
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(station.signText.map { "Reads “\($0)”" } ?? station.name).font(.headline).lineLimit(1)
                                Text([station.kind == .task ? nil : station.kind.label, pinLabel(station)]
                                    .compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(station.lat == nil ? Color.orange : Color.secondary)
                            }
                            Spacer()
                            Image(systemName: "mappin.and.ellipse").foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .accessibilityHint("Move this sign's map pin and floor")
                }
                .onDelete { offsets in
                    let ids = offsets.map { stations[$0].id }
                    whenUnlocked {
                        Task {
                            for id in ids { await store.editGamesets("gamesets/\(gamesetId)/stations/\(id)/delete") }
                            await refresh()
                        }
                    }
                }
                if gameset != nil && stations.isEmpty {
                    Text("No signs yet.").foregroundStyle(.secondary)
                }
            } header: {
                Text("\(signCount) signs")
            } footer: {
                Text("Tap a sign to move its pin or change its floor. Players are placed on the map at a sign's pin when they scan it, so put each pin exactly on its sign. Lobbies already using this game pick up the change when the host selects it again.")
            }

            Section {
                if store.canEditGamesets {
                    Button { adding = true } label: { Label("Take a photo of a sign", systemImage: "camera.fill") }
                    PhotosPicker(selection: $importItems, maxSelectionCount: 30, matching: .images) {
                        Label("Import from Photos", systemImage: "photo.stack")
                    }
                    .disabled(importProgress != nil)
                    if let importProgress {
                        ProgressView("Importing \(importProgress.done) of \(importProgress.total)…",
                                     value: Double(importProgress.done), total: Double(importProgress.total))
                    }
                } else {
                    Button { askingPassword = true } label: { Label("Unlock to add signs", systemImage: "lock.fill") }
                }
            } footer: {
                Text("Imported photos use the location saved in each photo (taken with Location on), so pins land where the sign is. Photos without one are added without a map pin. The app reads each sign's text for you.")
            }

            Section {
                ForEach(SpecialSignSlot.all) { slot in
                    let set = slot.station(in: stations) != nil
                    LabeledContent {
                        Text(set ? "Set" : slot.required ? "Needed to start" : "Optional")
                            .foregroundStyle(set ? .green : slot.required ? .red : .secondary)
                    } label: {
                        Label(slot.title, systemImage: slot.kind.icon)
                    }
                }
                if store.canEditGamesets {
                    Button { addingSpecial = true } label: { Label("Set up special signs", systemImage: "light.beacon.max") }
                }
            } header: {
                Text("Special signs")
            } footer: {
                Text("Include the red button so the game can start with no setup. A lobby keeps its own special signs for any the saved game doesn't have.")
            }
        }
        .navigationTitle(gameset?.name ?? initialName)
        .fullScreenCover(isPresented: $adding, onDismiss: { Task { await refresh() } }) {
            SignPanelContainer { compact in
                VStack(alignment: .leading, spacing: 12) {
                    SignPanel.header("Add a sign", subtitle: "To \(gameset?.name ?? initialName) · \(signCount) so far · no naming needed")
                    SignCaptureStep(compact: compact, title: "Sign \(signCount + 1)", fallbackName: "Sign \(signCount + 1)") { payload in
                        await store.editGamesets("gamesets/\(gamesetId)/stations", payload) != nil
                    } onSaved: {
                        Task { await refresh() }
                    }
                }
                .signPanel(closeLabel: "Done adding signs") { adding = false }
            }
            .presentationBackground(.clear)
        }
        .fullScreenCover(isPresented: $addingSpecial, onDismiss: { Task { await refresh() } }) {
            SpecialSignsView(
                stations: stations,
                submit: { payload in
                    let ok = await store.editGamesets("gamesets/\(gamesetId)/stations", payload) != nil
                    await refresh()
                    return ok
                },
                delete: { station in
                    await store.editGamesets("gamesets/\(gamesetId)/stations/\(station.id)/delete")
                    await refresh()
                },
                close: { addingSpecial = false }
            )
            .presentationBackground(.clear)
        }
        .sheet(item: $moving) { station in
            SignPlacementEditor(gamesetId: gamesetId, station: station,
                                others: stations.filter { $0.id != station.id }) {
                Task { await refresh() }
            }
        }
        .onChange(of: importItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await importPhotos(items) }
        }
        .gamesetPasswordPrompt(isPresented: $askingPassword) { afterUnlock?(); afterUnlock = nil }
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    private func whenUnlocked(_ action: @escaping () -> Void) {
        if store.canEditGamesets { action() } else { afterUnlock = action; askingPassword = true }
    }

    private func refresh() async {
        if let latest = try? await store.gameset(gamesetId) { gameset = latest }
    }

    /// Where the sign's pin is: building and floor, or that it has none yet.
    private func pinLabel(_ station: Station) -> String {
        guard station.lat != nil else { return "No map pin" }
        guard let b = station.buildingId, let building = store.campus.building(b) else { return "Map pin" }
        return "\(building.id) · \(building.floor(station.floorId)?.name ?? "no floor")"
    }

    /// Each photo: upload it, read the sign's text, and add it with the photo's own GPS location.
    private func importPhotos(_ items: [PhotosPickerItem]) async {
        importItems = []
        importProgress = (0, items.count)
        var number = signCount
        for (index, item) in items.enumerated() {
            if let imported = await SignPhotoImport.load(item),
               let photoId = try? await store.uploadPhoto(imported.image) {
                number += 1
                let text = await StationEditorView.readSignText(imported.image)
                var payload: [String: Any] = ["name": text ?? "Sign \(number)", "kind": "task", "photoId": photoId]
                if let text { payload["signText"] = text }
                if let coordinate = imported.coordinate {
                    payload["lat"] = coordinate.latitude
                    payload["lng"] = coordinate.longitude
                }
                await store.editGamesets("gamesets/\(gamesetId)/stations", payload)
            }
            importProgress = (index + 1, items.count)
        }
        importProgress = nil
        await refresh()
    }
}

private struct GamesetPasswordPrompt: ViewModifier {
    @Environment(GameStore.self) private var store
    @Binding var isPresented: Bool
    let onUnlock: () -> Void
    @State private var password = ""

    func body(content: Content) -> some View {
        content.alert("Team password", isPresented: $isPresented) {
            SecureField("Password", text: $password)
            Button("Unlock") {
                let attempt = password
                password = ""
                Task { if await store.unlockGamesets(password: attempt) { onUnlock() } }
            }
            Button("Cancel", role: .cancel) { password = "" }
        } message: {
            Text("Creating and editing saved games needs the team password.")
        }
    }
}

extension View {
    func gamesetPasswordPrompt(isPresented: Binding<Bool>, onUnlock: @escaping () -> Void) -> some View {
        modifier(GamesetPasswordPrompt(isPresented: isPresented, onUnlock: onUnlock))
    }
}
