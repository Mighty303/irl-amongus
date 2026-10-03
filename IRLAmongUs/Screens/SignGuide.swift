import SwiftUI

/// Guides a player to a sign: its reference photo plus, when the sign is GPS-tagged, an approximate
/// distance and a compass arrow. GPS is rough indoors, so the photo is what confirms you found it.
struct SignGuide: View {
    @Environment(GameStore.self) private var store
    let station: Station

    var body: some View {
        VStack(spacing: 12) {
            if let photoId = station.photoId, let base = store.serverURL {
                AsyncImage(url: base.appendingPathComponent("photos/\(photoId).jpg")) { $0.resizable().scaledToFit() }
                    placeholder: { ProgressView() }
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text("Find this sign").font(.caption)
            }
            if let distance = store.location.distance(to: station) {
                HStack(spacing: 16) {
                    if let arrow = arrowAngle {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 44))
                            .rotationEffect(.degrees(arrow))
                            .animation(.easeOut(duration: 0.3), value: arrow)
                    }
                    VStack(alignment: .leading) {
                        Text(Self.format(distance)).font(.title.bold().monospacedDigit())
                        if let accuracy = store.location.location?.horizontalAccuracy {
                            Text("GPS ±\(Int(accuracy)) m").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } else if station.lat == nil {
                Text("This sign has no GPS tag. Use the photo.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear { store.location.start() }
    }

    /// Arrow rotation relative to where the phone points.
    private var arrowAngle: Double? {
        guard let bearing = store.location.bearing(to: station), let heading = store.location.heading else { return nil }
        return bearing - heading
    }

    static func format(_ meters: Double) -> String {
        meters < 1000 ? "\(Int(meters.rounded())) m" : String(format: "%.1f km", meters / 1000)
    }
}
