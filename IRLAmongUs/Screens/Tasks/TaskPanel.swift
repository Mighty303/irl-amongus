import AVFoundation
import SwiftUI

/// The Among Us task window: the game dims behind the panel, an X closes it, and
/// "Task Completed!" slides across before it closes itself. Tasks are always landscape,
/// like the game; closing restores whatever orientation was in use before.
struct TaskPanel<Content: View>: View {
    var title: String?
    var message: String?
    let completed: Bool
    let close: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var previousOrientation: UIInterfaceOrientationMask = .landscape

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            content()
                .padding(.horizontal, 64)
                .padding(.vertical, 8)
                .allowsHitTesting(!completed)
            if completed { TaskCompletedBanner() }
        }
        .overlay(alignment: .topLeading) {
            Button(action: close) {
                Image("CloseMenuIcon").resizable().frame(width: 44, height: 44)
            }
            .padding(8)
            .accessibilityLabel("Close task")
        }
        .overlay(alignment: .topTrailing) {
            if let title { Text(title).font(.caption.bold()).foregroundStyle(.white).padding(12) }
        }
        .overlay(alignment: .bottom) {
            if let message {
                Text(message).font(.callout.bold()).foregroundStyle(.white).multilineTextAlignment(.center)
                    .padding(8).background(.red, in: RoundedRectangle(cornerRadius: 8)).padding(8)
            }
        }
        .onAppear {
            previousOrientation = OrientationDelegate.supportedOrientations
            OrientationDelegate.requestLandscape()
            TaskSound.panelOpen.play()
        }
        // Back to how it was: landscape in a game (never a flip to portrait and back), portrait in the POCs.
        .onDisappear { OrientationDelegate.requestOrientation(previousOrientation) }
    }
}

private struct TaskCompletedBanner: View {
    @State private var offset: CGFloat = 600

    var body: some View {
        TaskText("Task Completed!", size: 40)
            .offset(x: offset)
            .task {
                withAnimation(.easeOut(duration: 0.25)) { offset = 0 }
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation(.easeIn(duration: 0.25)) { offset = -600 }
            }
    }
}

/// White rounded text with the heavy black outline Among Us uses for its overlay messages.
struct TaskText: View {
    let text: String
    let size: CGFloat
    init(_ text: String, size: CGFloat) { self.text = text; self.size = size }

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black, radius: 0, x: 2, y: 2)
            .shadow(color: .black, radius: 0, x: -2, y: -2)
            .shadow(color: .black, radius: 0, x: 2, y: -2)
            .shadow(color: .black, radius: 0, x: -2, y: 2)
    }
}

/// Lays sprites out in the source art's pixel coordinates (1x assets, so 1 px = 1 pt)
/// and scales the whole stage to fit. Gestures inside report stage coordinates.
struct SpriteStage<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geo in
            content()
                .frame(width: width, height: height)
                .scaleEffect(min(geo.size.width / width, geo.size.height / height))
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(width / height, contentMode: .fit)
    }
}

extension View {
    /// Places a view with its center at a point in stage coordinates.
    func at(_ x: CGFloat, _ y: CGFloat) -> some View { position(x: x, y: y) }
}

/// Among Us task sounds, stored as data assets by scripts/import-task-assets.py.
/// They play on the default audio session, so the ringer switch mutes them.
enum TaskSound: String {
    case panelOpen = "TaskSoundPanelOpen", panelClose = "TaskSoundPanelClose", complete = "TaskSoundComplete"
    case select = "TaskSoundSelect"
    case wire1 = "TaskSoundWire1", wire2 = "TaskSoundWire2", wire3 = "TaskSoundWire3"
    case reactorBeep = "TaskSoundReactorBeep", reactorFail = "TaskSoundReactorFail"
    case walletOut = "TaskSoundWalletOut", cardMove = "TaskSoundCardMove"
    case cardAccept = "TaskSoundCardAccept", cardDeny = "TaskSoundCardDeny"
    case shieldOn = "TaskSoundShieldOn", shieldOff = "TaskSoundShieldOff"
    case leafGrab = "TaskSoundLeafGrab"
    case leafSuck1 = "TaskSoundLeafSuck1", leafSuck2 = "TaskSoundLeafSuck2", leafSuck3 = "TaskSoundLeafSuck3"
    case scan = "TaskSoundScan", divert = "TaskSoundDivert", accept = "TaskSoundAccept"

    @MainActor private static var players: [TaskSound: AVAudioPlayer] = [:]

    @MainActor func play() {
        guard let player = Self.players[self] ?? load() else { return }
        player.currentTime = 0
        player.play()
    }

    @MainActor func stop() { Self.players[self]?.stop() }

    @MainActor private func load() -> AVAudioPlayer? {
        guard let data = NSDataAsset(name: rawValue)?.data,
              let player = try? AVAudioPlayer(data: data) else { return nil } // tasks still work silently
        player.prepareToPlay()
        Self.players[self] = player
        return player
    }
}
