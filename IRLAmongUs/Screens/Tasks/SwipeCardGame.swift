import SwiftUI

/// Swipe Card: tap the card to take it out of the wallet, then swipe it through the reader in one
/// steady motion. Too fast, too slow, or letting go early fails with the game's messages.
/// Coordinates are pixels of the 500×500 panel art.
struct SwipeCardGame: View {
    let onDone: () -> Void

    /// Seconds a swipe may take, start to end of the reader. The game's window is similarly tight.
    static let acceptedSeconds = 0.5...1.0

    private static let readerY: CGFloat = 190
    private static let startX: CGFloat = 125
    private static let endX: CGFloat = 375
    private static let walletCard = CGPoint(x: 150, y: 382)

    private enum Light { case none, red, green }

    @State private var inReader = false
    @State private var cardX = SwipeCardGame.startX
    @State private var message = "Please insert card"
    @State private var light = Light.none
    @State private var swipeStart: Date?
    @State private var reachedEnd: Date?
    @State private var finished = false

    var body: some View {
        SpriteStage(width: 500, height: 500) {
            ZStack {
                Image("TaskCardBackground")
                Image("TaskCardReaderTop").at(250, 85.5)
                Text(message.uppercased())
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .frame(width: 400)
                    .at(250, 31)
                lightGlow(.red, on: light == .red).at(424, 131)
                lightGlow(.green, on: light == .green).at(463, 131)
                Image("TaskCardWallet").at(250, 416)
                Image("TaskCard")
                    .at(inReader ? cardX : Self.walletCard.x, inReader ? Self.readerY : Self.walletCard.y)
                    .gesture(swipe, including: inReader ? .all : .subviews)
                    .onTapGesture { takeOut() }
                Image("TaskCardReaderBottom").at(250, 232).allowsHitTesting(false)
                if !inReader { Image("TaskCardWalletFront").at(139, 457).allowsHitTesting(false) }
            }
            .coordinateSpace(name: "card")
        }
    }

    private func lightGlow(_ color: Color, on: Bool) -> some View {
        Circle().fill(color).frame(width: 24, height: 24)
            .shadow(color: color, radius: 10)
            .opacity(on ? 1 : 0)
            .allowsHitTesting(false)
    }

    private func takeOut() {
        guard !inReader else { return }
        TaskSound.walletOut.play()
        withAnimation(.easeOut(duration: 0.3)) { inReader = true }
        message = "Please swipe card"
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("card"))
            .onChanged { value in
                guard !finished else { return }
                if swipeStart == nil {
                    swipeStart = Date()
                    reachedEnd = nil
                    light = .none
                    message = "Please swipe card"
                    TaskSound.cardMove.play()
                }
                let x = Self.startX + value.translation.width
                cardX = min(Self.endX, max(Self.startX, x))
                if cardX >= Self.endX, reachedEnd == nil { reachedEnd = Date() }
            }
            .onEnded { _ in
                guard !finished, let swipeStart else { return }
                self.swipeStart = nil
                guard let reachedEnd else { return fail("Bad read. Try again.") }
                let seconds = reachedEnd.timeIntervalSince(swipeStart)
                if seconds < Self.acceptedSeconds.lowerBound { return fail("Too fast. Try again.") }
                if seconds > Self.acceptedSeconds.upperBound { return fail("Too slow. Try again.") }
                finished = true
                light = .green
                message = "Accepted. Thank you."
                TaskSound.cardAccept.play()
                onDone()
            }
    }

    private func fail(_ text: String) {
        light = .red
        message = text
        TaskSound.cardDeny.play()
        Haptics.error()
        withAnimation(.easeOut(duration: 0.2)) { cardX = Self.startX }
    }
}
