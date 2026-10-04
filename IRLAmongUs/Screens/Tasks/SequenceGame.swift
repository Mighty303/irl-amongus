import SwiftUI

/// Start Reactor: the left screen flashes a pattern that grows by one square each round (five rounds);
/// repeat it on the right keypad. A wrong press flashes red and restarts the same pattern from round one.
/// Lights above the screen count finished rounds, lights above the keypad count presses this round.
/// Coordinates are pixels of the 247×281 panel art; the two panels stack in portrait.
struct SequenceGame: View {
    let onDone: () -> Void

    private static let rounds = 5
    private static let blue = Color(red: 0.2, green: 0.55, blue: 1)
    private static let red = Color(red: 1, green: 0.15, blue: 0.1)

    @State private var pattern: [Int] = (0..<rounds).map { _ in Int.random(in: 0..<9) }
    /// Rounds completed so far.
    @State private var round = 0
    @State private var presses = 0
    @State private var showing = true
    @State private var lit: Int?
    @State private var pressed: Int?
    @State private var failed = false

    var body: some View {
        GeometryReader { geo in
            let stacked = geo.size.height > geo.size.width
            let layout = stacked ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
            layout {
                panel { screen }
                panel { keypad }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .task(id: round) { await playPattern() }
    }

    private func panel<Content: View>(@ViewBuilder _ content: @escaping () -> Content) -> some View {
        SpriteStage(width: 247, height: 281) {
            ZStack {
                Image("TaskReactorBase")
                content()
            }
        }
    }

    private func lights(_ count: Int, color: Color) -> some View {
        ZStack(alignment: .topLeading) {
            Image("TaskReactorLights")
            ForEach(0..<Self.rounds, id: \.self) { i in
                Image("TaskReactorLight")
                    .colorMultiply(color)
                    .brightness(0.15)
                    .opacity(i < count ? 1 : 0)
                    .position(x: [10.5, 44.5, 78, 112.5, 145][i], y: 10.5)
            }
        }
        .frame(width: 157, height: 28)
        .at(123.5, 32)
    }

    private static func cell(_ i: Int) -> CGPoint {
        CGPoint(x: 123.5 + CGFloat(i % 3 - 1) * 50, y: 160 + CGFloat(i / 3 - 1) * 50)
    }

    private var screen: some View {
        ZStack {
            lights(round, color: .green)
            Image("TaskReactorScreen").at(123.5, 160)
            ForEach(0..<9, id: \.self) { i in
                let p = Self.cell(i)
                Rectangle()
                    .fill(failed ? Self.red : Self.blue)
                    .frame(width: 44, height: 44)
                    .opacity(failed || lit == i ? 1 : 0)
                    .at(p.x, p.y)
            }
        }
    }

    private var keypad: some View {
        ZStack {
            lights(presses, color: .green)
            Image("TaskReactorKeypad").at(123.5, 162)
            ForEach(0..<9, id: \.self) { i in
                let p = Self.cell(i)
                Image("TaskReactorButton")
                    .overlay(RoundedRectangle(cornerRadius: 4).fill(Self.blue).opacity(pressed == i ? 0.75 : 0))
                    .onTapGesture { press(i) }
                    .at(p.x, p.y)
            }
        }
        .allowsHitTesting(!showing)
    }

    private func playPattern() async {
        showing = true
        presses = 0
        try? await Task.sleep(for: .milliseconds(700))
        for i in pattern.prefix(round + 1) {
            guard !Task.isCancelled else { return }
            lit = i
            TaskSound.reactorBeep.play()
            try? await Task.sleep(for: .milliseconds(400))
            lit = nil
            try? await Task.sleep(for: .milliseconds(150))
        }
        showing = false
    }

    private func press(_ i: Int) {
        Task {
            pressed = i
            try? await Task.sleep(for: .milliseconds(150))
            if pressed == i { pressed = nil }
        }
        guard i == pattern[presses] else { fail(); return }
        TaskSound.reactorBeep.play()
        Haptics.tap()
        presses += 1
        guard presses == round + 1 else { return }
        if round + 1 == Self.rounds {
            showing = true
            onDone()
        } else {
            round += 1
        }
    }

    private func fail() {
        showing = true
        TaskSound.reactorFail.play()
        Haptics.error()
        Task {
            for _ in 0..<3 {
                failed = true
                try? await Task.sleep(for: .milliseconds(200))
                failed = false
                try? await Task.sleep(for: .milliseconds(150))
            }
            if round == 0 {
                await playPattern() // round won't change, so replay it here
            } else {
                round = 0
            }
        }
    }
}
