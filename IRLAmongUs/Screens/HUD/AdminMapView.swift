import CoreLocation
import SwiftUI

/// Admin, like Among Us: the floor plan with a crewmate icon for every person in each room (the living and
/// bodies nobody has found), and no names. For the living right after scanning the Admin sign. The server
/// sends where everyone is, nameless; this phone counts them per room on its own floor plans.
struct AdminMapView: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let close: () -> Void

    /// Floor picked with the arrows; starts on the floor the map is showing.
    @State private var floorChoice: String?

    var body: some View {
        let campus = store.campusView(points: state.locatedStationPoints, stations: state.stations, playArea: state.playArea)
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 10) {
                if let building = campus.focus {
                    let floor = building.floor(floorChoice) ?? campus.floors[building.id] ?? building.mainFloor
                    let counts = AdminCounts(people: store.adminPeople, building: building, floor: floor, campus: store.campus)
                    header(building: building, counts: counts)
                    AdminFloorPlan(rooms: floor.rooms, counts: counts.perRoom)
                        .overlay(alignment: .bottomTrailing) {
                            if building.floors.count > 1 {
                                CampusFloorControl(building: building, floor: floor) { step in
                                    let index = min(max((building.floorIndex(floor.id) ?? 0) + step, 0), building.floors.count - 1)
                                    floorChoice = building.floors[index].id
                                }
                                .padding(8)
                            }
                        }
                } else {
                    header(building: nil, counts: nil)
                    Spacer()
                    Text("No floor plan for this game's signs.").foregroundStyle(.white.opacity(0.7))
                    Spacer()
                }
            }
            .padding(14)
            .background(HUDStyle.panel())
            .overlay(alignment: .topLeading) { HUDCloseButton(action: close) }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .task { if !(await store.watchAdmin(true)) { close() } }
        .onAppear { GameSoundEffect.panelAppear.play() }
        .onDisappear {
            GameSoundEffect.panelDisappear.play()
            Task { await store.watchAdmin(false) }
        }
        .onChange(of: state.me.canViewAdmin) { _, can in if can != true { close() } }
        .accessibilityIdentifier("admin.map")
    }

    private func header(building: CampusBuilding?, counts: AdminCounts?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "map.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(POCPinStyle.admin.color)
            Text("ADMIN").font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(.white)
            if let counts {
                Text(counts.summary).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 34)
    }
}

/// Who's in which room on one floor, and how many are elsewhere.
struct AdminCounts {
    let perRoom: [String: Int]
    let onFloorOutsideRooms: Int
    let otherFloors: [(name: String, count: Int)]

    @MainActor
    init(people: [AdminPerson], building: CampusBuilding, floor: CampusFloor, campus: CampusMap) {
        let index = campus.index(building, floor)
        var perRoom: [String: Int] = [:], outside = 0, others: [String: Int] = [:]
        for person in people {
            let coordinate = CLLocationCoordinate2D(latitude: person.lat, longitude: person.lng)
            guard person.buildingId == building.id || (person.buildingId == nil && building.contains(coordinate)) else { continue }
            if let floorId = person.floorId, floorId != floor.id {
                others[floorId, default: 0] += 1
                continue
            }
            if let room = index.room(containing: coordinate) { perRoom[room.id, default: 0] += 1 } else { outside += 1 }
        }
        self.perRoom = perRoom
        onFloorOutsideRooms = outside
        otherFloors = others.compactMap { id, count in building.floor(id).map { ($0.name, count) } }.sorted { $0.name < $1.name }
    }

    var summary: String {
        var parts: [String] = []
        if onFloorOutsideRooms > 0 { parts.append("\(onFloorOutsideRooms) between rooms") }
        parts += otherFloors.map { "\($0.count) on \($0.name)" }
        return parts.joined(separator: " · ")
    }
}

/// The floor plan, with one crewmate icon per person at the middle of each room.
struct AdminFloorPlan: View {
    let rooms: [POCRoom]
    let counts: [String: Int]

    var body: some View {
        GeometryReader { geo in
            let projection = POCMapProjection(bounds: POCMapBounds.covering(rooms), size: geo.size)
            ZStack {
                Canvas { context, _ in
                    for room in rooms {
                        let path = room.path(using: projection)
                        let busy = (counts[room.id] ?? 0) > 0
                        context.fill(path, with: .color(room.mapFill))
                        if busy { context.fill(path, with: .color(POCPinStyle.admin.color.opacity(0.28))) }
                        context.stroke(path, with: .color(.white.opacity(0.4)), lineWidth: 0.8)
                    }
                }
                ForEach(rooms.filter { (counts[$0.id] ?? 0) > 0 }) { room in
                    AdminRoomIcons(count: counts[room.id] ?? 0)
                        .position(projection.point(room.center))
                        .accessibilityLabel("\(room.label): \(counts[room.id] ?? 0)")
                }
            }
        }
        .background(Color(red: 0.06, green: 0.09, blue: 0.11), in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// A little crowd of plain crewmates, like the icons on Among Us's admin map.
private struct AdminRoomIcons: View {
    let count: Int

    var body: some View {
        let shown = min(count, 8)
        let columns = min(shown, 4)
        VStack(spacing: -2) {
            ForEach(0..<Int(ceil(Double(shown) / Double(columns))), id: \.self) { row in
                HStack(spacing: -3) {
                    ForEach(0..<min(columns, shown - row * columns), id: \.self) { _ in
                        Image("LobbyPlayerWhite").resizable().scaledToFit().frame(width: 18, height: 18)
                    }
                }
            }
            if count > shown {
                Text("+\(count - shown)").font(.system(size: 9, weight: .black, design: .rounded)).foregroundStyle(.white)
            }
        }
        .shadow(color: .black.opacity(0.8), radius: 2)
    }
}
