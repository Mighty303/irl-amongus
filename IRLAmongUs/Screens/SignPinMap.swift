import MapKit
import SwiftUI

/// Where a new sign goes on the map. GPS is rough (much worse indoors) and library photos only know
/// where they were taken, so the player drags the map until the fixed pin in the middle sits on the
/// sign. `pin` follows the map's center, and is nil while zoomed out too far for it to mean anything.
struct SignPinMap: View {
    @Binding var pin: CLLocationCoordinate2D?
    @State private var position: MapCameraPosition

    /// `start` is the first guess (GPS or the photo's location). Without one the map follows the player.
    init(start: CLLocationCoordinate2D?, pin: Binding<CLLocationCoordinate2D?>) {
        _pin = pin
        _position = State(initialValue: start.map { .camera(MapCamera(centerCoordinate: $0, distance: Self.startDistance)) }
            ?? .userLocation(fallback: .automatic))
    }

    /// Camera height when the map opens: a building or two across.
    private static let startDistance: CLLocationDistance = 250
    /// Farther out than this, the center is too vague to be a pin.
    private static let maxPinDistance: CLLocationDistance = 3000

    var body: some View {
        Map(position: $position) {
            UserAnnotation()
        }
        .mapStyle(.hybrid(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControls { MapUserLocationButton(); MapCompass() }
        .onMapCameraChange(frequency: .continuous) { context in
            pin = context.camera.distance <= Self.maxPinDistance ? context.region.center : nil
        }
        .overlay {
            // The pin's tip marks the map's center; it doesn't take touches, so the map drags under it.
            ZStack {
                Ellipse().fill(.black.opacity(0.35)).frame(width: 12, height: 5)
                VStack(spacing: 0) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white, SignPanel.error)
                    Rectangle().fill(SignPanel.ink).frame(width: 3, height: 12)
                }
                .alignmentGuide(VerticalAlignment.center) { $0[.bottom] }
                .opacity(pin == nil ? 0.4 : 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
        }
    }
}

/// Where a new sign goes: the SFU campus floor plans, dragged under a fixed pin, with the venue's other
/// signs on it and a floor switcher for the building under the pin (saved with the sign). Off campus
/// there's no floor plan to use, so it falls back to the Apple map.
struct SignPinPicker: View {
    @Environment(GameStore.self) private var store
    let start: CLLocationCoordinate2D?
    @Binding var pin: CLLocationCoordinate2D?
    /// The building and floor under the pin (nil outdoors or on the Apple map).
    @Binding var place: CampusPlace?
    let others: [Station]

    var body: some View {
        if let buildings = FloorPlanPinMap.buildings(around: start, in: store.campus) {
            FloorPlanPinMap(start: start, pin: $pin, place: $place, others: others, buildings: buildings)
        } else {
            SignPinMap(start: start, pin: $pin).onAppear { place = nil }
        }
    }
}

/// Campus floor plans with a pin fixed in the middle; drag and pinch until the pin is on the sign.
struct FloorPlanPinMap: View {
    @Environment(GameStore.self) private var store
    let start: CLLocationCoordinate2D?
    @Binding var pin: CLLocationCoordinate2D?
    @Binding var place: CampusPlace?
    let others: [Station]
    /// The buildings drawn (those around the first guess).
    let buildings: [CampusBuilding]

    @State private var scale: CGFloat = 2.2
    @GestureState private var gestureScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var gestureOffset: CGSize = .zero
    @State private var centered = false
    /// Floor picked per building while placing this sign.
    @State private var floorChoice: [String: String] = [:]
    @State private var pinBuilding: CampusBuilding?

    /// The buildings within ~400 m of the first guess (or around the SUB without one); nil off campus.
    @MainActor
    static func buildings(around start: CLLocationCoordinate2D?, in campus: CampusMap) -> [CampusBuilding]? {
        let center: CLLocationCoordinate2D? = start ?? campus.building("SUB").map { (b: CampusBuilding) -> CLLocationCoordinate2D in
            CLLocationCoordinate2D(latitude: Double(b.bounds.minY + b.bounds.maxY) / 2,
                                   longitude: Double(b.bounds.minX + b.bounds.maxX) / 2)
        }
        guard let center else { return nil }
        let near = campus.buildings(near: [CGPoint(x: center.longitude, y: center.latitude)], marginM: 400)
        return near.isEmpty ? nil : near
    }

    private var plan: POCMapBounds {
        buildings.dropFirst().reduce(buildings[0].bounds) {
            $0.including(CGPoint(x: $1.bounds.minX, y: $1.bounds.minY)).including(CGPoint(x: $1.bounds.maxX, y: $1.bounds.maxY))
        }
    }

    private func floor(_ b: CampusBuilding) -> CampusFloor {
        if let chosen = b.floor(floorChoice[b.id]) { return chosen }
        // Start on the floor you're on when you're in this building, else the game's play area floor.
        if store.positions.estimate?.buildingId == b.id, let mine = b.floor(store.positions.estimate?.floorId) { return mine }
        if let area = store.state?.playArea, area.buildingId == b.id, let floor = b.floor(area.floorId) { return floor }
        return store.campus.displayedFloor(b)
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let projection = POCMapProjection(bounds: plan, size: size)
            let s = min(max(scale * gestureScale, 1), 12)
            let o = CGSize(width: offset.width + gestureOffset.width, height: offset.height + gestureOffset.height)
            let shown = Dictionary(uniqueKeysWithValues: buildings.map { ($0.id, floor($0)) })
            ZStack {
                Color(red: 0.06, green: 0.09, blue: 0.11)
                Canvas { context, _ in
                    for building in buildings {
                        for room in shown[building.id]?.rooms ?? [] {
                            let path = room.path(using: projection)
                            let corridor = room.roomType.localizedCaseInsensitiveContains("corridor")
                            let highlight = building.id == pinBuilding?.id
                            context.fill(path, with: .color(corridor ? .cyan.opacity(0.10) : .white.opacity(highlight ? 0.2 : 0.12)))
                            context.stroke(path, with: .color(.white.opacity(0.4)), lineWidth: 0.8 / s)
                        }
                    }
                    for station in others {
                        guard let lat = station.lat, let lng = station.lng else { continue }
                        let offFloor = station.buildingId.flatMap { shown[$0] }.map { $0.id != station.floorId } ?? false
                        let p = projection.point(CGPoint(x: lng, y: lat))
                        let r = 4 / s
                        let dot = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                        context.fill(dot, with: .color(POCPinStyle(station.kind).color.opacity(offFloor ? 0.35 : 1)))
                        context.stroke(dot, with: .color(.white.opacity(offFloor ? 0.4 : 1)), lineWidth: 1 / s)
                    }
                }
                .frame(width: size.width, height: size.height)
                .scaleEffect(s)
                .offset(o)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .updating($gestureOffset) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        offset.width += value.translation.width
                        offset.height += value.translation.height
                        updatePin(size: size, projection: projection)
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .updating($gestureScale) { value, state, _ in state = value }
                    .onEnded { value in
                        // Zoom about the middle: the point under the pin stays under the pin.
                        let next = min(max(scale * value, 1), 12)
                        offset.width *= next / scale
                        offset.height *= next / scale
                        scale = next
                        updatePin(size: size, projection: projection)
                    }
            )
            .onChange(of: gestureOffset) { updatePin(size: size, projection: projection) }
            .onChange(of: floorChoice) { updatePin(size: size, projection: projection) }
            .onAppear {
                guard !centered else { return }
                centered = true
                if let start {
                    // Put the first guess under the pin, zoomed to about a building across.
                    let p = projection.point(CGPoint(x: start.longitude, y: start.latitude))
                    scale = min(max(size.width / max(projection.points(meters: 120), 1), 1), 12)
                    offset = CGSize(width: (size.width / 2 - p.x) * scale, height: (size.height / 2 - p.y) * scale)
                }
                updatePin(size: size, projection: projection)
            }
            .overlay {
                // Same pin as the Apple map version: its tip marks the middle, and it doesn't take touches.
                ZStack {
                    Ellipse().fill(.black.opacity(0.35)).frame(width: 12, height: 5)
                    VStack(spacing: 0) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white, SignPanel.error)
                        Rectangle().fill(.white).frame(width: 3, height: 12)
                    }
                    .alignmentGuide(VerticalAlignment.center) { $0[.bottom] }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                if let building = pinBuilding, building.floors.count > 1 {
                    CampusFloorControl(building: building, floor: floor(building)) { step in
                        let current = building.floorIndex(floor(building).id) ?? 0
                        let next = min(max(current + step, 0), building.floors.count - 1)
                        floorChoice[building.id] = building.floors[next].id
                    }
                    .padding(8)
                } else if let building = pinBuilding {
                    Text("\(building.id) · \(floor(building).name)")
                        .font(.system(size: 10, weight: .black, design: .rounded)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.black.opacity(0.72), in: Capsule())
                        .padding(8)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Campus floor plan. Drag until the pin is on the sign")
    }

    /// The plan point under the middle of the view: screen = C + s·(p − C) + o, so p = C − o / s.
    private func updatePin(size: CGSize, projection: POCMapProjection) {
        let s = min(max(scale * gestureScale, 1), 12)
        let o = CGSize(width: offset.width + gestureOffset.width, height: offset.height + gestureOffset.height)
        let p = CGPoint(x: size.width / 2 - o.width / s, y: size.height / 2 - o.height / s)
        let c = projection.coordinate(p)
        let coordinate = CLLocationCoordinate2D(latitude: c.y, longitude: c.x)
        pin = coordinate
        let building = store.campus.building(at: coordinate, marginM: 2)
        if building?.id != pinBuilding?.id { pinBuilding = building }
        place = building.map { CampusPlace(buildingId: $0.id, floorId: floor($0).id) }
    }
}
