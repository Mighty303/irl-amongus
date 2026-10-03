import SwiftUI

/// Fix Wiring: drag each wire on the left to the same color on the right. Like the game, the left
/// side is shuffled, the right is always red/blue/yellow/magenta, and wrong connections are allowed
/// but don't count. Coordinates are pixels of the 504×504 panel art.
struct WiringGame: View {
    let onDone: () -> Void

    private static let colors: [Color] = [
        Color(red: 1, green: 0, blue: 0), Color(red: 0.15, green: 0, blue: 1),
        Color(red: 1, green: 0.92, blue: 0.02), Color(red: 1, green: 0, blue: 1),
    ]
    /// Colorblind symbols added to the game in 2020.10.22.
    private static let symbols = ["triangle.fill", "xmark", "circle.fill", "star.fill"]
    private static let slotY: [CGFloat] = [103, 207, 310, 413]
    private static let leftEnd = CGPoint(x: 52, y: 0)
    private static let rightEnd = CGPoint(x: 452, y: 0)

    /// Color of each left slot. The right slots are in color order.
    @State private var left = Array(0..<4).shuffled()
    /// Left slot -> right slot it's plugged into.
    @State private var links: [Int: Int] = [:]
    @State private var drag: (slot: Int, point: CGPoint)?
    @State private var finished = false

    var body: some View {
        SpriteStage(width: 504, height: 504) {
            ZStack {
                Image("TaskWiresBack")
                ForEach(0..<4, id: \.self) { slot in
                    stub(color: slot, at: Self.slotY[slot], leftSide: false, showsEnd: true)
                }
                ForEach(0..<4, id: \.self) { slot in
                    wire(slot)
                    stub(color: left[slot], at: Self.slotY[slot], leftSide: true, showsEnd: end(of: slot) == nil)
                        .contentShape(Rectangle().inset(by: -20))
                        .gesture(dragGesture(slot))
                }
            }
            .coordinateSpace(name: "wires")
        }
    }

    private func end(of slot: Int) -> CGPoint? {
        if let drag, drag.slot == slot { return drag.point }
        guard let target = links[slot] else { return nil }
        return CGPoint(x: Self.rightEnd.x, y: Self.slotY[target])
    }

    @ViewBuilder private func wire(_ slot: Int) -> some View {
        if let end = end(of: slot) {
            let start = CGPoint(x: Self.leftEnd.x, y: Self.slotY[slot])
            let path = Path { $0.move(to: start); $0.addLine(to: end) }
            ZStack {
                path.stroke(.black.opacity(0.6), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                path.stroke(Self.colors[left[slot]], style: StrokeStyle(lineWidth: 16, lineCap: .round))
                Image("TaskWireEnd")
                    .rotationEffect(.radians(atan2(end.y - start.y, end.x - start.x)))
                    .at(end.x, end.y)
            }
            .allowsHitTesting(false)
        }
    }

    /// The colored wire stub sticking out of a slot, with its copper end and symbol.
    private func stub(color: Int, at y: CGFloat, leftSide: Bool, showsEnd: Bool) -> some View {
        let x: CGFloat = leftSide ? 22 : 482
        return ZStack {
            Rectangle().fill(Self.colors[color]).frame(width: 44, height: 18)
                .overlay(Rectangle().stroke(.black.opacity(0.6), lineWidth: 2))
            Image(systemName: Self.symbols[color]).font(.system(size: 11, weight: .black)).foregroundStyle(.black.opacity(0.7))
        }
        .overlay(alignment: leftSide ? .trailing : .leading) {
            Image("TaskWireEnd")
                .rotationEffect(.degrees(leftSide ? 0 : 180))
                .offset(x: leftSide ? 26 : -26)
                .opacity(showsEnd ? 1 : 0)
        }
        .at(x, y)
    }

    private func dragGesture(_ slot: Int) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("wires"))
            .onChanged { value in
                guard !finished else { return }
                if drag == nil { links[slot] = nil }
                drag = (slot, value.location)
            }
            .onEnded { value in
                drag = nil
                guard !finished else { return }
                // Plug in if dropped near a right-hand socket.
                guard let target = Self.slotY.indices.first(where: {
                    abs(Self.slotY[$0] - value.location.y) < 45 && value.location.x > Self.rightEnd.x - 70
                }) else { return }
                links[slot] = target
                [TaskSound.wire1, .wire2, .wire3].randomElement()?.play()
                Haptics.tap()
                if (0..<4).allSatisfy({ links[$0] == left[$0] }) {
                    finished = true
                    onDone()
                }
            }
    }
}
