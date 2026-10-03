import CoreBluetooth
import Foundation
import Observation

/// Foreground BLE proximity: every phone advertises a short per-game token and scans for everyone else's.
///
/// The phone never decides who is "in range". It reports raw RSSI sightings to the server, which
/// applies the host-calibrated thresholds and decides kill/report eligibility.
///
/// The token travels in the advertisement local name ("AU" + token) next to a fixed service UUID.
/// That works while the app is in the foreground. In the background iOS drops the local name and
/// moves service UUIDs to the overflow area, so background play is out of scope (per PRD).
@Observable
final class BLEProximity: NSObject {
    static let serviceUUID = CBUUID(string: "8E1F0C5A-3B7D-4E2A-9C61-5A2F7D9B1E01")
    private static let namePrefix = "AU"

    struct Reading {
        var rssi: Double       // smoothed
        var rawRSSI: Int
        var lastSeen: Date
        var samples: Int
    }

    private(set) var centralState: CBManagerState = .unknown
    private(set) var peripheralState: CBManagerState = .unknown
    private(set) var readings: [String: Reading] = [:]
    private(set) var advertisingToken: String?
    private(set) var isAdvertising = false

    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var peripheral: CBPeripheralManager?
    /// The local name sometimes only arrives in the scan response, so remember which peripheral is which token.
    @ObservationIgnored private var tokenByPeripheral: [UUID: String] = [:]
    @ObservationIgnored private let smoothing = 0.35

    var statusMessage: String? {
        for state in [centralState, peripheralState] {
            switch state {
            case .poweredOff: return "Bluetooth is off. Turn it on in Control Center. Kills and body reports need it."
            case .unauthorized: return "Bluetooth access denied. Enable it in Settings > Privacy > Bluetooth > IRL Among Us."
            case .unsupported: return "This device doesn't support Bluetooth LE (the simulator doesn't either)."
            default: continue
            }
        }
        return nil
    }

    /// Start advertising `token` and scanning. Creating the managers triggers the permission prompt.
    func start(token: String) {
        if central == nil { central = CBCentralManager(delegate: self, queue: nil) }
        if peripheral == nil { peripheral = CBPeripheralManager(delegate: self, queue: nil) }
        if token != advertisingToken {
            advertisingToken = token
            readings = [:]
            tokenByPeripheral = [:]
            restartAdvertising()
        }
        startScanning()
    }

    func stop() {
        central?.stopScan()
        peripheral?.stopAdvertising()
        isAdvertising = false
        advertisingToken = nil
        readings = [:]
    }

    /// Sightings fresh enough to report to the server.
    func freshSightings(within seconds: TimeInterval = 3) -> [(token: String, rssi: Int)] {
        let cutoff = Date().addingTimeInterval(-seconds)
        return readings.compactMap { token, r in r.lastSeen >= cutoff ? (token, Int(r.rssi.rounded())) : nil }
    }

    private func restartAdvertising() {
        guard let peripheral, peripheral.state == .poweredOn, let token = advertisingToken else { return }
        peripheral.stopAdvertising()
        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
            CBAdvertisementDataLocalNameKey: Self.namePrefix + token,
        ])
    }

    private func startScanning() {
        guard let central, central.state == .poweredOn, !central.isScanning else { return }
        // Duplicates on: we want a continuous RSSI stream, not one callback per device.
        central.scanForPeripherals(withServices: [Self.serviceUUID],
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
}

extension BLEProximity: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        centralState = central.state
        startScanning()
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let rssi = RSSI.intValue
        guard rssi < 0 else { return } // 127 means "unavailable"
        if let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String, name.hasPrefix(Self.namePrefix) {
            tokenByPeripheral[peripheral.identifier] = String(name.dropFirst(Self.namePrefix.count))
        }
        guard let token = tokenByPeripheral[peripheral.identifier], token != advertisingToken else { return }

        var r = readings[token] ?? Reading(rssi: Double(rssi), rawRSSI: rssi, lastSeen: Date(), samples: 0)
        // Exponential moving average: RSSI is noisy (body blocking, orientation, multipath).
        r.rssi = r.samples == 0 ? Double(rssi) : r.rssi + smoothing * (Double(rssi) - r.rssi)
        r.rawRSSI = rssi
        r.lastSeen = Date()
        r.samples += 1
        readings[token] = r
    }
}

extension BLEProximity: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        peripheralState = peripheral.state
        restartAdvertising()
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        isAdvertising = error == nil
        if let error { print("BLE advertise error: \(error)") }
    }
}
