import CoreLocation
import PhotosUI
import SwiftUI
import Vision

/// Photograph a sign and tag it with GPS. Players never name signs: the app reads the sign's text
/// (shown as "Reads “…”") and uses it as the label, falling back to `fallbackName`. The server assigns
/// random tasks to signs at game start.
struct StationEditorView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// Players adding their lobby signs: always a task sign, no station-kind picker or name.
    var signOnly = false
    var title = "New sign"
    /// Label used when the sign has no readable text, e.g. "Sign 2".
    var fallbackName = "Sign"
    /// Where the sign goes. Default: this lobby (`add_station`); saved games pass their own.
    var submit: (([String: Any]) async -> Bool)? = nil

    @State private var name = ""
    @State private var kind: StationKind = .task
    @State private var readText: String?
    @State private var reading = false
    @State private var radius: Double = 15
    @State private var photo: UIImage?
    @State private var latestFrame = FrameBox()
    @State private var saving = false
    @State private var pickerItem: PhotosPickerItem?
    /// Photos from the library carry their own location (EXIF), never the phone's current one.
    @State private var fromLibrary = false
    @State private var photoCoordinate: CLLocationCoordinate2D?
    /// Where the map opened, and where its pin is now (what gets saved). GPS is rough, so the player
    /// drags the map until the pin sits on the sign.
    @State private var pinStart: CLLocationCoordinate2D?
    @State private var pin: CLLocationCoordinate2D?
    /// SFU building and floor under the pin, saved with the sign.
    @State private var place: CampusPlace?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let photo {
                        Image(uiImage: photo).resizable().scaledToFit().frame(maxHeight: 260)
                            .frame(maxWidth: .infinity)
                        Group {
                            if reading {
                                Label("Reading the sign…", systemImage: "text.viewfinder")
                            } else if let readText {
                                Label("Reads “\(readText)”", systemImage: "text.viewfinder")
                            } else {
                                Label("No readable text. That's fine, the photo is enough.", systemImage: "text.viewfinder")
                            }
                        }
                        .font(.subheadline)
                        Button("Retake") { self.photo = nil; readText = nil; fromLibrary = false; photoCoordinate = nil; pinStart = nil; pin = nil; place = nil }
                    } else {
                        CameraView(onFrame: { buffer in latestFrame.buffer = buffer }, frameInterval: 0.2)
                            .frame(height: 300)
                            .listRowInsets(EdgeInsets())
                        Button("Take photo") { capture() }
                            .font(.headline)
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            Label("Choose from Photos", systemImage: "photo.on.rectangle")
                        }
                    }
                } header: {
                    Text("Sign photo")
                } footer: {
                    if signOnly {
                        Text("Room numbers, posters and exit signs work best. Fill the frame with the sign.")
                    }
                }

                if !signOnly {
                    Section("Station") {
                        Picker("Used as", selection: $kind) {
                            ForEach(StationKind.allCases) { Text($0.label).tag($0) }
                        }
                        TextField("Name (optional)", text: $name)
                    }
                }

                Section {
                    if photo != nil {
                        SignPinPicker(start: pinStart, pin: $pin, place: $place, others: store.state?.stations ?? [])
                            .frame(height: 260)
                            .listRowInsets(EdgeInsets())
                        Label(pin == nil ? "Zoom in and drag the map until the pin is on the sign"
                                  : pinStart == nil ? "No location to start from: drag the map to the sign"
                                  : "Drag the map until the pin is on the sign",
                              systemImage: "mappin.and.ellipse")
                    } else if fromLibrary {
                        if let photoCoordinate {
                            Label(String(format: "Location from the photo · %.5f, %.5f", photoCoordinate.latitude, photoCoordinate.longitude),
                                  systemImage: "location.fill")
                        } else {
                            Label("This photo has no saved location, so the sign won't get a map pin.", systemImage: "location.slash")
                        }
                    } else if let loc = store.location.location {
                        Label(String(format: "Location tagged · ±%.0f m", loc.horizontalAccuracy), systemImage: "location.fill")
                    } else {
                        Label(store.location.statusMessage ?? "Waiting for GPS… (saved without a map pin if none)", systemImage: "location.slash")
                    }
                    if !signOnly {
                        Stepper("Geofence radius: \(Int(radius)) m", value: $radius, in: 5...100, step: 5)
                    }
                } footer: {
                    Text("GPS gives a first guess; drag the map so the pin lands on the sign. The photo is what proves you're there.")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { save() }
                        .disabled(saving || reading || (signOnly && photo == nil))
                }
            }
            .onAppear { store.location.start() }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task { await usePicked(item) }
            }
        }
    }

    private func usePicked(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        guard let imported = await SignPhotoImport.load(item) else {
            store.errorMessage = "Couldn't load that photo"
            return
        }
        photo = imported.image
        fromLibrary = true
        photoCoordinate = imported.coordinate
        pinStart = imported.coordinate
        pin = imported.coordinate
        reading = true
        readText = await Self.readSignText(imported.image)
        reading = false
    }

    private func capture() {
        guard let image = latestFrame.buffer?.toUIImage() else {
            store.errorMessage = "No camera frame yet"
            return
        }
        photo = image
        pinStart = store.location.location?.coordinate
        pin = pinStart
        reading = true
        Task {
            readText = await Self.readSignText(image)
            reading = false
        }
    }

    private var label: String {
        let typed = name.trimmingCharacters(in: .whitespaces)
        if !typed.isEmpty { return typed }
        if let readText { return readText }
        return signOnly || kind == .task ? fallbackName : kind.label
    }

    private func save() {
        saving = true
        Task {
            defer { saving = false }
            var payload: [String: Any] = ["name": label, "kind": (signOnly ? .task : kind).rawValue, "radiusM": radius]
            if let readText { payload["signText"] = readText }
            if let coordinate = photo != nil ? pin : store.location.location?.coordinate {
                payload["lat"] = coordinate.latitude
                payload["lng"] = coordinate.longitude
            }
            if let place {
                payload["buildingId"] = place.buildingId
                payload["floorId"] = place.floorId
            }
            if let photo {
                do {
                    payload["photoId"] = try await store.uploadPhoto(photo)
                } catch {
                    store.errorMessage = "Photo upload failed: \(error.localizedDescription)"
                    return
                }
            }
            let saved = if let submit { await submit(payload) } else { await store.perform("add_station", payload) }
            if saved { dismiss() }
        }
    }

    /// The sign's most prominent text (its biggest line, plus a second line of similar size), or nil.
    static func readSignText(_ image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }
        return await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            try? VNImageRequestHandler(cgImage: cgImage).perform([request])
            let lines = (request.results ?? [])
                .compactMap { observation -> (text: String, height: CGFloat)? in
                    guard let text = observation.topCandidates(1).first?.string.trimmingCharacters(in: .whitespaces),
                          !text.isEmpty else { return nil }
                    return (text, observation.boundingBox.height)
                }
                .sorted { $0.height > $1.height }
            guard let biggest = lines.first else { return nil }
            var text = biggest.text
            if lines.count > 1, lines[1].height >= biggest.height * 0.8 { text += " " + lines[1].text }
            return String(text.prefix(30))
        }.value
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
