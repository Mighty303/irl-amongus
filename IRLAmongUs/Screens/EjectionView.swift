import SwiftUI

/// After a vote, like Among Us: black space with stars streaming past, the ejected player's crewmate
/// tumbling across the screen, and the verdict typed out in the middle ("Martin was An Impostor." /
/// "1 Impostor remains."). A skip or tie just types "No one was ejected." Shown for the server's
/// RESULT phase; play resumes (or the game ends) when that phase does.
struct EjectionView: View {
    let state: GameState
    @State private var start = Date()

    /// How long the crewmate takes to cross; the text starts typing as it reaches the middle.
    private static let crossSeconds = 5.0
    private static let typeStart = 1.4
    private static let charsPerSecond = 16.0

    private var ejected: PlayerView? { state.player(state.result?.ejectedId) }

    private var headline: String {
        guard let r = state.result else { return "" }
        guard let ejected else { return r.tie ? "No one was ejected. (Tie)" : "No one was ejected. (Skipped)" }
        switch r.ejectedWasImpostor {
        case true?: return "\(ejected.name) was An Impostor."
        case false?: return "\(ejected.name) was not An Impostor."
        case nil: return "\(ejected.name) was ejected."
        }
    }

    private var remaining: String? {
        guard let n = state.result?.impostorsRemaining else { return nil }
        return n == 1 ? "1 Impostor remains." : "\(n) Impostors remain."
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            GeometryReader { geo in
                let size = geo.size
                ZStack {
                    Color.black
                    Self.stars(time: t, size: size)

                    VStack(spacing: 10) {
                        Text(typed(headline, after: Self.typeStart, at: t))
                            .font(.system(size: min(30, size.width / 24), weight: .regular))
                        if let remaining {
                            let second = Self.typeStart + Double(headline.count) / Self.charsPerSecond + 0.4
                            Text(typed(remaining, after: second, at: t))
                                .font(.system(size: min(22, size.width / 32), weight: .regular))
                        }
                    }
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    // Keep the line laid out at full width so typing doesn't shift it.
                    .frame(maxWidth: .infinity)

                    if let ejected {
                        let progress = min(max(t / Self.crossSeconds, 0), 1)
                        let height = min(size.height * 0.32, 130)
                        Image((ejected.color ?? .red).lobbyAssetName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: height)
                            .rotationEffect(.degrees(t * 140))
                            .position(x: -height + (size.width + 2 * height) * progress,
                                      y: size.height * 0.5 + sin(t * 1.3) * size.height * 0.04)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: size.width, height: size.height)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([headline, remaining].compactMap { $0 }.joined(separator: " "))
        .onAppear { start = Date() }
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
