import SwiftUI

extension GameState {
    /// Pins for every sign with a location that isn't already a task pin: special signs by kind
    /// (red button, reactor, lights, security, admin) and other signs as small grey pins. The meeting
    /// point is drawn by the floor plan itself.
    /// The game map passes `includeMeeting` (the meeting point as a tappable pin) and leaves out other
    /// players' plain signs (`includeSigns: false`), which mean nothing to you in a game.
    func otherSignPins(excluding taskPinIds: Set<String>, campus: CampusView = CampusView(),
                       includeSigns: Bool = true, includeMeeting: Bool = false) -> [POCStation] {
        stations.compactMap { s in
            guard !taskPinIds.contains(s.id), includeMeeting || s.kind != .meeting, includeSigns || s.kind != .task,
                  let lat = s.lat, let lng = s.lng else { return nil }
            let label = s.kind == .task ? (s.signText ?? s.name) : s.kind.shortLabel
            let offFloor = campus.isOffFloor(buildingId: s.buildingId, floorId: s.floorId)
            return POCStation(id: s.id, displayName: s.signText ?? s.name, taskType: s.kind.label,
                              roomID: String(label.prefix(10)), roomLabel: s.name,
                              position: CGPoint(x: lng, y: lat), style: POCPinStyle(s.kind),
                              faded: offFloor, floorNote: offFloor ? s.floorId : nil)
        }
    }

    var locatedStationPoints: [CGPoint] {
        stations.compactMap { s in s.lat.flatMap { lat in s.lng.map { CGPoint(x: $0, y: lat) } } }
    }

    var meetingPointPin: CGPoint? {
        guard let m = stations.first(where: { $0.kind == .meeting }), let lat = m.lat, let lng = m.lng else { return nil }
        return CGPoint(x: lng, y: lat)
    }
}

extension StationKind {
    /// Label under a special sign's map pin.
    var shortLabel: String {
        switch self {
        case .task: return "SIGN"
        case .meeting: return "MEETING"
        case .emergency: return "BUTTON"
        case .reactor: return "REACTOR"
        case .electrical: return "LIGHTS"
        case .security: return "SECURITY"
        case .admin: return "ADMIN"
        }
    }
}

/// What a game map draws from the campus: the buildings around the things on it, each on one floor.
struct CampusView {
    var rooms: [POCRoom] = []
    /// The floor each drawn building shows.
    var floors: [String: CampusFloor] = [:]
    /// The building the floor switcher controls: where you are, else where most signs are.
    var focus: CampusBuilding?

    /// Off the shown floor of its building: drawn faded with its floor id.
    func isOffFloor(buildingId: String?, floorId: String?) -> Bool {
        guard let buildingId, let floorId, let shown = floors[buildingId] else { return false }
        return shown.id != floorId
    }
}

extension GameStore {
    func campusView(points: [CGPoint], stations: [Station], playArea: CampusPlace?) -> CampusView {
        let mine = positions.estimate
        var near = campus.buildings(near: points + [mine.map { CGPoint(x: $0.lng, y: $0.lat) }].compactMap { $0 })
        // The play area's building is always drawn.
        if let area = campus.building(playArea?.buildingId), !near.contains(area) { near.append(area) }
        if near.isEmpty, let fallback = campus.building(mine?.buildingId) ?? campus.building("SUB") { near = [fallback] }
        var view = CampusView()
        for building in near {
            let hint = shownFloorHint(building, stations: stations, playArea: playArea)
            let floor = building.floor(hint) ?? building.mainFloor
            view.floors[building.id] = floor
            view.rooms += floor.rooms
        }
        view.focus = near.first { $0.id == mine?.buildingId }
            ?? near.first { $0.id == playArea?.buildingId }
            ?? near.max { a, b in stations.filter { $0.buildingId == a.id }.count < stations.filter { $0.buildingId == b.id }.count }
        return view
    }

    /// The floor shown for a building on the game maps: the play area's floor (picked at setup), else the
    /// one you're on, else the floor most of its signs are on.
    /// The floor you're measured to be on (from the red button at the start or a sign scan in this building,
    /// then the barometer) comes first; then the floor most of the signs are on; the play area last. The
    /// play area (or an estimate that only assumed it) drew another floor's plan under the signs whenever it
    /// was set to a different floor than the saved game's signs.
    func shownFloorHint(_ building: CampusBuilding, stations: [Station], playArea: CampusPlace?) -> String? {
        if let mine = positions.estimate, mine.buildingId == building.id, mine.floorMeasured, let floor = mine.floorId {
            return floor
        }
        let signFloors = stations.filter { $0.buildingId == building.id }.compactMap(\.floorId)
        if let most = Dictionary(grouping: signFloors, by: { $0 }).max(by: { $0.value.count < $1.value.count })?.key {
            return most
        }
        return playArea?.buildingId == building.id ? playArea?.floorId : nil
    }
}

/// Building · floor with up/down, over a map.
struct CampusFloorControl: View {
    let building: CampusBuilding
    let floor: CampusFloor
    let step: (Int) -> Void

    var body: some View {
        let index = building.floorIndex(floor.id) ?? 0
        HStack(spacing: 2) {
            Button { step(-1) } label: { Image(systemName: "chevron.down").frame(width: 30, height: 30) }
                .disabled(index == 0)
                .accessibilityLabel("Floor down")
            VStack(spacing: 0) {
                Text(building.id).font(.system(size: 10, weight: .black, design: .rounded))
                Text(floor.name).font(.system(size: 9, weight: .bold, design: .rounded)).opacity(0.8)
            }
            .frame(minWidth: 56)
            Button { step(1) } label: { Image(systemName: "chevron.up").frame(width: 30, height: 30) }
                .disabled(index >= building.floors.count - 1)
                .accessibilityLabel("Floor up")
        }
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 4)
        .background(.black.opacity(0.72), in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(building.name), \(floor.name)")
    }
}

/// A sign on a game map: Among Us artwork for the security room and the emergency button, a coloured
/// symbol for the rest, with its label under it. Big enough to read at a glance while walking.
struct SignPinView: View {
    let station: POCStation

    static let signSize: CGFloat = 40
    static let specialSize: CGFloat = 56

    var body: some View {
        VStack(spacing: 2) {
            icon
            // The security art already says SECURITY.
            if (station.style != .sign && station.style != .security) || station.faded {
                Text(station.pinLabel)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.black.opacity(0.76), in: Capsule())
            }
        }
        .opacity(station.faded ? 0.45 : 1)
    }

    @ViewBuilder private var icon: some View {
        switch station.style {
        case .security:
            Image("SecurityActionIcon").resizable().scaledToFit()
                .frame(width: Self.specialSize, height: Self.specialSize)
                .shadow(color: .black.opacity(0.6), radius: 2)
        case .emergency:
            Image("EmergencyButtonIcon").resizable().interpolation(.high).scaledToFit()
                .padding(4)
                .frame(width: Self.specialSize * 1.25, height: Self.specialSize * 0.8)
                .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(POCPinStyle.emergency.color, lineWidth: 2.5))
        default:
            let size = station.style == .sign ? Self.signSize : Self.specialSize
            Image(systemName: station.style.icon)
                .font(.system(size: size * 0.45, weight: .black))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(station.style.color, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 2))
        }
    }
}
