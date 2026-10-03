import SwiftUI

/// Proves the player is at a station. Three methods, in order of preference:
///  1. Point the camera at the station's sign (Vision feature print / OCR match)
///  2. Scan the station's fallback QR
///  3. GPS geofence (validated server-side, coarse indoors)
struct CheckpointScannerView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let state: GameState

    @State private var distances: [String: Float] = [:]
    @State private var recognizedText: [String] = []
    @State private var candidate: (id: String, hits: Int)?
    @State private var submitting = false
    @State private var showDebug = false

    /// Consecutive matching frames required, to avoid one-off false positives.
    private let requiredHits = 2

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            VStack(spacing: 0) {
                CameraView(onQRCode: handleQR, onFrame: { [signs = store.signs, threshold = store.signThreshold] buffer in
                    // Camera queue: only touch thread-safe objects here, then hop to main.
                    let result = signs.analyze(buffer, threshold: threshold)
                    DispatchQueue.main.async { handle(result) }
                })
                    .frame(maxHeight: .infinity)
                    .overlay(alignment: .bottom) { matchOverlay }

                List {
                    Section {
                        VStack(alignment: .leading) {
                            Text("Match threshold: \(store.signThreshold, specifier: "%.2f") (lower = stricter)").font(.caption)
                            Slider(value: $store.signThreshold, in: 0.1...1.5)
                        }
                        Toggle("Show distances", isOn: $showDebug)
                        if showDebug {
                            ForEach(state.stations.filter { distances[$0.id] != nil }) { s in
                                Text("\(s.name): \(distances[s.id]!, specifier: "%.3f")").font(.caption.monospaced())
                            }
                            if !recognizedText.isEmpty {
                                Text("OCR: \(recognizedText.joined(separator: " | "))").font(.caption2)
                            }
                            Text("\(store.signs.loadedCount) reference signs loaded").font(.caption2)
                        }
                    }
                    Section("GPS check-in") {
                        ForEach(gpsStations, id: \.0.id) { station, distance in
                            Button("\(station.name): \(Int(distance)) m away (radius \(Int(station.radiusM)) m)") {
                                submit(station.id, method: "gps")
                            }
                        }
                        if gpsStations.isEmpty { Text("No GPS-tagged stations or no location fix").font(.caption) }
                    }
                    if state.settings.devSkipCheckpoint {
                        Section("DEV manual check-in") {
                            ForEach(state.stations) { s in Button(s.name) { submit(s.id, method: "manual") } }
                        }
                    }
                }
                .frame(height: 260)
            }
            .navigationTitle("Point at a station sign")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Close") { dismiss() } }
        }
    }

    @ViewBuilder private var matchOverlay: some View {
        if let candidate, let station = state.station(candidate.id) {
            Text("Recognizing \(station.name)…")
                .padding(10).background(.thinMaterial, in: Capsule()).padding()
        }
    }

    private var gpsStations: [(Station, Double)] {
        state.stations.compactMap { s in store.location.distance(to: s).map { (s, $0) } }.sorted { $0.1 < $1.1 }
    }

    private func handle(_ result: SignRecognizer.FrameResult) {
        distances = result.distances
        recognizedText = result.recognizedText
        guard let match = result.best else { candidate = nil; return }
        let hits = candidate?.id == match.stationId ? (candidate?.hits ?? 0) + 1 : 1
        candidate = (match.stationId, hits)
        if hits >= requiredHits { submit(match.stationId, method: "sign") }
    }

    private func handleQR(_ payload: String) {
        guard case let .station(id)? = QRPayload(payload) else { return }
        submit(id, method: "qr")
    }

    private func submit(_ stationId: String, method: String) {
        guard !submitting else { return }
        submitting = true
        Task {
            if await store.checkIn(stationId: stationId, method: method) { dismiss() }
            submitting = false
            candidate = nil
        }
    }
}
