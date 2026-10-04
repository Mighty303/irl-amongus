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

/// Where a new sign goes: our SUB floor plan, dragged under a fixed pin, with the venue's other signs
/// on it. Away from the SUB (testing somewhere else) there's no floor plan to use, so it falls back to
/// the Apple map.
struct SignPinPicker: View {
    let start: CLLocationCoordinate2D?
    @Binding var pin: CLLocationCoordinate2D?
    let others: [Station]

    var body: some View {
        if FloorPlanPinMap.covers(start) {
            FloorPlanPinMap(start: start, pin: $pin, others: others)
        } else {
            SignPinMap(start: start, pin: $pin)
        }
    }
}

/// The floor plan with a pin fixed in the middle; drag and pinch the plan until the pin is on the sign.
struct FloorPlanPinMap: View {
    let start: CLLocationCoordinate2D?
    @Binding var pin: CLLocationCoordinate2D?
    let others: [Station]

    @State private var scale: CGFloat = 2.2
    @GestureState private var gestureScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var gestureOffset: CGSize = .zero
    @State private var centered = false

    private static let rooms = SUBLevel2Map.rooms
    private static let plan = POCMapBounds.covering(SUBLevel2Map.rooms)

    /// The floor plan is worth using when the first guess is within ~400 m of it (or there's no guess).
    static func covers(_ c: CLLocationCoordinate2D?) -> Bool {
        guard !rooms.isEmpty else { return false }
        guard let c else { return true }
        let m: CGFloat = 0.004
        return c.longitude >= plan.minX - m && c.longitude <= plan.maxX + m && c.latitude >= plan.minY - m && c.latitude <= plan.maxY + m
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let projection = POCMapProjection(bounds: Self.plan, size: size)
            let s = min(max(scale * gestureScale, 1), 8)
            let o = CGSize(width: offset.width + gestureOffset.width, height: offset.height + gestureOffset.height)
            ZStack {
                Color(red: 0.06, green: 0.09, blue: 0.11)
                Canvas { context, _ in
                    for room in Self.rooms {
                        let path = room.path(using: projection)
                        let corridor = room.roomType.localizedCaseInsensitiveContains("corridor")
                        context.fill(path, with: .color(corridor ? .cyan.opacity(0.10) : .white.opacity(0.14)))
                        context.stroke(path, with: .color(.white.opacity(0.4)), lineWidth: 0.8 / s)
                    }
                    for station in others {
                        guard let lat = station.lat, let lng = station.lng else { continue }
                        let p = projection.point(CGPoint(x: lng, y: lat))
                        let r = 4 / s
                        let dot = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                        context.fill(dot, with: .color(POCPinStyle(station.kind).color))
                        context.stroke(dot, with: .color(.white), lineWidth: 1 / s)
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
                        let next = min(max(scale * value, 1), 8)
                        offset.width *= next / scale
                        offset.height *= next / scale
                        scale = next
                        updatePin(size: size, projection: projection)
                    }
            )
            .onChange(of: gestureOffset) { updatePin(size: size, projection: projection) }
            .onAppear {
                guard !centered else { return }
                centered = true
                if let start {
                    // Put the first guess under the pin.
                    let p = projection.point(CGPoint(x: start.longitude, y: start.latitude))
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
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Floor plan. Drag until the pin is on the sign")
    }

    /// The plan point under the middle of the view: screen = C + s·(p − C) + o, so p = C − o / s.
    private func updatePin(size: CGSize, projection: POCMapProjection) {
        let s = min(max(scale * gestureScale, 1), 8)
        let o = CGSize(width: offset.width + gestureOffset.width, height: offset.height + gestureOffset.height)
        let p = CGPoint(x: size.width / 2 - o.width / s, y: size.height / 2 - o.height / s)
        let c = projection.coordinate(p)
        pin = CLLocationCoordinate2D(latitude: c.y, longitude: c.x)
    }
}
