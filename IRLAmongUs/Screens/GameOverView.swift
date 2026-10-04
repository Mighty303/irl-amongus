import SwiftUI
import CoreImage
import UIKit

struct GameOverView: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var restarting = false

    private var role: Role { state.winner == "crewmates" ? .crewmate : .impostor }
    private var didWin: Bool { GameOutcome.didWin(winner: state.winner, localRole: state.me.role?.rawValue) }

    var body: some View {
        ZStack(alignment: .bottom) {
            GameOverArtwork(role: role, didWin: didWin, players: GameOverArtwork.winners(
                from: state.players, localID: state.me.id, role: role))
            HStack(alignment: .bottom, spacing: 16) {
                GameOverActionButton(asset: "QuitActionIcon", label: "Quit",
                                     identifier: "gameOver.leave") { store.leave() }
                Spacer(minLength: 0)
                if !state.isHost {
                    Text("Waiting for the host…")
                        .font(.caption).foregroundStyle(.white)
                }
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

    }
}

/// The supplied backgrounds provide the glow; impostor wins reuse the Victory lettering in red.
struct GameOverArtwork: View {
    let role: Role
    var didWin = true
    let players: [RoleRevealPlayer]

    // Use the exact Victory pixels from the crew background as a tintable title.
    // Its blue channel becomes the alpha mask, leaving the black background transparent.
    private static let victoryTitle: UIImage? = {
        guard let source = UIImage(named: "CrewmateWinBackground")?.cgImage,
              let crop = source.cropping(to: CGRect(x: 410, y: 80, width: 480, height: 100)),
              let filter = CIFilter(name: "CIColorMatrix") else { return nil }
        filter.setValue(CIImage(cgImage: crop), forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputAVector")
        guard let output = filter.outputImage,
              let image = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: image)
    }()

    nonisolated static func winners(from players: [PlayerView], localID: String, role: Role) -> [RoleRevealPlayer] {
        let winners = players.enumerated().compactMap { index, player -> RoleRevealPlayer? in
            guard player.role == role else { return nil }
            return RoleRevealPlayer(id: player.id, name: player.name,
                color: player.color ?? PlayerColor.allCases[index % PlayerColor.allCases.count], faceId: player.faceId)
        }
        return winners.filter { $0.id == localID } + winners.filter { $0.id != localID }
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let aspect: CGFloat = !didWin || role == .crewmate ? 1280 / 720 : 1076 / 510
            let width = min(size.width, size.height * aspect)
            let height = width / aspect
            ZStack {
                Color.black
                ZStack {
                    Image(!didWin ? "DefeatBackground" : role == .crewmate ? "CrewmateWinBackground" : "ImpostorWinBackground")
                        .resizable().interpolation(.none)
                        .frame(width: width, height: height)
                        .accessibilityLabel(!didWin ? "Defeat" : role == .crewmate ? "Crewmates win" : "Impostors win")
                        .accessibilityIdentifier("gameOver.title")
                        .accessibilityAddTraits(.isHeader)
                    if didWin && role == .impostor {
                        Color.black
                            .frame(width: width, height: height * 0.40)
                            .position(x: width / 2, y: height * 0.20)
                            .accessibilityHidden(true)
                        if let title = Self.victoryTitle {
                            Image(uiImage: title).renderingMode(.template)
                                .resizable().interpolation(.none).scaledToFit()
                                .foregroundStyle(Color(red: 1, green: 0.06, blue: 0.06))
                                .frame(width: width * 0.46, height: height * 0.20)
                                .position(x: width / 2, y: height * 0.20)
                                .accessibilityHidden(true)
                        }
                    }
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
    @Environment(GameStore.self) private var store
    @State private var role = Role.crewmate
    @State private var didWin = true

    var body: some View {
        ZStack(alignment: .bottom) {
            GameOverArtwork(role: role, didWin: didWin, players: RoleRevealPlayer.preview(for: role, localFaceId: store.preferredFaceId))
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
                Picker("Your result", selection: $didWin) {
                    Text("Victory").tag(true)
                    Text("Defeat").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 180)
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
