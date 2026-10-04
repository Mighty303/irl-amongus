import CoreLocation
import SwiftUI

/// Move a sign's map pin and floor, in the white sign panel: the floor plan on the left (drag until the pin
/// sits exactly on the sign, arrows change floor), details and save on the right. Sign check-ins put players
/// exactly at the pin, so the position estimate is only as good as these pins. Used by My signs, special
/// signs and saved games, which pass their own save.
struct SignPinStep: View {
    @Environment(GameStore.self) private var store
    let compact: Bool
    let station: Station
    /// The other signs, drawn on the map for reference.
    let others: [Station]
    /// Saves the placement (`lat`, `lng`, `buildingId`, `floorId`); true when it worked.
    let save: ([String: Any]) async -> Bool
    let done: () -> Void

    @State private var pin: CLLocationCoordinate2D?
    @State private var place: CampusPlace?
    @State private var saving = false
    @State private var showingPhoto = false

    private var start: CLLocationCoordinate2D? {
        guard let lat = station.lat, let lng = station.lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    private var startPlace: CampusPlace? {
        guard let b = station.buildingId, let f = station.floorId else { return nil }
        return CampusPlace(buildingId: b, floorId: f)
    }

    var body: some View {
        let layout = compact ? AnyLayout(VStackLayout(spacing: 14)) : AnyLayout(HStackLayout(alignment: .top, spacing: 18))
        layout {
            SignPanel.well
                .overlay {
                    if showingPhoto, let photoId = station.photoId, let base = store.serverURL {
                        AsyncImage(url: base.appendingPathComponent("photos/\(photoId).jpg")) { $0.resizable().scaledToFill() }
                            placeholder: { ProgressView() }
                    } else {
                        SignPinPicker(start: start, pin: $pin, place: $place, others: others, startPlace: startPlace)
                    }
                }
                .frame(width: compact ? nil : 300)
                .frame(maxWidth: compact ? .infinity : nil, maxHeight: compact ? 300 : .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .topLeading) {
                    if station.photoId != nil {
                        Button { showingPhoto.toggle() } label: {
                            Label(showingPhoto ? "MAP" : "PHOTO", systemImage: showingPhoto ? "map.fill" : "photo.fill")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(SignPanel.ink, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .accessibilityLabel(showingPhoto ? "Show the map" : "Show the photo")
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(white: 0.8), lineWidth: 2))

            VStack(alignment: .leading, spacing: 10) {
                Text(station.signText.map { "Reads “\($0)”" } ?? station.name)
                    .font(.system(size: 18, weight: .black, design: .rounded)).lineLimit(2)
                Label(placeLabel ?? "Not on a floor plan", systemImage: "building.2.fill")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                Label(moved, systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(SignPanel.muted)
                Text("Pinch in close and drag until the pin's tip is exactly on the sign. Arrows change floor.")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(SignPanel.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    Button(action: done) { SignPanel.outlineLabel("CANCEL", systemImage: "xmark") }
                        .buttonStyle(.plain)
                    SignPanel.filledButton(saving ? "SAVING…" : "SAVE PIN", systemImage: "checkmark") { submit() }
                        .disabled(saving || pin == nil)
                        .opacity(pin == nil ? 0.5 : 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var placeLabel: String? {
        guard let place, let building = store.campus.building(place.buildingId) else { return nil }
        return "\(building.id) · \(building.floor(place.floorId)?.name ?? place.floorId)"
    }

    private var moved: String {
        guard let pin else { return "Zoom in to place the pin" }
        guard let start else { return "New pin" }
        let m = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
            .distance(from: CLLocation(latitude: start.latitude, longitude: start.longitude))
        let floorChanged = place?.floorId != station.floorId || place?.buildingId != station.buildingId
        let distance = m < 0.05 ? "Not moved" : m < 10 ? String(format: "Moved %.1f m", m) : "Moved \(Int(m.rounded())) m"
        return floorChanged ? "\(distance) · new floor" : distance
    }

    private func submit() {
        guard let pin else { return }
        saving = true
        Task {
            defer { saving = false }
            // Blank building/floor clears them (pin moved off the floor plans).
            let ok = await save(["lat": pin.latitude, "lng": pin.longitude,
                                 "buildingId": place?.buildingId ?? "", "floorId": place?.floorId ?? ""])
            if ok { done() }
        }
    }

    /// Round outlined pin button for sign tiles, matching their trash button.
    static func button(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "mappin.and.ellipse").font(.system(size: 13, weight: .bold))
                .frame(width: 32, height: 32)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(SignPanel.ink, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Move \(name)'s map pin")
    }
}

/// The pin step on its own white panel (Settings → Games, tapping a sign).
struct SignPinPanel: View {
    let station: Station
    let others: [Station]
    let save: ([String: Any]) async -> Bool
    let close: () -> Void

    var body: some View {
        SignPanelContainer { compact in
            VStack(alignment: .leading, spacing: 12) {
                SignPanel.header("Move pin", subtitle: station.kind == .task ? "Sign" : station.kind.label)
                SignPinStep(compact: compact, station: station, others: others, save: save, done: close)
            }
            .signPanel(closeLabel: "Close", close: close)
        }
    }
}

extension Station {
    /// Where the sign's pin is, for sign tiles: building and floor, or that it has none.
    @MainActor
    func pinLabel(_ campus: CampusMap) -> String {
        guard lat != nil else { return "No map pin" }
        guard let b = buildingId, let building = campus.building(b) else { return "On the map" }
        return "\(building.id) · \(building.floor(floorId)?.name ?? "no floor")"
    }
}
