import SwiftUI

/// Divert Power, step 1: push the one lit switch all the way up. Its power line on the screen lights
/// up. Coordinates are pixels of the 500×500 Electrical panel art.
struct DivertPowerGame: View {
    /// Which of the eight switches to push (the art's labels are the game's rooms).
    let target: Int
    let onDone: () -> Void

    private static let trackX: [CGFloat] = [61, 115, 169, 223, 276, 330, 384, 438]
    private static let bottomY: CGFloat = 437
    private static let topY: CGFloat = 341

    @State private var y = DivertPowerGame.bottomY
    @State private var finished = false

    var body: some View {
        SpriteStage(width: 500, height: 500) {
            ZStack {
                Image("TaskDivertBase")
                // The target's node on the power diagram pulses until the power arrives.
                TimelineView(.animation(minimumInterval: 0.05, paused: finished)) { context in
                    let pulse = finished ? 1 : 0.5 + 0.5 * sin(context.date.timeIntervalSinceReferenceDate * 6)
                    Circle().fill(Color.yellow).frame(width: 14, height: 14)
                        .shadow(color: .yellow, radius: 8)
                        .opacity(pulse)
                        .at(Self.trackX[target], 161)
                }
                ForEach(0..<8, id: \.self) { i in
                    Image("TaskDivertSwitch")
                        .saturation(i == target ? 1 : 0)
                        .brightness(i == target ? 0 : -0.25)
                        .at(Self.trackX[i], i == target ? y : Self.bottomY)
                }
                Color.clear.frame(width: 70, height: 160)
                    .contentShape(Rectangle())
                    .gesture(drag)
                    .at(Self.trackX[target], (Self.topY + Self.bottomY) / 2)
            }
            .coordinateSpace(name: "divert")
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("divert"))
            .onChanged { value in
                guard !finished else { return }
                y = min(Self.bottomY, max(Self.topY, value.location.y))
                if y <= Self.topY + 4 {
                    finished = true
                    y = Self.topY
                    TaskSound.divert.play()
                    Haptics.tap()
                    onDone()
                }
            }
            .onEnded { _ in
                guard !finished else { return }
                withAnimation(.easeOut(duration: 0.2)) { y = Self.bottomY }
            }
    }
}

/// Divert Power, step 2 (Accept Diverted Power): tap the fuse to turn it and connect the circuit.
/// Coordinates are pixels of the 424×250 panel art.
struct AcceptPowerGame: View {
    let onDone: () -> Void
    @State private var turned = false

    var body: some View {
        SpriteStage(width: 424, height: 250) {
            ZStack {
                Image("TaskDivertAcceptBase")
                    .overlay(Color.yellow.opacity(turned ? 0.2 : 0).blendMode(.screen))
                Image("TaskDivertAcceptSwitch")
                    .rotationEffect(.degrees(turned ? 90 : 0))
                    .frame(width: 70, height: 70)
                    .contentShape(Rectangle())
                    .onTapGesture { turn() }
                    .at(212, 126)
            }
        }
    }

    private func turn() {
        guard !turned else { return }
        withAnimation(.easeInOut(duration: 0.25)) { turned = true }
        TaskSound.accept.play()
        Haptics.tap()
        onDone()
    }
}
