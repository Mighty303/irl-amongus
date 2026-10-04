import SwiftUI

/// The in-game map: zoomed in to a little more than a room across, and locked on the player, who stays
/// in the middle while the floor plan glides underneath. Pinch changes how much it shows (within limits);
/// there's no panning. Task signs off the edge get an arrow with their distance.
struct FollowFloorMap: View {
    let rooms: [POCRoom]
    /// This player's task pins (`.task`, tappable) and every other sign.
    let stations: [POCStation]
    let completedStationIDs: Set<String>
    let meetingPoint: CGPoint?
    let players: [POCPlayerDot]
    /// x = longitude, y = latitude: what stays in the middle (the player).
    let center: CGPoint
    /// Whether `center` is a live estimate (YOU marker) or just a fallback spot.
    let centerIsPlayer: Bool
    let onSelectStation: (POCStation) -> Void

    /// Meters across the shorter side: a little over a room's width.
    @State private var spanM: Double = 16
    @GestureState private var pinch: CGFloat = 1
    /// The floor plan is drawn around this point (three views wide) and slid so `center` stays put;
    /// it moves when the player gets far from it.
    @State private var anchor: CGPoint?

    private static let minSpan = 8.0
    private static let maxSpan = 120.0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let span = min(max(spanM / Double(pinch), Self.minSpan), Self.maxSpan)
            let ppm = min(size.width, size.height) / span // points per meter
            let a = anchor ?? center
            let big = CGSize(width: size.width * 3, height: size.height * 3)
            let projection = LocalProjection(anchor: a, pointsPerMeter: ppm, origin: CGPoint(x: big.width / 2, y: big.height / 2))
            let pc = projection.point(center)
            let slide = CGSize(width: big.width / 2 - pc.x, height: big.height / 2 - pc.y)

            ZStack {
                RoundedRectangle(cornerRadius: 22).fill(Color(red: 0.06, green: 0.09, blue: 0.11))

                ZStack {
                    Canvas { context, _ in
                        for room in rooms {
                            let path = projection.path(room)
                            let corridor = room.roomType.localizedCaseInsensitiveContains("corridor")
                            context.fill(path, with: .color(corridor ? .cyan.opacity(0.10) : .white.opacity(0.12)))
                            context.stroke(path, with: .color(.white.opacity(0.4)), lineWidth: 1)
                        }
                        // At this zoom every room can carry its name.
                        for room in rooms where room.priority > 5 {
                            let p = projection.point(room.center)
                            guard p.x > -40, p.y > -40, p.x < big.width + 40, p.y < big.height + 40 else { continue }
                            context.draw(Text(room.label.count > 22 ? room.roomID : room.label)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6)), at: p)
                        }
                    }
                    .frame(width: big.width, height: big.height)

                    ForEach(players.filter { !$0.isMe || !centerIsPlayer }) { player in
                        dot(player, at: projection.point(player.position), ppm: ppm)
                    }
                    if let me = players.first(where: \.isMe), centerIsPlayer {
                        // Your uncertainty circle; the YOU marker itself sits fixed in the middle.
                        Circle().fill(Color.cyan.opacity(0.14)).overlay(Circle().stroke(.cyan.opacity(0.6), lineWidth: 1))
                            .frame(width: max(ppm * me.accuracyM * 2, 6), height: max(ppm * me.accuracyM * 2, 6))
                            .position(pc)
                            .allowsHitTesting(false)
                    }
                    if let meetingPoint {
                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 28, height: 28).background(.red, in: Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                            .position(projection.point(meetingPoint))
                            .accessibilityLabel("Meeting point")
                    }
                    ForEach(stations) { station in
                        pin(station).position(projection.point(station.position))
                    }
                }
                .frame(width: big.width, height: big.height)
                .offset(slide)
                .animation(.easeInOut(duration: 0.8), value: pc)
                .frame(width: size.width, height: size.height)

                if centerIsPlayer {
                    you.allowsHitTesting(false)
                }
                taskArrows(projection: projection, pc: pc, size: size, ppm: ppm)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .contentShape(Rectangle())
            .gesture(
                MagnificationGesture()
                    .updating($pinch) { value, state, _ in state = value }
                    .onEnded { value in spanM = min(max(spanM / Double(value), Self.minSpan), Self.maxSpan) }
            )
            .onAppear { anchor = center }
            .onChange(of: center) { _, new in
                // Far from where the plan is drawn: redraw around here, without sliding.
                let off = LocalProjection(anchor: a, pointsPerMeter: 1, origin: .zero).point(new)
                if hypot(off.x, off.y) > span {
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) { anchor = new }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map.floorPlan")
        .accessibilityLabel("Map, centered on you. Pinch to zoom.")
    }

    // MARK: - Pieces

    private var you: some View {
        VStack(spacing: 0) {
            Image("PlayerMarker").resizable().scaledToFit().frame(width: 40, height: 40)
                .shadow(color: .cyan.opacity(0.75), radius: 6)
            Text("YOU")
                .font(.system(size: 8, weight: .black, design: .rounded)).foregroundStyle(.black)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.cyan, in: Capsule())
        }
        .offset(y: -12) // the marker's feet on the spot
        .accessibilityIdentifier("map.ownPosition")
        .accessibilityLabel("You")
    }

    @ViewBuilder private func pin(_ station: POCStation) -> some View {
        if station.style == .task {
            let done = completedStationIDs.contains(station.id)
            Button { onSelectStation(station) } label: {
                VStack(spacing: 2) {
                    Image(systemName: done ? "checkmark" : "wrench.and.screwdriver.fill")
                        .font(.caption.weight(.black)).foregroundStyle(.black)
                        .frame(width: 30, height: 30)
                        .background(done ? Color.green : Color.orange, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 2))
                    Text(station.pinLabel)
                        .font(.system(size: 8, weight: .black, design: .rounded)).foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.black.opacity(0.76), in: Capsule())
                }
            }
            .buttonStyle(.plain)
            .opacity(station.faded ? 0.5 : 1)
            .accessibilityLabel("\(station.displayName) task\(done ? ", done" : "")")
        } else {
            VStack(spacing: 2) {
                Image(systemName: station.style.icon)
                    .font(.system(size: station.style == .sign ? 9 : 11, weight: .black)).foregroundStyle(.white)
                    .frame(width: station.style == .sign ? 18 : 26, height: station.style == .sign ? 18 : 26)
                    .background(station.style.color, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 1.5))
                if station.style != .sign || station.faded {
                    Text(station.pinLabel)
                        .font(.system(size: 7, weight: .black, design: .rounded)).foregroundStyle(.white)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(.black.opacity(0.76), in: Capsule())
                }
            }
            .opacity(station.faded ? 0.45 : 1)
            .allowsHitTesting(false)
            .accessibilityLabel("\(station.displayName) sign")
        }
    }

    private func dot(_ player: POCPlayerDot, at p: CGPoint, ppm: CGFloat) -> some View {
        ZStack {
            Circle().fill(player.color.opacity(player.faded ? 0.07 : 0.16))
                .overlay(Circle().stroke(player.color.opacity(player.faded ? 0.3 : 0.75), lineWidth: 1))
                .frame(width: max(ppm * player.accuracyM * 2, 6), height: max(ppm * player.accuracyM * 2, 6))
            VStack(spacing: 1) {
                Circle().fill(player.color).frame(width: 16, height: 16).overlay(Circle().stroke(.white, lineWidth: 2))
                Text(player.name)
                    .font(.system(size: 8, weight: .black, design: .rounded)).foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(.black.opacity(0.76), in: Capsule())
            }
            .opacity(player.faded ? 0.45 : 1)
        }
        .position(p)
        .allowsHitTesting(false)
        .accessibilityLabel("\(player.name), within about \(Int(player.accuracyM.rounded())) meters")
    }

    /// Arrows on the edge toward task signs that are off screen, with how far away they are.
    private func taskArrows(projection: LocalProjection, pc: CGPoint, size: CGSize, ppm: CGFloat) -> some View {
        let middle = CGPoint(x: size.width / 2, y: size.height / 2)
        let inset: CGFloat = 22
        let due = stations.filter { $0.style == .task && !completedStationIDs.contains($0.id) }
        return ForEach(due) { station in
            let p = projection.point(station.position)
            let v = CGPoint(x: middle.x + (p.x - pc.x), y: middle.y + (p.y - pc.y))
            if v.x < inset || v.y < inset || v.x > size.width - inset || v.y > size.height - inset {
                let dx = v.x - middle.x, dy = v.y - middle.y
                let k = min((size.width / 2 - inset) / max(abs(dx), 0.001), (size.height / 2 - inset) / max(abs(dy), 0.001))
                let edge = CGPoint(x: middle.x + dx * k, y: middle.y + dy * k)
                let meters = hypot(dx, dy) / ppm
                Button { onSelectStation(station) } label: {
                    VStack(spacing: 0) {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 14, weight: .black)).foregroundStyle(.orange)
                            .rotationEffect(.radians(atan2(dx, -dy)))
                        Text("\(Int(meters.rounded())) m")
                            .font(.system(size: 8, weight: .black, design: .rounded)).foregroundStyle(.white)
                            .padding(.horizontal, 4).background(.black.opacity(0.7), in: Capsule())
                    }
                }
                .buttonStyle(.plain)
                .position(edge)
                .accessibilityLabel("\(station.displayName), \(Int(meters.rounded())) meters away")
            }
        }
    }
}

/// Flat-earth projection in meters around an anchor point (x = longitude, y = latitude), for a small area.
struct LocalProjection {
    let anchor: CGPoint
    let pointsPerMeter: CGFloat
    let origin: CGPoint

    func point(_ c: CGPoint) -> CGPoint {
        let kx = cos(Double(anchor.y) * .pi / 180) * 111_320
        return CGPoint(x: origin.x + CGFloat(Double(c.x - anchor.x) * kx) * pointsPerMeter,
                       y: origin.y - CGFloat(Double(c.y - anchor.y) * 111_320) * pointsPerMeter)
    }

    func path(_ room: POCRoom) -> Path {
        var path = Path()
        for ring in room.rings {
            guard let first = ring.first else { continue }
            path.move(to: point(first))
            for c in ring.dropFirst() { path.addLine(to: point(c)) }
            path.closeSubpath()
        }
        return path
    }
}
