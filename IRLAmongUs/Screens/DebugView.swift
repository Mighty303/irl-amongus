import SwiftUI

/// Diagnostics for proving out the risky tech on real phones: BLE RSSI calibration,
/// connection / clock sync, GPS accuracy, sign reference loading.
struct DebugView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            List {
                Section("Server") {
                    row("URL", store.serverURLString)
                    row("Connection", "\(store.connection)" + (store.isSynced ? " · synced" : " · not synced"))
                    row("Clock offset", "\(Int(store.clockOffset)) ms")
                    if let s = store.session { row("Game / player", "\(s.code) / \(s.playerId.prefix(8))") }
                    Button("Force reconnect") { store.connect() }
                }

                Section {
                    row("Central", "\(store.ble.centralState.rawValue)")
                    row("Peripheral", "\(store.ble.peripheralState.rawValue)" + (store.ble.isAdvertising ? " · advertising" : ""))
                    row("My token", store.ble.advertisingToken ?? "–")
                    if let msg = store.ble.statusMessage { Text(msg).foregroundStyle(.red) }
                    let readings = store.ble.readings.sorted { $0.value.rssi > $1.value.rssi }
                    if readings.isEmpty { Text("No phones heard yet").foregroundStyle(.secondary) }
                    ForEach(readings, id: \.key) { token, r in
                        let age = Date().timeIntervalSince(r.lastSeen)
                        HStack {
                            Text(token).font(.body.monospaced())
                            Spacer()
                            Text("\(Int(r.rssi)) dBm (raw \(r.rawRSSI))").font(.body.monospaced())
                            Text(String(format: "%.1fs", age)).font(.caption).foregroundStyle(age > 3 ? .red : .secondary)
                        }
                    }
                    if let s = store.state {
                        row("Kill threshold", "≥ \(s.settings.killRssiThreshold) dBm")
                        row("Report threshold", "≥ \(s.settings.reportRssiThreshold) dBm")
                        row("Server says in kill range", "\(s.me.killTargets.count)")
                        row("Server says body nearby", "\(s.me.nearbyBodies.count)")
                    }
                } header: {
                    Text("Bluetooth proximity")
                } footer: {
                    Text("Calibrate: hold two phones at 'kill distance' (arm's length) and note the smoothed RSSI, then set the host's kill threshold just below it. Tokens appear only during a game (state 5 = powered on).")
                }

                Section("Location") {
                    if let loc = store.location.location {
                        row("Fix", String(format: "%.6f, %.6f", loc.coordinate.latitude, loc.coordinate.longitude))
                        row("Accuracy", "±\(Int(loc.horizontalAccuracy)) m")
                    } else {
                        Text(store.location.statusMessage ?? "No fix yet")
                    }
                }

                Section("Sign recognition") {
                    row("Reference signs loaded", "\(store.signs.loadedCount)")
                    row("Threshold", String(format: "%.2f", store.signThreshold))
                }
            }
        }
        .navigationTitle("Diagnostics")
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).foregroundStyle(.secondary).font(.callout.monospaced()) }
    }
}
