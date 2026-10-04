import AVFoundation
import SwiftUI
import UIKit

/// Isolated visual demo: no role assignment or network actions.
struct RoleRevealPOCView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var role: Role?
    @State private var revealed = false
    @State private var playbackID = UUID()
    @StateObject private var revealAudio = RoleRevealAudioPlayer()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                if let role {
                    if revealed {
                        RoleRevealArtwork(role: role, impostorCount: 1)
                        VStack {
                            Spacer()
                            HStack(spacing: 24) {
                                Button("Replay") { start(role) }
                                    .accessibilityIdentifier("roles.replay")
                                Button("Try \(role == .impostor ? "Crewmate" : "Impostor")") {
                                    start(role == .impostor ? .crewmate : .impostor)
                                }
                                .accessibilityIdentifier("roles.switch")
                            }
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.bottom, 12)
                        }
                    } else {
                        ShhhIntroView {
                            revealed = true
                            revealAudio.play()
                        }
                            .id(playbackID)
                            .accessibilityLabel("Shhh. Keep your role secret.")
                            .accessibilityIdentifier("roles.intro")
                    }
                } else {
                    VStack(spacing: 16) {
                        ShhhPosterView().frame(width: 120, height: 120)
                        Text("Role Reveal").font(.largeTitle)
                        Text("Choose a role to preview").foregroundStyle(.secondary)
                        HStack(spacing: 24) {
                            roleButton(.crewmate, title: "Crewmate", color: .cyan)
                            roleButton(.impostor, title: "Impostor", color: .red)
                        }
                    }
                    .foregroundStyle(.white)
                }
                VStack {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image("CloseMenuIcon").resizable().scaledToFit()
                                .frame(width: 32, height: 32).frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Close role reveal")
                        .accessibilityIdentifier("roles.close")
                    }
                    Spacer()
                }
                .padding(8)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .buttonStyle(.plain)
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear { OrientationDelegate.requestLandscape() }
        .onDisappear { revealAudio.stop() }
    }

    private func roleButton(_ role: Role, title: String, color: Color) -> some View {
        Button { start(role) } label: {
            Text(title).font(.title2.monospaced()).foregroundStyle(color)
                .padding(.horizontal, 26).padding(.vertical, 16)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 2))
        }
        .accessibilityIdentifier("roles.\(role.rawValue)")
    }

    private func start(_ nextRole: Role) {
        revealAudio.stop()
        revealed = false
        role = nextRole
        playbackID = UUID()
    }
}

struct RoleRevealArtwork: View {
    let role: Role
    let impostorCount: Int
    private var color: Color { role == .impostor ? Color(red: 0.78, green: 0, blue: 0.1) : .cyan }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                Color.black
                Ellipse()
                    .fill(color.opacity(0.35))
                    .frame(width: size.width * 0.83, height: size.height * 0.16)
                    .blur(radius: 30)
                    .position(x: size.width / 2, y: size.height * 0.67)
                PixelRoleTitle(text: role == .impostor ? "Impostor" : "Crewmate", color: color)
                    .frame(width: size.width * 0.7, height: size.height * 0.2)
                    .position(x: size.width / 2, y: size.height * 0.25)
                    .accessibilityLabel(role == .impostor ? "Impostor" : "Crewmate")
                    .accessibilityIdentifier("roles.title")
                    .accessibilityAddTraits(.isHeader)
                if role == .crewmate {
                    (Text("There \(impostorCount == 1 ? "is" : "are") ")
                     + Text("\(impostorCount) Impostor\(impostorCount == 1 ? "" : "s")").foregroundColor(.red)
                     + Text(" among us"))
                        .font(.system(size: size.height * 0.045, design: .monospaced))
                        .foregroundStyle(.white)
                        .position(x: size.width / 2, y: size.height * 0.43)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// Bitmap lettering drawn at whole-pixel boundaries; stays sharp at every screen size.
private struct PixelRoleTitle: View {
    let text: String
    let color: Color
    private static let glyphs: [Character: [String]] = [
        "I": ["11111","00100","00100","00100","00100","00100","11111"],
        "C": ["01111","10000","10000","10000","10000","10000","01111"],
        "m": ["00000","00000","11010","10101","10101","10101","10101"],
        "p": ["00000","11110","10001","11110","10000","10000","10000"],
        "o": ["00000","00000","01110","10001","10001","10001","01110"],
        "s": ["00000","00000","01111","10000","01110","00001","11110"],
        "t": ["00100","00100","11111","00100","00100","00100","00011"],
        "r": ["00000","00000","10110","11001","10000","10000","10000"],
        "e": ["00000","00000","01110","10001","11111","10000","01111"],
        "w": ["00000","00000","10001","10001","10101","10101","01010"],
        "a": ["00000","00000","01110","00001","01111","10001","01111"]
    ]

    var body: some View {
        Canvas { context, size in
            let columns = text.count * 6 - 1
            let pixel = floor(min(size.width / CGFloat(columns), size.height / 7))
            let origin = CGPoint(x: floor((size.width - CGFloat(columns) * pixel) / 2),
                                 y: floor((size.height - 7 * pixel) / 2))
            var glyphPath = Path()
            for (index, letter) in text.enumerated() {
                for (row, line) in (Self.glyphs[letter] ?? []).enumerated() {
                    for (column, bit) in line.enumerated() where bit == "1" {
                        let rect = CGRect(x: origin.x + CGFloat(index * 6 + column) * pixel,
                                          y: origin.y + CGFloat(row) * pixel, width: pixel, height: pixel)
                        glyphPath.addRect(rect)
                    }
                }
            }
            context.fill(glyphPath, with: .color(color))
        }
    }
}

private struct ShhhIntroView: View {
    let onComplete: () -> Void
    var body: some View { IntroMovieView(onComplete: onComplete) }
}

private struct ShhhPosterView: View {
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.height, geometry.size.width)
            ZStack {
                Image("RoleShhhBackground").resizable().scaledToFit()
                Image("RoleShhhCrew").resizable().scaledToFit()
                    .frame(width: side * 0.48).offset(y: side * 0.04)
                Image("RoleShhhHand").resizable().scaledToFit()
                    .frame(width: side * 0.23).offset(x: side * 0.03, y: side * 0.31)
                Image("RoleShhhText").resizable().scaledToFit()
                    .frame(width: side * 0.8).offset(y: side * 0.46)
            }
            .frame(width: side, height: side)
        }
        .accessibilityHidden(true)
    }
}

private struct IntroMovieView: UIViewRepresentable {
    let onComplete: () -> Void

    func makeUIView(context: Context) -> IntroPlayerView {
        let view = IntroPlayerView()
        view.play(onComplete: onComplete)
        return view
    }

    func updateUIView(_ uiView: IntroPlayerView, context: Context) {}
    static func dismantleUIView(_ uiView: IntroPlayerView, coordinator: ()) { uiView.stop() }
}

private final class IntroPlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?

    func play(onComplete: @escaping () -> Void) {
        guard let url = Bundle.main.url(forResource: "shhh-intro", withExtension: "mp4") else {
            onComplete()
            return
        }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        player.isMuted = true
        let playerLayer = layer as! AVPlayerLayer
        playerLayer.videoGravity = .resizeAspect
        playerLayer.player = player
        backgroundColor = .black
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                                            object: item, queue: .main) { _ in
            MainActor.assumeIsolated { onComplete() }
        }
        player.play()
    }

    func stop() {
        player?.pause()
        (layer as? AVPlayerLayer)?.player = nil
        player = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
    }
}
