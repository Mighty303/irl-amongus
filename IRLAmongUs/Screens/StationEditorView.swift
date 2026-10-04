import SwiftUI

/// Host walks to a sign, photographs it, and tags it with GPS. That's the whole venue setup:
/// the server assigns random tasks to signs at game start.
struct StationEditorView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// Players adding their lobby signs: always a task sign, no station-kind picker.
    var signOnly = false
    var title = "New sign"

    @State private var name = ""
    @State private var kind: StationKind = .task
    @State private var signText = ""
    @State private var tagGPS = true
    @State private var radius: Double = 15
    @State private var photo: UIImage?
    @State private var latestFrame = FrameBox()
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Sign photo") {
                    if let photo {
                        Image(uiImage: photo).resizable().scaledToFit().frame(maxHeight: 260)
                        Button("Retake") { self.photo = nil }
                    } else {
                        CameraView(onFrame: { buffer in latestFrame.buffer = buffer }, frameInterval: 0.2)
                            .frame(height: 300)
                            .listRowInsets(EdgeInsets())
                        Button("Capture sign") {
                            photo = latestFrame.buffer?.toUIImage()
                            if photo == nil { store.errorMessage = "No camera frame yet" }
                        }
                    }
                }
                Section("Station") {
                    TextField("Name (e.g. Room 2005 sign)", text: $name)
                    if !signOnly {
                        Picker("Used as", selection: $kind) {
                            ForEach(StationKind.allCases) { Text($0.label).tag($0) }
                        }
                    }
                    TextField("Text on the sign (optional, for OCR)", text: $signText)
                }
                Section {
                    Toggle("Tag current GPS location", isOn: $tagGPS)
                    if let loc = store.location.location {
                        Text(String(format: "%.6f, %.6f  ±%.0f m", loc.coordinate.latitude, loc.coordinate.longitude, loc.horizontalAccuracy))
                            .font(.caption.monospaced())
                    } else {
                        Text(store.location.statusMessage ?? "Waiting for GPS…").font(.caption)
                    }
                    Stepper("Geofence radius: \(Int(radius)) m", value: $radius, in: 5...100, step: 5)
                } footer: {
                    Text("GPS places the pin on the mini-map and enables GPS check-in. Indoors it's rough. Sign recognition is the main check-in method.")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { save() }.disabled(name.isEmpty || saving)
                }
            }
            .onAppear { store.location.start() }
        }
    }

    private func save() {
        saving = true
        Task {
            defer { saving = false }
            var payload: [String: Any] = ["name": name, "kind": kind.rawValue, "radiusM": radius]
            if !signText.isEmpty { payload["signText"] = signText }
            if tagGPS, let loc = store.location.location {
                payload["lat"] = loc.coordinate.latitude
                payload["lng"] = loc.coordinate.longitude
            }
            if let photo {
                do {
                    payload["photoId"] = try await store.uploadPhoto(photo)
                } catch {
                    store.errorMessage = "Photo upload failed: \(error.localizedDescription)"
                    return
                }
            }
            if await store.perform("add_station", payload) { dismiss() }
        }
    }
}

/// Holds the latest camera frame without triggering SwiftUI updates on every frame.
final class FrameBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _buffer: CVPixelBuffer?
    var buffer: CVPixelBuffer? {
        get { lock.withLock { _buffer } }
        set { lock.withLock { _buffer = newValue } }
    }
}
