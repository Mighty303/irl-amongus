import SwiftUI

/// The in-game map: zoomed in to a little more than a room across, and locked on the player, who stays
/// in the middle while the floor plan glides underneath. The zoom is fixed and there's no panning:
/// seeing further than you could in person would be cheating (ghosts may pinch to zoom). Task signs off
/// the edge get an arrow with their distance.
///
/// Fog of war, like Among Us vision: you see out to `visionM`, and walls block the view, so other rooms
/// are dark. Other players only show where you can see them; your task signs, the red button and the
/// special signs stay visible on top so you can find them.
struct FollowFloorMap: View {
    let rooms: [POCRoom]
    /// This player's task pins (`.task`) and the special signs, all tappable.
    let stations: [POCStation]
    let completedStationIDs: Set<String>
    let meetingPoint: CGPoint?
    let players: [POCPlayerDot]
    /// x = longitude, y = latitude: what stays in the middle (the player).
    let center: CGPoint
    /// Whether `center` is a live estimate (YOU marker) or just a fallback spot.
    let centerIsPlayer: Bool
    /// How far you can see, meters; nil = no fog (ghosts, or no position yet).
    var visionM: Double? = nil
    /// Your suit colour, for the YOU crewmate.
    var myColor: PlayerColor? = nil
    var myFaceURL: URL? = nil
    /// Dead: your marker is see-through, like an Among Us ghost, and you can zoom.
    var isGhost = false
    /// A reactor or O2 sabotage: the arrows point at its signs and flash red, like Among Us.
    var crisis = false
    /// Unfound bodies, in their colours: yours (always shown) and others' when your vision reaches them.
    var bodies: [MapBody] = []
    let onSelectStation: (POCStation) -> Void

    /// Meters across the shorter side: a little over a room's width. Fixed for the living, so nobody can
    /// zoom out to look around; ghosts can pinch between `minSpan` and `maxSpan`.
    private static let spanM: Double = 16
    private static let minSpan = 8.0
    private static let maxSpan = 150.0
    @State private var ghostSpan = FollowFloorMap.spanM
    @GestureState private var pinch: CGFloat = 1
    /// The floor plan is drawn around this point (three views wide) and slid so `center` stays put;
    /// it moves when the player gets far from it.
    @State private var anchor: CGPoint?

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let span = isGhost ? min(max(ghostSpan / Double(pinch), Self.minSpan), Self.maxSpan) : Self.spanM
            let ppm = min(size.width, size.height) / span // points per meter
            let a = anchor ?? center
            let big = CGSize(width: size.width * 3, height: size.height * 3)
            let projection = LocalProjection(anchor: a, pointsPerMeter: ppm, origin: CGPoint(x: big.width / 2, y: big.height / 2))
            let pc = projection.point(center)
            let slide = CGSize(width: big.width / 2 - pc.x, height: big.height / 2 - pc.y)
            let sight = visionM.map { Vision(center: center, radiusM: $0, rooms: rooms) }

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

                    // Other signs sit under the fog; other players only appear where you can see them.
                    ForEach(stations.filter { $0.style == .sign }) { station in
                        pin(station).position(projection.point(station.position))
                    }
                    ForEach(players.filter { ($0.isMe ? !centerIsPlayer : true) && (sight?.canSee($0.position) ?? true) }) { player in
                        dot(player, at: projection.point(player.position), ppm: ppm)
                    }
                    if let sight {
                        Canvas { context, canvasSize in
                            var fog = Path(CGRect(origin: .zero, size: canvasSize))
                            fog.addPath(sight.path(around: pc, pointsPerMeter: ppm))
                            context.addFilter(.blur(radius: 5))
                            context.fill(fog, with: .color(.black.opacity(0.82)), style: FillStyle(eoFill: true))
                        }
                        .frame(width: big.width, height: big.height)
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
                    ForEach(stations.filter { $0.style != .sign }) { station in
                        pin(station).position(projection.point(station.position))
                    }
                    ForEach(bodies.filter { $0.mine || (sight?.canSee($0.position) ?? true) }) { body in
                        Image(uiImage: BodyReportArtwork.corpse(color: body.color))
                            .resizable().interpolation(.high).scaledToFit()
                            .frame(width: 56, height: 36)
                            .shadow(color: .black.opacity(0.7), radius: 3)
                            .position(projection.point(body.position))
                            .allowsHitTesting(false)
                            .accessibilityLabel(body.mine ? "Your body" : "A body")
                    }
                }
                .frame(width: big.width, height: big.height)
                .offset(slide)
                // Glide only when the player moves. Keyed on the projected point, a resize (rotation, layout)
                // or a redraw around a new anchor animated every pin across the screen while the plan jumped.
                .animation(.easeInOut(duration: 0.8), value: center)
                .frame(width: size.width, height: size.height)

                if centerIsPlayer {
                    you.allowsHitTesting(false)
                }
                taskArrows(projection: projection, pc: pc, size: size, ppm: ppm)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .contentShape(Rectangle())
            .simultaneousGesture(
                MagnificationGesture()
                    .updating($pinch) { value, state, _ in state = value }
                    .onEnded { value in ghostSpan = min(max(ghostSpan / Double(value), Self.minSpan), Self.maxSpan) },
                including: isGhost ? .all : .none
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
        .accessibilityLabel("Map, centered on you")
    }

    // MARK: - Pieces

    private var you: some View {
        VStack(spacing: 0) {
            CrewmateView(color: myColor ?? .red, faceURL: myFaceURL, height: 40)
                .opacity(isGhost ? 0.5 : 1)
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
            // Among Us map style: a yellow "!" for each task still to do; finished ones leave the map.
            if !completedStationIDs.contains(station.id) {
                Button { onSelectStation(station) } label: {
                    AmongUsTaskMarker(size: 44)
                        .frame(width: 64, height: 64)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(station.faded ? 0.5 : 1)
                .accessibilityLabel("\(station.displayName) task")
            }
        } else {
            // Special signs open their card (photo, what to scan), like a task's "!".
            Button { onSelectStation(station) } label: { SignPinView(station: station) }
                .buttonStyle(.plain)
                .disabled(station.style == .sign)
            .accessibilityLabel("\(station.displayName) sign")
        }
    }

    /// Just the player's dot and name; the uncertainty circles are only on the live map (testing).
    private func dot(_ player: POCPlayerDot, at p: CGPoint, ppm: CGFloat) -> some View {
        ZStack {
            VStack(spacing: 0) {
                // Their crewmate in their suit colour, like your own marker.
                if let suit = player.playerColor {
                    CrewmateView(color: suit, faceURL: player.faceURL, height: 30)
                } else {
                    Circle().fill(player.color).frame(width: 16, height: 16).overlay(Circle().stroke(.white, lineWidth: 2))
                }
                Text(player.name)
                    .font(.system(size: 8, weight: .black, design: .rounded)).foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(.black.opacity(0.76), in: Capsule())
            }
            .opacity(player.faded ? 0.45 : 1)
        }
        .position(p)
        .allowsHitTesting(false)
        .accessibilityLabel(player.name)
    }

    /// Arrows on the edge toward task signs that are off screen, with how far away they are.
    private func taskArrows(projection: LocalProjection, pc: CGPoint, size: CGSize, ppm: CGFloat) -> some View {
        let middle = CGPoint(x: size.width / 2, y: size.height / 2)
        let inset: CGFloat = 26
        let due = crisis ? stations.filter { $0.style == .reactor || $0.style == .oxygen }
            : stations.filter { $0.style == .task && !completedStationIDs.contains($0.id) }
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
                        MapArrow(crisis: crisis).rotationEffect(.radians(atan2(dy, dx)))
                        Text("\(Int(meters.rounded())) m")
                            .font(.system(size: 9, weight: .black, design: .rounded)).foregroundStyle(.white)
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

/// What the player can see: rays out to the vision radius, each stopped by the first wall (room edge)
/// it meets. Worked out in meters around the player.
struct Vision {
    /// Ray end points, meters east/north of the player, all the way round.
    let outline: [CGPoint]
    private let center: CGPoint
    private let kx: Double
    private static let rays = 240

    init(center: CGPoint, radiusM: Double, rooms: [POCRoom]) {
        let kx = cos(Double(center.y) * .pi / 180) * 111_320
        self.center = center
        self.kx = kx
        func local(_ c: CGPoint) -> CGPoint {
            CGPoint(x: Double(c.x - center.x) * kx, y: Double(c.y - center.y) * 111_320)
        }
        // Walls near enough to matter, each stretched 15 cm at both ends so neighbouring rooms'
        // edges overlap and rays can't slip through the hairline gaps between them.
        var walls: [(CGPoint, CGPoint)] = []
        let reach = radiusM + 2
        for room in rooms {
            for ring in room.rings where ring.count > 1 {
                let pts = ring.map(local)
                for i in pts.indices {
                    var a = pts[i], b = pts[(i + 1) % pts.count]
                    if min(a.x, b.x) > reach || max(a.x, b.x) < -reach || min(a.y, b.y) > reach || max(a.y, b.y) < -reach { continue }
                    let len = hypot(b.x - a.x, b.y - a.y)
                    guard len > 0.01 else { continue }
                    let ux = (b.x - a.x) / len * 0.15, uy = (b.y - a.y) / len * 0.15
                    a = CGPoint(x: a.x - ux, y: a.y - uy)
                    b = CGPoint(x: b.x + ux, y: b.y + uy)
                    walls.append((a, b))
                }
            }
        }
        outline = (0..<Self.rays).map { i in
            let angle = Double(i) / Double(Self.rays) * 2 * .pi
            let dx = cos(angle), dy = sin(angle)
            var nearest = radiusM
            for (a, b) in walls {
                // Ray (t·d) against segment a + u·(b − a).
                let ex = Double(b.x - a.x), ey = Double(b.y - a.y)
                let denom = dx * ey - dy * ex
                guard abs(denom) > 1e-9 else { continue }
                let ax = Double(a.x), ay = Double(a.y)
                let t = (ax * ey - ay * ex) / denom
                let u = (ax * dy - ay * dx) / denom
                // Ignore walls right on top of us (standing on a line), so we never see nothing at all.
                if t > 0.2, u >= 0, u <= 1, t < nearest { nearest = t }
            }
            return CGPoint(x: dx * nearest, y: dy * nearest)
        }
    }

    /// The visible area in view points, around the player's point `pc`.
    func path(around pc: CGPoint, pointsPerMeter ppm: CGFloat) -> Path {
        var path = Path()
        for (i, p) in outline.enumerated() {
            let q = CGPoint(x: pc.x + p.x * ppm, y: pc.y - p.y * ppm)
            if i == 0 { path.move(to: q) } else { path.addLine(to: q) }
        }
        path.closeSubpath()
        return path
    }

    /// Whether a spot (x = longitude, y = latitude) is in view.
    func canSee(_ c: CGPoint) -> Bool {
        let p = CGPoint(x: Double(c.x - center.x) * kx, y: Double(c.y - center.y) * 111_320)
        var inside = false
        var j = outline.count - 1
        for i in outline.indices {
            let a = outline[i], b = outline[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
            j = i
        }
        return inside
    }
}

/// The Among Us map's task marker: a yellow exclamation mark with a black outline.
struct AmongUsTaskMarker: View {
    static let yellow = Color(red: 1, green: 0.89, blue: 0.2)
    var size: CGFloat = 28

    var body: some View {
        let glyph = Text("!").font(.system(size: size, weight: .black, design: .rounded))
        ZStack {
            // The outline: the glyph in black, nudged all the way round.
            ForEach(0..<12, id: \.self) { i in
                let angle = Double(i) * .pi / 6
                glyph.foregroundStyle(.black).offset(x: cos(angle) * size / 11, y: sin(angle) * size / 11)
            }
            glyph.foregroundStyle(Self.yellow)
        }
        .accessibilityHidden(true)
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

/// Among Us's arrow toward something off the map: yellow toward tasks; in a crisis it flashes between yellow
/// and red, as the game's does. (The sprite is light and pointing right; it's tinted here.)
struct MapArrow: View {
    var crisis = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.4)) { timeline in
            let red = crisis && Int(timeline.date.timeIntervalSinceReferenceDate / 0.4) % 2 == 0
            Image("MapArrow")
                .resizable().interpolation(.high).scaledToFit()
                .frame(width: 52, height: 44)
                .colorMultiply(red ? Color(red: 1, green: 0.2, blue: 0.2) : AmongUsTaskMarker.yellow)
                .shadow(color: .black.opacity(0.6), radius: 2)
        }
        .accessibilityHidden(true)
    }
}

/// A body on the map (x = longitude, y = latitude), in the dead player's colour.
struct MapBody: Identifiable {
    let id: String
    let position: CGPoint
    let color: PlayerColor
    /// Your own: always shown. Others' only where you can see.
    var mine = false
}
