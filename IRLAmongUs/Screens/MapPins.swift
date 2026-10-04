import SwiftUI

extension GameState {
    /// Pins for every sign with a location that isn't already a task pin: special signs by kind
    /// (red button, reactor, lights, security, admin) and other signs as small grey pins. The meeting
    /// point is drawn by the floor plan itself.
    func otherSignPins(excluding taskPinIds: Set<String>, campus: CampusView = CampusView()) -> [POCStation] {
        stations.compactMap { s in
            guard !taskPinIds.contains(s.id), s.kind != .meeting, let lat = s.lat, let lng = s.lng else { return nil }
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
    func shownFloorHint(_ building: CampusBuilding, stations: [Station], playArea: CampusPlace?) -> String? {
        if playArea?.buildingId == building.id { return playArea?.floorId }
        if positions.estimate?.buildingId == building.id, let floor = positions.estimate?.floorId { return floor }
        let signFloors = stations.filter { $0.buildingId == building.id }.compactMap(\.floorId)
        return Dictionary(grouping: signFloors, by: { $0 }).max { $0.value.count < $1.value.count }?.key
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
