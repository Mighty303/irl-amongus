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
