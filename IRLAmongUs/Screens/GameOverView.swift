import SwiftUI

struct GameOverView: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var showingRoles = false
    @State private var restarting = false

    private var role: Role { state.winner == "crewmates" ? .crewmate : .impostor }

    var body: some View {
        ZStack(alignment: .bottom) {
            GameOverArtwork(role: role, players: GameOverArtwork.winners(
                from: state.players, localID: state.me.id, role: role))
            HStack(alignment: .bottom, spacing: 16) {
                GameOverActionButton(asset: "QuitActionIcon", label: "Quit",
                                     identifier: "gameOver.leave") { store.leave() }
                Spacer(minLength: 0)
                VStack(spacing: 6) {
                    if let reason = state.winReason { Text(reason).font(.subheadline) }
                    Text("\(state.taskProgress.done) / \(state.taskProgress.total) tasks completed")
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                    Button("Roles") { showingRoles = true }
                        .buttonStyle(.bordered).tint(.white)
                    if !state.isHost {
                        Text("Waiting for the host…").font(.caption)
                    }
                }
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                Spacer(minLength: 0)
                if state.isHost {
                    GameOverActionButton(asset: "PlayAgainActionIcon",
                                         label: restarting ? "Starting…" : "Play again",
                                         identifier: "gameOver.restart") {
                        restarting = true
                        Task {
                            await store.perform("restart")
                            restarting = false
                        }
                    }
                    .disabled(restarting || !store.isSynced)
                } else {
                    Color.clear.frame(width: 90, height: 108)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(.black)
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .sheet(isPresented: $showingRoles) {
            NavigationStack {
                List(state.players) { player in
                    HStack {
                        Image((player.color ?? .white).lobbyAssetName)
                            .resizable().scaledToFit().frame(width: 28, height: 36)
                        Text(player.name)
                        Spacer()
                        Text(player.role == .impostor ? "Impostor" : "Crewmate")
                            .foregroundStyle(player.role == .impostor ? .red : .cyan)
                        if !player.alive {
                            Image(systemName: player.ejected ? "arrow.up.circle" : "xmark.circle")
                                .accessibilityLabel(player.ejected ? "Ejected" : "Dead")
                        }
                    }
                }
                .navigationTitle("Roles")
                .toolbar { Button("Done") { showingRoles = false } }
            }
            .preferredColorScheme(.dark)
        }
    }
}

/// The supplied bitmap backgrounds include the title and glow. Only the roster is layered on top.
struct GameOverArtwork: View {
    let role: Role
    let players: [RoleRevealPlayer]

    nonisolated static func winners(from players: [PlayerView], localID: String, role: Role) -> [RoleRevealPlayer] {
        let winners = players.enumerated().compactMap { index, player -> RoleRevealPlayer? in
            guard player.role == role else { return nil }
            return RoleRevealPlayer(id: player.id, name: player.name,
                color: player.color ?? PlayerColor.allCases[index % PlayerColor.allCases.count])
        }
        return winners.filter { $0.id == localID } + winners.filter { $0.id != localID }
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let aspect: CGFloat = role == .crewmate ? 1280 / 720 : 1076 / 510
            let width = min(size.width, size.height * aspect)
            let height = width / aspect
            ZStack {
                Color.black
                ZStack {
                    Image(role == .crewmate ? "CrewmateWinBackground" : "ImpostorWinBackground")
                        .resizable().interpolation(.none)
                        .frame(width: width, height: height)
                        .accessibilityLabel(role == .crewmate ? "Crewmates win" : "Impostors win")
                        .accessibilityIdentifier("gameOver.title")
                        .accessibilityAddTraits(.isHeader)
                    RoleRevealLineup(players: players, showsNames: role == .impostor,
                                     accessibilityPrefix: "gameOver")
                        .frame(width: width * 0.8, height: height * 0.32)
                        .position(x: width / 2, y: height * 0.60)
                }
                .frame(width: width, height: height)
                .position(x: size.width / 2, y: size.height / 2)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
    }
}

/// Shared with the preview so the artwork and button placement can be reviewed together.
private struct GameOverActionButton: View {
    let asset: String
    let label: String
    let identifier: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(asset)
                .resizable().scaledToFit()
                .frame(width: 90, height: 108)
                .opacity(isEnabled ? 1 : 0.45)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}

struct GameOverPreview: View {
    @State private var role = Role.crewmate

    var body: some View {
        ZStack(alignment: .bottom) {
            GameOverArtwork(role: role, players: RoleRevealPlayer.preview(for: role))
            HStack(alignment: .bottom) {
                GameOverActionButton(asset: "QuitActionIcon", label: "Quit",
                                     identifier: "gameOver.leave") {}
                Spacer()
                Picker("Winning team", selection: $role) {
                    Text("Crewmates").tag(Role.crewmate)
                    Text("Impostors").tag(Role.impostor)
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
                Spacer()
                GameOverActionButton(asset: "PlayAgainActionIcon", label: "Play again",
                                     identifier: "gameOver.restart") {}
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(.black)
        .onAppear { OrientationDelegate.requestLandscape() }
    }
}
