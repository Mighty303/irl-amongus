import SwiftUI

struct HomeView: View {
    @Environment(GameStore.self) private var store
    @State private var code = ""
    @State private var scanning = false
    @State private var serverStatus: String?
    @State private var busy = false

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section("You") {
                    TextField("Display name", text: $store.playerName)
                        .textInputAutocapitalization(.words)
                }
                Section("Join") {
                    Button("Scan lobby QR") { scanning = true }
                    TextField("Room code", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Button("Join game") { run { await store.joinGame(code: code) } }
                        .disabled(!GameStore.isValidRoomCode(code) || !store.canEnterLobby || busy)
                }
                Section("Host") {
                    Button("Create game") { run { await store.createGame() } }
                        .disabled(!store.canEnterLobby || busy)
                }
                Section {
                    TextField(GameStore.defaultServerURL, text: $store.serverURLString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Test connection") {
                        serverStatus = "Testing…"
                        Task { serverStatus = await store.checkServer() }
                    }
                    if let serverStatus { Text(serverStatus).font(.caption.monospaced()) }
                } header: {
                    Text("Server")
                } footer: {
                    Text("Defaults to the hosted server. Scanning a lobby QR sets this automatically. For a local server, use the URL it prints (or a tunnel).")
                }
            }
            .navigationTitle("IRL Among Us")
            .sheet(isPresented: $scanning) {
                QRScanSheet(title: "Scan lobby QR") { payload in
                    if case let .join(c, server) = QRPayload(payload) {
                        if let server { store.serverURLString = server }
                        code = c
                        scanning = false
                    }
                }
            }
            .onChange(of: store.pendingJoinCode, initial: true) { _, pending in
                if let pending { code = pending; store.pendingJoinCode = nil }
            }
        }
    }

    private func run(_ work: @escaping () async -> Void) {
        busy = true
        Task {
            await work()
            busy = false
        }
    }
}

/// Generic camera QR scanner sheet.
struct QRScanSheet: View {
    let title: String
    let onCode: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CameraView(onQRCode: onCode)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Close") { dismiss() } }
        }
    }
}
