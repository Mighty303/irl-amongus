import SwiftUI

/// Reveals the server-assigned role automatically, then acknowledges it after the presentation. The role
/// stays on screen ("Waiting for everyone…") until the server starts play and the HUD takes over.
struct RoleRevealView: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var revealed = false
    /// Three seconds after the role appears: time to tell the server we've seen it.
    @State private var presented = false
    @StateObject private var revealAudio = RoleRevealAudioPlayer()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let role = state.me.role {
                if revealed {
                    RoleRevealArtwork(
                        role: role,
                        impostorCount: state.settings.impostors,
                        players: RoleRevealPlayer.lineup(from: state.players, localID: state.me.id, role: role)
                    )
                    VStack {
                        Spacer()
                        let partners = state.players.filter { $0.role == .impostor && $0.id != state.me.id }
                        if role == .impostor && !partners.isEmpty {
                            Text("Fellow impostors: \(partners.map(\.name).joined(separator: ", "))")
                                .foregroundStyle(.red)
                        }
                        if state.me.ackedRole {
                            Text("Waiting for everyone to see their role…")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .font(.system(size: 14, design: .monospaced))
                    .padding(.bottom, 24)
                } else {
                    RoleRevealIntroView {
                        guard !revealed else { return }
                        revealed = true
                        revealAudio.play()
                    }
                    .accessibilityLabel("Shhh. Keep your role secret.")
                    .accessibilityIdentifier("roles.intro")
                }
            } else {
                ProgressView("Receiving your role…")
            }
        }
        .preferredColorScheme(.dark)
        .task(id: revealed) {
            guard revealed else { return }
            do {
                // Three seconds from the role appearing, after the Shhh intro finishes.
                try await Task.sleep(for: .seconds(3))
            } catch { return }
            presented = true
            revealAudio.stop()
        }
        .task(id: "\(presented)-\(store.isSynced)-\(state.me.ackedRole)") {
            guard presented, store.isSynced, store.state?.phase == .ROLE_REVEAL,
                  store.state?.me.ackedRole == false else { return }
            await store.perform("ack_role")
        }
        .onAppear { OrientationDelegate.requestLandscape() }
        .onDisappear { revealAudio.stop() }
    }
}
