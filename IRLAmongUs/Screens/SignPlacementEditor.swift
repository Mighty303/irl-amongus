import CoreLocation
import SwiftUI

/// Move a saved game's sign: drag the floor plan until the pin sits exactly on the sign, and pick its floor.
/// Sign check-ins put players exactly at the pin, so the position estimate is only as good as these pins.
struct SignPlacementEditor: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let gamesetId: String
    let station: Station
    /// The game's other signs, drawn on the map for reference.
    let others: [Station]
    let onSaved: () -> Void

    @State private var pin: CLLocationCoordinate2D?
    @State private var place: CampusPlace?
    @State private var saving = false

    private var start: CLLocationCoordinate2D? {
        guard let lat = station.lat, let lng = station.lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    private var startPlace: CampusPlace? {
        guard let b = station.buildingId, let f = station.floorId else { return nil }
        return CampusPlace(buildingId: b, floorId: f)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SignPinPicker(start: start, pin: $pin, place: $place, others: others, startPlace: startPlace)
                        .frame(height: 320)
                        .listRowInsets(EdgeInsets())
                    LabeledContent("Floor", value: placeLabel(place) ?? "Not on a floor plan")
                    LabeledContent("Moved", value: moved)
                } header: {
                    Text(station.signText.map { "Reads “\($0)”" } ?? station.name)
                } footer: {
                    Text("Pinch in close and drag until the pin's tip is exactly on the sign. Use the arrows to change floor. Players scanning this sign are placed here, so the closer the pin, the better everyone's map position.")
                }
            }
            .navigationTitle("Move sign")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { save() }
                        .disabled(saving || pin == nil)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var moved: String {
        guard let pin else { return "Zoom in to place the pin" }
        guard let start else { return "New pin" }
        let m = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
            .distance(from: CLLocation(latitude: start.latitude, longitude: start.longitude))
        let floorChanged = place?.floorId != station.floorId || place?.buildingId != station.buildingId
        let distance = m < 0.05 ? "Not moved" : m < 10 ? String(format: "%.1f m", m) : "\(Int(m.rounded())) m"
        return floorChanged ? "\(distance) · new floor" : distance
    }

    private func placeLabel(_ place: CampusPlace?) -> String? {
        guard let place, let building = store.campus.building(place.buildingId) else { return nil }
        return "\(building.id) · \(building.floor(place.floorId)?.name ?? place.floorId)"
    }

    private func save() {
        guard let pin else { return }
        saving = true
        Task {
            defer { saving = false }
            // Blank building/floor clears them (pin moved off the floor plans).
            let saved = await store.editGamesets("gamesets/\(gamesetId)/stations/\(station.id)/update", [
                "lat": pin.latitude, "lng": pin.longitude,
                "buildingId": place?.buildingId ?? "", "floorId": place?.floorId ?? "",
            ])
            if saved != nil {
                onSaved()
                dismiss()
            }
        }
    }
}
