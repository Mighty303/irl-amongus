import SwiftUI

/// What the killer sees after a kill (the victim gets the full kill animation): a slash cut across the screen,
/// white-hot with a red glow, and a quick red flash. About half a second, then gone.
struct KillSlashView: View {
    var onFinished: () -> Void = {}
    /// Hold it at this many seconds in (previews and tests).
    var frozenAt: Double? = nil
    @State private var start = Date()

    private static let cut = 0.14
    private static let hold = 0.22
    private static let fade = 0.3

    /// A curved blade from `from` to `to`: pointed at both ends, `width` across at its widest.
    private static func blade(from: CGPoint, to: CGPoint, width: CGFloat) -> Path {
        let dx = to.x - from.x, dy = to.y - from.y
        let length = max(hypot(dx, dy), 0.001)
        let normal = CGPoint(x: -dy / length, y: dx / length)
        let mid = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
        return Path { path in
            path.move(to: from)
            path.addQuadCurve(to: to, control: CGPoint(x: mid.x + normal.x * width, y: mid.y + normal.y * width))
            path.addQuadCurve(to: from, control: CGPoint(x: mid.x + normal.x * width * 0.2, y: mid.y + normal.y * width * 0.2))
            path.closeSubpath()
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = frozenAt ?? timeline.date.timeIntervalSince(start)
            let progress = min(1, t / Self.cut)
            let opacity = t < Self.hold ? 1 : max(0, 1 - (t - Self.hold) / Self.fade)
            GeometryReader { geo in
                let size = geo.size
                let from = CGPoint(x: size.width * 0.86, y: size.height * 0.08)
                let to = CGPoint(x: size.width * 0.14, y: size.height * 0.92)
                let tip = CGPoint(x: from.x + (to.x - from.x) * progress, y: from.y + (to.y - from.y) * progress)
                ZStack {
                    Color.red.opacity(0.28 * opacity)
                    Self.blade(from: from, to: tip, width: 34).fill(Color.red.opacity(0.75)).blur(radius: 12)
                    Self.blade(from: from, to: tip, width: 22).fill(Color(red: 1, green: 0.22, blue: 0.22))
                    Self.blade(from: from, to: tip, width: 9).fill(.white)
                }
                .opacity(opacity)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            start = .now
            try? await Task.sleep(for: .seconds(Self.hold + Self.fade + 0.05))
            if !Task.isCancelled { onFinished() }
        }
    }
}
