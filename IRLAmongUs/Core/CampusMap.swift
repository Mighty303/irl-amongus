import CoreGraphics
import CoreLocation
import Foundation
import Observation

/// A floor of an SFU building: its rooms as floor-plan polygons.
struct CampusFloor: Identifiable, Equatable {
    let id: String
    let name: String
    /// Bottom to top within the building.
    let order: Double
    let rooms: [POCRoom]

    static func == (a: CampusFloor, b: CampusFloor) -> Bool { a.id == b.id && a.rooms.count == b.rooms.count }
}

struct CampusBuilding: Identifiable, Equatable {
    let id: String
    let name: String
    let bounds: POCMapBounds
    /// Bottom to top.
    let floors: [CampusFloor]

    static func == (a: CampusBuilding, b: CampusBuilding) -> Bool { a.id == b.id && a.floors == b.floors }

    func floor(_ id: String?) -> CampusFloor? { floors.first { $0.id == id } }
    func floorIndex(_ id: String?) -> Int? { floors.firstIndex { $0.id == id } }

    /// The floor shown when nothing says otherwise: the one with the most rooms (usually the main floor).
    var mainFloor: CampusFloor { floors.max { $0.rooms.count < $1.rooms.count } ?? floors[0] }

    func contains(_ c: CLLocationCoordinate2D, marginM: Double = 0) -> Bool {
        let dLat = marginM / 111_320, dLng = marginM / (111_320 * cos(c.latitude * .pi / 180))
        return c.longitude >= bounds.minX - dLng && c.longitude <= bounds.maxX + dLng
            && c.latitude >= bounds.minY - dLat && c.latitude <= bounds.maxY + dLat
    }
}

/// Where something is on campus: a building and one of its floors.
struct CampusPlace: Equatable {
    let buildingId: String
    let floorId: String
}

/// The SFU Burnaby campus floor plans (every building and floor), from the game server's `/campus`
/// (SFU's RoomFinder data). Kept on disk so it's there offline; until the first download it falls back
/// to the bundled SUB level 2 plan.
@MainActor
@Observable
final class CampusMap {
    private(set) var buildings: [CampusBuilding]
    private(set) var isFullCampus = false
    private(set) var loading = false

    @ObservationIgnored private var indexes: [String: FloorPlanIndex] = [:]
    @ObservationIgnored private let defaults: UserDefaults

    private static var cacheFile: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("campus.json")
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        buildings = Self.bundledSUB()
        if let data = try? Data(contentsOf: Self.cacheFile), let decoded = Self.decode(data) {
            buildings = decoded
            isFullCampus = true
        }
    }

    /// Downloads the campus if the server has a newer copy (ETag), and keeps it on disk.
    func load(serverURL: URL) async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        var request = URLRequest(url: serverURL.appendingPathComponent("campus"))
        request.timeoutInterval = 60
        if isFullCampus, let etag = defaults.string(forKey: "campusETag") {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
        let decoded = await Task.detached(priority: .utility) { Self.decode(data) }.value
        guard let decoded, !decoded.isEmpty else { return }
        try? data.write(to: Self.cacheFile, options: .atomic)
        defaults.set(http.value(forHTTPHeaderField: "Etag"), forKey: "campusETag")
        indexes = [:]
        buildings = decoded
        isFullCampus = true
    }

    // MARK: - Lookups

    func building(_ id: String?) -> CampusBuilding? { buildings.first { $0.id == id } }

    /// The building a point is in: inside one of its rooms on any floor, or failing that the smallest
    /// building whose outline (plus `marginM`) contains it.
    func building(at c: CLLocationCoordinate2D, marginM: Double = 8) -> CampusBuilding? {
        let candidates = buildings.filter { $0.contains(c, marginM: marginM) }
        if let inside = candidates.first(where: { b in b.floors.contains { index(b, $0).room(containing: c) != nil } }) {
            return inside
        }
        return candidates.min { area($0) < area($1) }
    }

    /// Room lookup for one floor (cached).
    func index(_ building: CampusBuilding, _ floor: CampusFloor) -> FloorPlanIndex {
        let key = "\(building.id)/\(floor.id)"
        if let cached = indexes[key] { return cached }
        let index = FloorPlanIndex(rooms: floor.rooms)
        indexes[key] = index
        return index
    }

    /// Buildings within `marginM` of any of the points.
    func buildings(near points: [CGPoint], marginM: Double = 60) -> [CampusBuilding] {
        guard !points.isEmpty else { return [] }
        return buildings.filter { b in
            points.contains { b.contains(CLLocationCoordinate2D(latitude: $0.y, longitude: $0.x), marginM: marginM) }
        }
    }

    /// The floor a map shows for a building: `hint` (e.g. the play area's floor), else the main floor.
    func displayedFloor(_ building: CampusBuilding, hint: String? = nil) -> CampusFloor {
        building.floor(hint) ?? building.mainFloor
    }

    private func area(_ b: CampusBuilding) -> CGFloat { (b.bounds.maxX - b.bounds.minX) * (b.bounds.maxY - b.bounds.minY) }

    // MARK: - Decoding

    private struct Bundle: Decodable {
        struct Building: Decodable {
            let id: String
            let name: String
            let bbox: [Double]
            let floors: [Floor]
        }
        struct Floor: Decodable {
            let id: String
            let name: String
            let order: Double
            let rooms: [Room]
        }
        struct Room: Decodable {
            let id: String
            let name: String
            let type: String
            let rings: [[[Double]]]
        }
        let buildings: [Building]
    }

    nonisolated private static func decode(_ data: Data) -> [CampusBuilding]? {
        guard let bundle = try? JSONDecoder().decode(Bundle.self, from: data) else { return nil }
        return bundle.buildings.compactMap { b in
            guard b.bbox.count == 4, !b.floors.isEmpty else { return nil }
            let floors = b.floors.map { f in
                CampusFloor(id: f.id, name: f.name, order: f.order, rooms: f.rooms.compactMap { r in
                    let rings = r.rings.map { $0.compactMap { $0.count >= 2 ? CGPoint(x: $0[0], y: $0[1]) : nil } }
                    guard let outer = rings.first, outer.count >= 3 else { return nil }
                    let corridor = r.type.localizedCaseInsensitiveContains("corridor")
                    let named = !r.name.hasPrefix("\(b.id) ")
                    return POCRoom(id: "\(b.id)-\(f.id)-\(r.id)", label: r.name, roomID: r.id, roomType: r.type,
                                   priority: corridor ? 5 : named ? 30 : 50, rings: rings,
                                   center: SUBLevel2Map.polygonCenter(outer))
                })
            }
            return CampusBuilding(id: b.id, name: b.name,
                                  bounds: POCMapBounds(minX: b.bbox[0], maxX: b.bbox[2], minY: b.bbox[1], maxY: b.bbox[3]),
                                  floors: floors)
        }
    }

    /// Offline fallback: the bundled SUB level 2 plan.
    private static func bundledSUB() -> [CampusBuilding] {
        let rooms = SUBLevel2Map.rooms
        guard !rooms.isEmpty else { return [] }
        return [CampusBuilding(id: "SUB", name: "Student Union Building", bounds: POCMapBounds.covering(rooms),
                               floors: [CampusFloor(id: "2000", name: "2000 Level", order: 2000, rooms: rooms)])]
    }
}
