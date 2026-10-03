import CoreBluetooth
import SwiftUI

/// BLE proximity test bench. Run it on two iPhones: each advertises a token and lists
/// what it hears with live RSSI and an estimated distance, so you can calibrate the game's
/// "RSSI at 1 m" and see what a kill distance in meters means in practice.
struct BluetoothLabView: View {
    @Environment(GameStore.self) private var store
    @State private var ble = BLEProximity()
    @State private var running = false
    @State private var token = String(format: "%06x", Int.random(in: 0..<0xFFFFFF))
    @State private var killMeters: Double = 1.5
    @AppStorage("labRssiAt1m") private var rssiAt1m: Double = -59
    @AppStorage("labPathLossExponent") private var exponent: Double = 2.2
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
                            Text(String(format: "Kill distance: ~%.1f m (≥ %d dBm)", killMeters, Int(threshold.rounded()))).font(.caption)
                            Slider(value: $killMeters, in: 0.5...10, step: 0.5)
                        }
                    } header: {
                        Text("Kill range")
                    } footer: {
                        Text("Same conversion the server uses. Bodies, pockets and phone orientation all weaken the signal, so test the way people will actually hold their phones.")
                    }

                    Section {
                        Button("Set 1 m from the closest phone (\(closestRSSI.map { "\($0) dBm" } ?? "none heard"))") {
                            if let rssi = closestRSSI { rssiAt1m = Double(rssi) }
                        }
                        .disabled(closestRSSI == nil)
                        Stepper("RSSI at 1 m: \(Int(rssiAt1m)) dBm", value: $rssiAt1m, in: -100...(-30), step: 1)
                        Stepper(String(format: "Indoor factor: %.1f", exponent), value: $exponent, in: 1.5...4, step: 0.1)
                        if let state = store.state, state.phase == .LOBBY, state.isHost {
                            Button("Apply to my lobby (\(state.code))") {
                                store.updateSetting("rssiAt1m", rssiAt1m.rounded())
                                store.updateSetting("pathLossExponent", (exponent * 10).rounded() / 10)
                                store.updateSetting("killDistanceM", killMeters)
                            }
                        }
                    } header: {
                        Text("Calibration")
                    } footer: {
                        Text("Hold the two phones 1 m apart until the reading settles, then tap \"Set 1 m\". Raise the indoor factor if the estimates read too close when phones are far apart.")
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
                                    VStack(alignment: .trailing) {
                                        Text(String(format: "~%.1f m", BLEDistance.meters(forRSSI: r.rssi, rssiAt1m: rssiAt1m, exponent: exponent)))
                                            .font(.title2.monospaced().bold())
                                        Text("\(Int(r.rssi)) dBm").font(.caption.monospaced())
                                    }
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

    private var threshold: Double {
        BLEDistance.rssi(atMeters: killMeters, rssiAt1m: rssiAt1m, exponent: exponent)
    }

    /// Strongest fresh smoothed reading, used as the 1 m calibration point.
    private var closestRSSI: Int? {
        ble.freshSightings(within: 3).map(\.rssi).max()
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
