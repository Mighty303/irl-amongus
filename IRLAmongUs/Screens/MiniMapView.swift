import MapKit
import SwiftUI

/// Mini-map: GPS-tagged stations, your assigned task pins, the meeting point, and your own location.
/// It never shows other players. Only this phone's own position and last check-in appear.
///
/// TODO(PRD §6): swap MapKit for a bundled SFU floor plan (GeoJSON room polygons) once reuse permission is confirmed.
struct MiniMapView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let state: GameState
    @State private var selected: Station?

    private var myTaskStations: [String: GameTask] {
        var map: [String: GameTask] = [:]
        for t in state.me.tasks { if let id = t.currentStationId { map[id] = t } }
        return map
    }

    var body: some View {
        NavigationStack {
            Group {
                if state.stations.contains(where: { $0.lat != nil }) {
                    Map(initialPosition: .automatic) {
                        UserAnnotation()
                        ForEach(state.stations.filter { $0.lat != nil && $0.lng != nil }) { s in
                            Annotation(s.name, coordinate: CLLocationCoordinate2D(latitude: s.lat!, longitude: s.lng!)) {
                                Image(systemName: icon(s))
                                    .padding(6)
                                    .background(color(s), in: Circle())
                                    .foregroundStyle(.white)
                                    .onTapGesture { selected = s }
                            }
                        }
                    }
                    .mapControls { MapUserLocationButton(); MapCompass() }
                } else {
                    ContentUnavailableView("No GPS-tagged stations", systemImage: "map",
                                           description: Text("Tag stations with GPS during setup to see them here."))
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let cp = state.me.lastCheckpoint, let s = state.station(cp.stationId) {
                    Text("You last checked in at \(s.name), \(Date(timeIntervalSince1970: cp.at / 1000).formatted(date: .omitted, time: .shortened))")
                        .font(.caption).padding(8).frame(maxWidth: .infinity).background(.thinMaterial)
                }
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Close") { dismiss() } }
            .sheet(item: $selected) { s in
                VStack(spacing: 12) {
                    StationRow(station: s)
                    if let task = myTaskStations[s.id] { Text("Your task here: \(task.type.label)").bold() }
                    if let d = store.location.distance(to: s) { Text("\(Int(d)) m away").font(.caption) }
                }
                .padding()
                .presentationDetents([.fraction(0.25)])
            }
        }
    }

    private func color(_ s: Station) -> Color {
        if s.kind == .meeting { return .blue }
        if s.kind == .emergency { return .red }
        if myTaskStations[s.id] != nil { return .yellow }
        if state.me.tasks.contains(where: { $0.completed && $0.steps.contains(s.id) }) { return .green }
        return .gray
    }

    private func icon(_ s: Station) -> String {
        switch s.kind {
        case .meeting: return "person.3.fill"
        case .emergency: return "light.beacon.max.fill"
        case .reactor: return "atom"
        case .electrical: return "bolt.fill"
        case .task: return myTaskStations[s.id] != nil ? "exclamationmark" : "mappin"
        }
    }
}
