import CoreBluetooth
import SwiftUI

/// BLE proximity test bench. Run it on two iPhones: each advertises a token and lists
/// what it hears with live RSSI, so you can calibrate the "kill distance" threshold.
struct BluetoothLabView: View {
    @State private var ble = BLEProximity()
    @State private var running = false
    @State private var token = String(format: "%06x", Int.random(in: 0..<0xFFFFFF))
    @State private var threshold: Double = -65
    @State private var inRange = false
    @State private var peak: [String: Int] = [:]

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                List {
                    Section {
                        Button(running ? "Stop" : "Start advertising + scanning") { toggle() }
                            .font(.headline)
                        row("My token", running ? token : "–")
                        row("Scanner", stateName(ble.centralState))
                        row("Advertiser", stateName(ble.peripheralState) + (ble.isAdvertising ? " · advertising" : ""))
                        if let msg = ble.statusMessage { Text(msg).foregroundStyle(.red) }
                    }

                    Section {
                        Text(inRange ? "🔪 IN KILL RANGE" : "out of range")
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(inRange ? .red : .secondary)
                            .frame(maxWidth: .infinity)
                        VStack(alignment: .leading) {
                            Text("Kill threshold: ≥ \(Int(threshold)) dBm").font(.caption)
                            Slider(value: $threshold, in: -100...(-30), step: 1)
                        }
                    } footer: {
                        Text("Closer = higher (less negative) RSSI. Hold the phones at the distance a kill should happen and set the threshold just below the smoothed value. Bodies, pockets and phone orientation all change it, so test realistically.")
                    }

                    Section("Phones heard") {
                        let readings = ble.readings.sorted { $0.value.rssi > $1.value.rssi }
                        if readings.isEmpty {
                            Text(running ? "Nothing yet. Open this test on another iPhone." : "Press Start.").foregroundStyle(.secondary)
                        }
                        ForEach(readings, id: \.key) { token, r in
                            let age = Date().timeIntervalSince(r.lastSeen)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(token).font(.headline.monospaced())
                                    Spacer()
                                    Text("\(Int(r.rssi)) dBm").font(.title2.monospaced().bold())
                                        .foregroundStyle(age < 3 && r.rssi >= threshold ? .red : .primary)
                                }
                                HStack {
                                    Text("raw \(r.rawRSSI)")
                                    Text("peak \(peak[token] ?? r.rawRSSI)")
                                    Text("\(r.samples) samples")
                                    Spacer()
                                    Text(String(format: "%.1fs ago", age)).foregroundStyle(age > 3 ? .red : .secondary)
                                }
                                .font(.caption.monospaced())
                                ProgressView(value: min(1, max(0, (r.rssi + 100) / 70)))
                                    .tint(r.rssi >= threshold ? .red : .blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bluetooth")
            .task(id: running) {
                // Mirrors the server's rule: a fresh sighting at or above the threshold.
                while running && !Task.isCancelled {
                    let now = ble.freshSightings(within: 3)
                    for s in now { peak[s.token] = max(peak[s.token] ?? -127, s.rssi) }
                    let near = now.contains { Double($0.rssi) >= threshold }
                    if near && !inRange { Haptics.killInRange() }
                    inRange = near
                    try? await Task.sleep(for: .milliseconds(500))
                }
            }
            .onDisappear { if running { toggle() } }
        }
    }

    private func toggle() {
        if running {
            ble.stop()
            inRange = false
            peak = [:]
        } else {
            ble.start(token: token)
        }
        running.toggle()
    }

    private func stateName(_ state: CBManagerState) -> String {
        switch state {
        case .poweredOn: return "on"
        case .poweredOff: return "OFF"
        case .unauthorized: return "not allowed"
        case .unsupported: return "unsupported"
        case .resetting: return "resetting"
        default: return "starting…"
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).foregroundStyle(.secondary).font(.callout.monospaced()) }
    }
}
