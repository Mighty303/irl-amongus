import CoreLocation
import MapKit
import SwiftUI

/// GPS test bench (opened from "GPS, QR, haptics & mini-games"): live fix quality, plus pins you drop to measure distance / geofence behavior
/// (the same check the server does for GPS check-ins).
struct LocationLabView: View {
    @Environment(GameStore.self) private var store
    @State private var pins: [Pin] = []
    @State private var radius: Double = 15

    struct Pin: Identifiable {
        let id = UUID()
        let name: String
        let location: CLLocation
    }

    var body: some View {
        let loc = store.location.location
        VStack(spacing: 0) {
            Map(initialPosition: .userLocation(fallback: .automatic)) {
                UserAnnotation()
                ForEach(pins) { pin in
                    MapCircle(center: pin.location.coordinate, radius: radius)
                        .foregroundStyle(.blue.opacity(0.15))
                        .stroke(.blue, lineWidth: 1)
                    Marker(pin.name, coordinate: pin.location.coordinate)
                }
            }
            .mapControls { MapUserLocationButton(); MapCompass(); MapScaleView() }
            .frame(height: 300)

            List {
                Section("Live fix") {
                    if let loc {
                        row("Lat, Lng", String(format: "%.6f, %.6f", loc.coordinate.latitude, loc.coordinate.longitude))
                        row("Horizontal accuracy", "±\(Int(loc.horizontalAccuracy)) m")
                            .foregroundStyle(loc.horizontalAccuracy > radius ? .orange : .primary)
                        row("Altitude", "\(Int(loc.altitude)) m ±\(Int(loc.verticalAccuracy))")
                        row("Floor (indoor)", loc.floor.map { "\($0.level)" } ?? "not reported")
                        row("Updated", loc.timestamp.formatted(date: .omitted, time: .standard))
                    } else {
                        Text(store.location.statusMessage ?? "Waiting for a fix…")
                    }
                }
                Section {
                    Button("📍 Drop pin here") {
                        if let loc { pins.append(Pin(name: "Pin \(pins.count + 1)", location: loc)) }
                    }
                    .disabled(loc == nil)
                    Stepper("Geofence radius: \(Int(radius)) m", value: $radius, in: 5...100, step: 5)
                    ForEach(pins) { pin in
                        let d = loc.map { $0.distance(from: pin.location) }
                        HStack {
                            Text(pin.name)
                            Spacer()
                            if let d {
                                Text("\(Int(d)) m").font(.body.monospaced())
                                Text(d <= radius ? "INSIDE" : "outside").bold()
                                    .foregroundStyle(d <= radius ? .green : .secondary)
                            }
                        }
                    }
                    .onDelete { pins.remove(atOffsets: $0) }
                } header: {
                    Text("Geofence test")
                } footer: {
                    Text("Drop a pin, walk away and back. Indoors, expect accuracy of 10–50 m and jumps, which is why sign recognition is the main check-in method.")
                }
            }
        }
        .navigationTitle("GPS")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.location.start() }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).font(.callout.monospaced()) }
    }
}
