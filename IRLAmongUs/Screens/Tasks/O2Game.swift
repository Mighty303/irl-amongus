import SwiftUI

/// Clean O2 Filter: fling the six leaves into the vent on the left. Leaves keep their momentum
/// when let go, and the vent sucks in any that drift close. Coordinates are pixels of the 500×500 art.
struct O2Game: View {
    let onDone: () -> Void

    private struct Leaf: Identifiable {
        let id: Int
        let image: String
        var position: CGPoint
        var velocity = CGVector.zero
        var angle: Double
        var spin = 0.0
        var held = false
        /// Set once the vent has it: 0 → 1 as it disappears.
        var sucked: Double?
    }

    private static let vent = CGPoint(x: 60, y: 250)
    /// Leaves left of this line, within the opening's height, get pulled in.
    private static let suctionX: CGFloat = 175
    private static let openingY: ClosedRange<CGFloat> = 140...360

    @State private var leaves = O2Game.scatterLeaves()
    @State private var lastDrag: [Int: (CGPoint, Date)] = [:]
    @State private var finished = false

    var body: some View {
        SpriteStage(width: 500, height: 500) {
            ZStack {
                Image("TaskO2Base")
                ForEach(leaves) { leaf in
                    Image(leaf.image)
                        .rotationEffect(.degrees(leaf.angle))
                        .scaleEffect(1 - (leaf.sucked ?? 0) * 0.7)
                        .opacity(1 - (leaf.sucked ?? 0))
                        .gesture(drag(leaf.id))
                        .allowsHitTesting(leaf.sucked == nil)
                        .at(leaf.position.x, leaf.position.y)
                }
                Image("TaskO2Top").at(51.5, 250).allowsHitTesting(false)
                arrows.allowsHitTesting(false)
            }
            .coordinateSpace(name: "o2")
        }
        .task {
            var last = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                let now = Date()
                step(min(now.timeIntervalSince(last), 0.05))
                last = now
            }
        }
    }

    @ViewBuilder private var arrows: some View {
        if finished {
            Image("TaskO2ArrowDoneLeft").at(27, 250)
            Image("TaskO2ArrowDoneRight").at(85, 250)
        } else if leaves.contains(where: { $0.sucked == nil && $0.position.x < 230 }) {
            // The arrows flash while a leaf is near the vent.
            TimelineView(.periodic(from: .now, by: 0.15)) { context in
                let on = Int(context.date.timeIntervalSinceReferenceDate / 0.15) % 2 == 0
                ZStack {
                    Image("TaskO2ArrowFlashLeft").at(27, 250)
                    Image("TaskO2ArrowFlashRight").at(85, 250)
                }
                .opacity(on ? 1 : 0.3)
            }
        }
    }

    /// Six of the seven leaf sprites, scattered over the filter.
    private static func scatterLeaves() -> [Leaf] {
        var leaves: [Leaf] = []
        for (i, n) in Array(1...7).shuffled().prefix(6).enumerated() {
            let position = CGPoint(x: CGFloat.random(in: 240...450), y: CGFloat.random(in: 70...430))
            leaves.append(Leaf(id: i, image: "TaskO2Leaf\(n)", position: position, angle: Double.random(in: 0...360)))
        }
        return leaves
    }

    private func drag(_ id: Int) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("o2"))
            .onChanged { value in
                guard let i = leaves.firstIndex(where: { $0.id == id }), leaves[i].sucked == nil else { return }
                if !leaves[i].held { TaskSound.leafGrab.play() }
                let now = Date()
                if let (p, t) = lastDrag[id], now.timeIntervalSince(t) > 0.005 {
                    let dt = now.timeIntervalSince(t)
                    leaves[i].velocity = CGVector(dx: (value.location.x - p.x) / dt, dy: (value.location.y - p.y) / dt)
                }
                lastDrag[id] = (value.location, now)
                leaves[i].held = true
                leaves[i].position = clamp(value.location)
            }
            .onEnded { _ in
                lastDrag[id] = nil
                guard let i = leaves.firstIndex(where: { $0.id == id }) else { return }
                leaves[i].held = false
                leaves[i].spin = Double(leaves[i].velocity.dx) * 0.3
            }
    }

    private func clamp(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(480, max(105, p.x)), y: min(480, max(20, p.y)))
    }

    private func step(_ dt: Double) {
        for i in leaves.indices {
            if let s = leaves[i].sucked {
                guard s < 1 else { continue }
                leaves[i].sucked = min(1, s + dt * 4)
                leaves[i].position.x += (Self.vent.x - leaves[i].position.x) * dt * 8
                leaves[i].position.y += (Self.vent.y - leaves[i].position.y) * dt * 8
                continue
            }
            var leaf = leaves[i]
            let nearOpening = leaf.position.x < Self.suctionX && Self.openingY.contains(leaf.position.y)
            if !leaf.held {
                if nearOpening {
                    leaf.velocity.dx -= 1800 * dt
                    leaf.velocity.dy += (Self.vent.y - leaf.position.y) * 6 * dt
                }
                let friction = pow(0.15, dt)
                leaf.velocity.dx *= friction
                leaf.velocity.dy *= friction
                leaf.position.x += leaf.velocity.dx * dt
                leaf.position.y += leaf.velocity.dy * dt
                leaf.angle += leaf.spin * dt
                leaf.spin *= friction
                // Bounce off the walls, except into the opening.
                if leaf.position.x > 480 { leaf.position.x = 480; leaf.velocity.dx = -abs(leaf.velocity.dx) * 0.5 }
                if leaf.position.y < 20 { leaf.position.y = 20; leaf.velocity.dy = abs(leaf.velocity.dy) * 0.5 }
                if leaf.position.y > 480 { leaf.position.y = 480; leaf.velocity.dy = -abs(leaf.velocity.dy) * 0.5 }
                if leaf.position.x < 115 && !Self.openingY.contains(leaf.position.y) {
                    leaf.position.x = 115; leaf.velocity.dx = abs(leaf.velocity.dx) * 0.5
                }
            }
            if leaf.position.x < 112 && Self.openingY.contains(leaf.position.y) {
                leaf.sucked = 0
                leaf.held = false
                [TaskSound.leafSuck1, .leafSuck2, .leafSuck3].randomElement()?.play()
                Haptics.tap()
            }
            leaves[i] = leaf
        }
        if !finished && leaves.allSatisfy({ $0.sucked != nil }) {
            finished = true
            onDone()
        }
    }
}
