import SwiftUI

/// Prime Shields: tap the red hexagons until they're all white. Two to five start red, and tapping
/// a white one turns it red again. Coordinates are pixels of the 505×505 panel art.
struct ShieldsGame: View {
    let onDone: () -> Void

    /// Flat-top honeycomb: the center hexagon and the six around it.
    private static let cells: [CGPoint] = {
        let (w, h, gap): (CGFloat, CGFloat, CGFloat) = (152, 132, 1.04)
        let c = CGPoint(x: 252.5, y: 252.5)
        return [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: -h), CGPoint(x: 0, y: h),
                CGPoint(x: -0.75 * w, y: -h / 2), CGPoint(x: 0.75 * w, y: -h / 2),
                CGPoint(x: -0.75 * w, y: h / 2), CGPoint(x: 0.75 * w, y: h / 2)]
            .map { CGPoint(x: c.x + $0.x * gap, y: c.y + $0.y * gap) }
    }()

    @State private var red: Set<Int> = Set(Array(0..<7).shuffled().prefix(Int.random(in: 2...5)))
    @State private var finished = false

    var body: some View {
        SpriteStage(width: 505, height: 505) {
            ZStack {
                Image("TaskShieldsScreen")
                ForEach(0..<7, id: \.self) { i in
                    Image("TaskShieldsHex")
                        .colorMultiply(red.contains(i) ? Color(red: 1, green: 0.1, blue: 0.1) : .white)
                        .opacity(red.contains(i) ? 0.9 : 0.6)
                        .contentShape(Hexagon())
                        .onTapGesture { tap(i) }
                        .at(Self.cells[i].x, Self.cells[i].y)
                }
            }
        }
    }

    private func tap(_ i: Int) {
        guard !finished else { return }
        if red.remove(i) != nil {
            TaskSound.shieldOn.play()
        } else {
            red.insert(i)
            TaskSound.shieldOff.play()
        }
        Haptics.tap()
        if red.isEmpty {
            finished = true
            onDone()
        }
    }
}

/// Flat-top hexagon filling its frame, for hit testing the shield cells.
private struct Hexagon: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.midY))
            p.addLine(to: CGPoint(x: r.minX + r.width / 4, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - r.width / 4, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            p.addLine(to: CGPoint(x: r.maxX - r.width / 4, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + r.width / 4, y: r.maxY))
            p.closeSubpath()
        }
    }
}
