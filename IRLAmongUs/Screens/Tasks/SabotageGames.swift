import SwiftUI

/// Reactor meltdown, like Among Us: hold your hand on the scanner. Both reactor scanners have to be held at the
/// same moment, so it takes two people in two places. `onHold` reports pressing and letting go; the host checks
/// in with the server every half second while held. Coordinates are pixels of the 500×500 art.
struct ReactorHandGame: View {
    /// Someone has a hand on the other scanner right now.
    let otherHeld: Bool
    let onHold: (Bool) -> Void

    @State private var holding = false

    private var status: String {
        if !holding { return "HOLD TO STOP MELTDOWN" }
        return otherHeld ? "HOLD STEADY…" : "WAITING FOR SECOND USER"
    }

    var body: some View {
        SpriteStage(width: 500, height: 500) {
            ZStack {
                // The hand on the art is see-through: light, turning blue while a hand is on it.
                Rectangle().fill(holding ? Color(red: 0.45, green: 0.8, blue: 1) : Color(white: 0.88))
                    .frame(width: 340, height: 380).at(250, 290)
                Image("SabotageReactorHand")
                if holding {
                    // The scan line sweeping up and down the hand.
                    TimelineView(.animation) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        Image("SabotageReactorGlow")
                            .colorMultiply(.cyan)
                            .at(250, 290 + sin(t * 3) * 170)
                    }
                    .allowsHitTesting(false)
                }
                Text(status)
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(holding && otherHeld ? Color(red: 0, green: 0.55, blue: 0.2) : .black)
                    .minimumScaleFactor(0.6).lineLimit(1)
                    .frame(width: 400)
                    .at(250, 53)
            }
            .frame(width: 500, height: 500)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !holding else { return }
                        holding = true
                        TaskSound.scan.play()
                        onHold(true)
                    }
                    .onEnded { _ in
                        holding = false
                        TaskSound.scan.stop()
                        onHold(false)
                    }
            )
        }
        .onDisappear { if holding { onHold(false) } }
        .accessibilityElement()
        .accessibilityLabel("Reactor hand scanner. \(status.lowercased())")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }
}

/// Oxygen depleted, like Among Us: the code is on the sticky note; type it on the keypad and press ✓. `submit`
/// sends it to the server; `wrongAttempts` going up means it was refused. Coordinates are pixels of the art:
/// the note on the left, the 374×503 keypad on the right.
struct OxygenKeypadGame: View {
    let code: String
    /// This keypad is fixed.
    let done: Bool
    let wrongAttempts: Int
    let submit: (String) -> Void

    @State private var typed = ""
    @State private var showingWrong = false

    private static let keypadX: CGFloat = 266
    /// Centres of the keys on the keypad art: three columns, four rows (X, 0, ✓ at the bottom).
    private static let columns: [CGFloat] = [98, 187, 277]
    private static let rows: [CGFloat] = [163, 254, 344, 433]
    private static let keys: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["X", "0", "✓"]]

    var body: some View {
        SpriteStage(width: 640, height: 503) {
            ZStack(alignment: .topLeading) {
                Image("SabotageKeypadNote").at(122, 190)
                Text(code)
                    .font(.custom("Noteworthy-Bold", size: 38))
                    .foregroundStyle(.black.opacity(0.85))
                    .rotationEffect(.degrees(-8))
                    .at(118, 185)
                    .accessibilityLabel("Code on the note: \(code.map(String.init).joined(separator: " "))")
                Image("SabotageKeypad").at(Self.keypadX + 187, 251.5)
                Text(display)
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundStyle(done ? .green : showingWrong ? .red : .white)
                    .at(Self.keypadX + 189, 69)
                ForEach(0..<4, id: \.self) { row in
                    ForEach(0..<3, id: \.self) { column in
                        let key = Self.keys[row][column]
                        Color.clear
                            .frame(width: 82, height: 82)
                            .contentShape(Rectangle())
                            .onTapGesture { press(key) }
                            .at(Self.keypadX + Self.columns[column], Self.rows[row])
                            .accessibilityElement()
                            .accessibilityLabel(key == "X" ? "Clear" : key == "✓" ? "Enter" : key)
                            .accessibilityAddTraits(.isButton)
                    }
                }
            }
            .frame(width: 640, height: 503)
        }
        .allowsHitTesting(!done)
        .onChange(of: wrongAttempts) { _, _ in
            typed = ""
            showingWrong = true
            TaskSound.cardDeny.play()
            Task {
                try? await Task.sleep(for: .milliseconds(900))
                showingWrong = false
            }
        }
    }

    private var display: String {
        if done { return "OK" }
        if showingWrong { return "WRONG" }
        return typed
    }

    private func press(_ key: String) {
        switch key {
        case "X":
            typed = ""
            TaskSound.select.play()
        case "✓":
            guard typed.count == code.count else { TaskSound.cardDeny.play(); return }
            submit(typed)
        default:
            guard typed.count < code.count else { return }
            typed += key
            TaskSound.select.play()
        }
    }
}
