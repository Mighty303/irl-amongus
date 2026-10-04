import SwiftUI

/// After a vote, like Among Us: black space with stars streaming past and the ejected player's crewmate
/// tumbling across from right to left; the verdict ("Martin was An Impostor." / "1 Impostor remains.")
/// appears from behind them as they pass over it, a click per letter. A skip or tie just types "No one
/// was ejected." Shown for the server's RESULT phase; play resumes (or the game ends) when that phase does.
struct EjectionView: View {
    let result: VoteResult?
    let ejected: PlayerView?
    @State private var start = Date()
    @State private var screen: CGSize = .zero
    /// Letters showing so far, for the clicks.
    @State private var revealed = 0
    private let clock = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()

    /// How long the crewmate takes to cross (passing the middle halfway through).
    private static let crossSeconds = 5.0
    /// Skip or tie: no crewmate, the text types itself.
    private static let typeStart = 1.0
    private static let charsPerSecond = 16.0

    init(state: GameState) {
        self.init(result: state.result, ejected: state.player(state.result?.ejectedId))
    }

    init(result: VoteResult?, ejected: PlayerView?) {
        self.result = result
        self.ejected = ejected
    }

    private var headline: String {
        guard let r = result else { return "" }
        guard let ejected else { return r.tie ? "No one was ejected. (Tie)" : "No one was ejected. (Skipped)" }
        switch r.ejectedWasImpostor {
        case true?: return "\(ejected.name) was An Impostor."
        case false?: return "\(ejected.name) was not An Impostor."
        case nil: return "\(ejected.name) was ejected."
        }
    }

    private var remaining: String? {
        guard let n = result?.impostorsRemaining else { return nil }
        return n == 1 ? "1 Impostor remains." : "\(n) Impostors remain."
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            GeometryReader { geo in
                let size = geo.size
                let height = min(size.height * 0.32, 130)
                let crewX = Self.crewmateX(at: t, width: size.width, height: height)
                ZStack {
                    Color.black
                    Self.stars(time: t, size: size)

                    VStack(spacing: 10) {
                        if ejected != nil {
                            Text(headline).font(.system(size: min(30, size.width / 24), weight: .regular))
                            if let remaining { Text(remaining).font(.system(size: min(22, size.width / 32), weight: .regular)) }
                        } else {
                            Text(typed(headline, after: Self.typeStart, at: t))
                                .font(.system(size: min(30, size.width / 24), weight: .regular))
                            if let remaining {
                                Text(typed(remaining, after: secondLineStart, at: t))
                                    .font(.system(size: min(22, size.width / 32), weight: .regular))
                            }
                        }
                    }
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    // Keep the lines laid out at full width so revealing doesn't shift them.
                    .frame(maxWidth: .infinity)
                    // Only what the crewmate has already passed shows: the text comes out from behind them.
                    .mask(alignment: .leading) {
                        if ejected != nil {
                            Color.black.padding(.leading, max(0, crewX)).frame(width: size.width)
                        } else {
                            Color.black
                        }
                    }

                    if let ejected {
                        Image((ejected.color ?? .red).lobbyAssetName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: height)
                            .rotationEffect(.degrees(-t * 140))
                            .position(x: crewX, y: size.height * 0.5 + sin(t * 1.3) * size.height * 0.04)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: size.width, height: size.height)
                .onAppear { screen = size }
                .onChange(of: size) { _, new in screen = new }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([headline, remaining].compactMap { $0 }.joined(separator: " "))
        // Letters revealed (each one clicked), for UI tests.
        .accessibilityValue("\(revealed)")
        .accessibilityIdentifier("ejection.screen")
        .onAppear { start = Date() }
        .onReceive(clock) { now in click(at: now.timeIntervalSince(start)) }
    }

    /// The crewmate's centre: in from the right edge, out past the left, crossing the middle halfway.
    private static func crewmateX(at t: Double, width: CGFloat, height: CGFloat) -> CGFloat {
        let progress = min(max(t / crossSeconds, 0), 1)
        return width + height - (width + 2 * height) * progress
    }

    private var letterCount: Int { headline.count + (remaining?.count ?? 0) }
    private var secondLineStart: Double { Self.typeStart + Double(headline.count) / Self.charsPerSecond + 0.4 }

    /// The eject-text click for each letter as it appears.
    private func click(at t: Double) {
        let shown: Int
        if ejected != nil {
            guard screen.width > 0 else { return }
            // The verdict is centred, about half a font size per letter: the letters the crewmate has passed.
            let font = min(30, screen.width / 24)
            let textWidth = min(screen.width - 48, CGFloat(headline.count) * font * 0.5)
            let x = Self.crewmateX(at: t, width: screen.width, height: min(screen.height * 0.32, 130))
            let passed = (screen.width / 2 + textWidth / 2 - x) / max(textWidth, 1)
            shown = Int((min(max(passed, 0), 1) * Double(letterCount)).rounded(.down))
        } else {
            let first = typed(headline, after: Self.typeStart, at: t).count
            shown = first + (remaining.map { typed($0, after: secondLineStart, at: t).count } ?? 0)
        }
        if shown > revealed { GameSoundEffect.ejectText.play() }
        revealed = max(revealed, shown)
    }

    /// The first characters of `text` that would have been typed by time `t`.
    private func typed(_ text: String, after begin: Double, at t: Double) -> String {
        let count = max(0, Int((t - begin) * Self.charsPerSecond))
        return String(text.prefix(count))
    }

    /// Stars streaming right to left at three depths, as if drifting through space.
    private static func stars(time: Double, size: CGSize) -> some View {
        Canvas { context, canvas in
            var rng = SeededRandom(seed: 7)
            for _ in 0..<70 {
                let depth = rng.next()            // 0 far … 1 near
                let speed = 20 + depth * 70       // points per second
                let y = rng.next() * canvas.height
                let x0 = rng.next() * (canvas.width + 40)
                let x = (x0 - time * speed).truncatingRemainder(dividingBy: canvas.width + 40)
                let px = x < 0 ? x + canvas.width + 40 : x
                let r = 0.8 + depth * 1.8
                context.fill(Path(ellipseIn: CGRect(x: px - 20, y: y, width: r * 2, height: r * 2)),
                             with: .color(.white.opacity(0.45 + depth * 0.5)))
            }
        }
    }
}

/// Same stars every frame (a fixed seed), so they move rather than flicker.
private struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}

/// Developer tools: the ejection screen without a game.
struct EjectionPreview: View {
    @State private var color = PlayerColor.lime
    @State private var outcome = 0
    @State private var playing = false

    var body: some View {
        Form {
            Picker("Ejected player's colour", selection: $color) {
                ForEach(PlayerColor.allCases, id: \.self) { Text($0.name).tag($0) }
            }
            Picker("Outcome", selection: $outcome) {
                Text("Impostor").tag(0)
                Text("Not the impostor").tag(1)
                Text("Skipped").tag(2)
            }
            Button("Eject") { playing = true }
                .accessibilityIdentifier("ejection.preview.play")
        }
        .fullScreenCover(isPresented: $playing) {
            let player = PlayerView(id: "preview", name: "Martin", color: color, faceId: nil, isHost: false, isBot: nil,
                                    connected: true, alive: false, ejected: true, role: nil, hasVoted: true)
            let result = VoteResult(tallies: [], ejectedId: outcome == 2 ? nil : player.id,
                                    ejectedWasImpostor: outcome == 2 ? nil : outcome == 0, tie: false,
                                    ejectedRole: nil, impostorsRemaining: outcome == 2 ? nil : outcome == 0 ? 0 : 1)
            EjectionView(result: result, ejected: outcome == 2 ? nil : player)
                .overlay(alignment: .topLeading) {
                    Button("Done") { playing = false }.padding().accessibilityIdentifier("ejection.preview.done")
                }
        }
    }
}
