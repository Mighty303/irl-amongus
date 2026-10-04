import CoreLocation
import PhotosUI
import SwiftUI

/// The white Among Us style panel (same look as Customize) used for adding signs.
enum SignPanel {
    static let ink = Color(white: 0.106)
    static let muted = Color(white: 0.3)
    static let well = Color(red: 0.91, green: 0.925, blue: 0.945)
    static let ready = Color(red: 0.2, green: 0.62, blue: 0.36)
    static let error = Color(red: 0.7, green: 0.08, blue: 0.08)

    static func filledButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(.white)
                .background(ink, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    static func outlineLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 15, weight: .black, design: .rounded))
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(ink)
            .background(.white, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(ink, lineWidth: 3))
    }

    static func header(_ title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title).font(.system(size: 20, weight: .black, design: .rounded))
            Text(subtitle)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(muted)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(height: 40)
        .padding(.leading, 26)
    }
}

/// Dimmed backdrop with the panel centered at the Customize panel's size.
struct SignPanelContainer<Content: View>: View {
    @ViewBuilder let content: (_ compact: Bool) -> Content

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.width < 560
            ZStack {
                Color.black.opacity(0.6).ignoresSafeArea()
                    .onTapGesture {} // what's underneath isn't interactive while this is open
                content(compact)
                    .frame(maxWidth: 640, maxHeight: compact ? 600 : 340)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
            }
        }
    }
}

extension View {
    /// White panel, ink outline and the Among Us X in the corner, at one fixed size.
    func signPanel(closeLabel: String, close: @escaping () -> Void) -> some View {
        padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading) // same size for every step
            .foregroundStyle(SignPanel.ink)
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(SignPanel.ink, lineWidth: 4))
            .overlay(alignment: .topLeading) {
                Button(action: close) {
                    Image("CloseMenuIcon").resizable().frame(width: 44, height: 44)
                }
                .offset(x: -16, y: -16)
                .accessibilityLabel(closeLabel)
            }
            .font(.system(size: 15, weight: .heavy, design: .rounded))
    }
}

/// Camera (or a photo from Photos) as a square on the left, controls on the right. The app reads
/// what the sign says; nobody names signs. Once there's a photo the square becomes a map with a pin
/// that starts at the GPS fix (library photos: their own saved location, never the phone's current
/// one) and the player drags it onto the sign. After a save it resets, ready for the next sign.
struct SignCaptureStep: View {
    @Environment(GameStore.self) private var store
    let compact: Bool
    /// e.g. "Sign 2 of 3".
    let title: String
    /// Label used when the sign has no readable text.
    let fallbackName: String
    /// Adds the sign; true when it worked.
    let submit: ([String: Any]) async -> Bool
    var onSaved: () -> Void = {}
    /// Special signs (red button, reactor, ...) keep their own name, e.g. "Red button"; task signs are named by their text.
    var kind: StationKind = .task
    var fixedName: String? = nil

    @State private var latestFrame = FrameBox()
    @State private var photo: UIImage?
    @State private var fromLibrary = false
    @State private var photoCoordinate: CLLocationCoordinate2D?
    /// Where the map opened, and where its pin is now (what gets saved).
    @State private var pinStart: CLLocationCoordinate2D?
    @State private var pin: CLLocationCoordinate2D?
    /// SFU building and floor under the pin, saved with the sign.
    @State private var place: CampusPlace?
    /// Shows the photo in the square instead of the map.
    @State private var showingPhoto = false
    @State private var readText: String?
    @State private var reading = false
    @State private var saving = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var message: String?

    var body: some View {
        let layout = compact ? AnyLayout(VStackLayout(spacing: 14)) : AnyLayout(HStackLayout(alignment: .top, spacing: 18))
        layout {
            // An overlay, so the photo fills this frame instead of resizing it to the photo.
            SignPanel.well
                .overlay {
                    if let photo, showingPhoto {
                        Image(uiImage: photo).resizable().scaledToFill()
                    } else if photo != nil {
                        SignPinPicker(start: pinStart, pin: $pin, place: $place, others: store.state?.stations ?? [])
                    } else {
                        CameraView(onFrame: { buffer in latestFrame.buffer = buffer }, frameInterval: 0.2)
                    }
                }
                .frame(width: compact ? nil : 260)
                .frame(maxWidth: compact ? .infinity : nil, maxHeight: compact ? 260 : .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .topLeading) {
                    if photo != nil {
                        Button { showingPhoto.toggle() } label: {
                            Label(showingPhoto ? "MAP" : "PHOTO", systemImage: showingPhoto ? "map.fill" : "photo.fill")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(SignPanel.ink, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .accessibilityLabel(showingPhoto ? "Show the map" : "Show the photo")
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(white: 0.8), lineWidth: 2))

            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.system(size: 20, weight: .black, design: .rounded))
                if photo == nil {
                    SignPanel.filledButton("TAKE PHOTO", systemImage: "camera.fill") { takePhoto() }
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        SignPanel.outlineLabel("CHOOSE FROM PHOTOS", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.plain)
                } else {
                    Label(reading ? "Reading the sign…" : readText.map { "Reads “\($0)”" } ?? "No readable text, the photo is enough",
                          systemImage: "text.viewfinder")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .lineLimit(2)
                }
                Label(locationText, systemImage: photo != nil ? "mappin.and.ellipse" : hasLocation ? "location.fill" : "location.slash")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(SignPanel.muted)
                    .lineLimit(2)
                if let message {
                    Text(message).font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(SignPanel.error)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                if photo != nil {
                    HStack(spacing: 10) {
                        Button { reset() } label: {
                            SignPanel.outlineLabel("RETAKE", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.plain)
                        SignPanel.filledButton(saving ? "SAVING…" : "SAVE SIGN", systemImage: "checkmark") { save() }
                            .disabled(saving || reading)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear { store.location.start() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await usePicked(item) }
        }
    }

    private var hasLocation: Bool {
        fromLibrary ? photoCoordinate != nil : store.location.location != nil
    }

    private var locationText: String {
        if photo != nil {
            if showingPhoto { return "Tap MAP to put the pin on the sign" }
            if pin == nil { return "Zoom in and drag the map until the pin is on the sign" }
            if pinStart == nil { return fromLibrary ? "This photo has no saved location: drag the map to the sign" : "No GPS yet: drag the map to the sign" }
            return "Drag the map until the pin is on the sign"
        }
        if fromLibrary {
            return photoCoordinate == nil ? "This photo has no saved location: no map pin" : "Location from the photo"
        }
        if let loc = store.location.location { return String(format: "Location tagged · ±%.0f m", loc.horizontalAccuracy) }
        return "Waiting for GPS (saved without a map pin if none)"
    }

    private func reset() {
        photo = nil
        readText = nil
        fromLibrary = false
        photoCoordinate = nil
        pinStart = nil
        pin = nil
        place = nil
        showingPhoto = false
        message = nil
    }

    private func takePhoto() {
        guard let image = latestFrame.buffer?.toUIImage() else {
            message = "No camera frame yet"
            return
        }
        message = nil
        photo = image
        fromLibrary = false
        placePin(at: store.location.location?.coordinate)
        read(image)
    }

    private func usePicked(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        guard let imported = await SignPhotoImport.load(item) else {
            message = "Couldn't open that photo."
            return
        }
        message = nil
        photo = imported.image
        fromLibrary = true
        photoCoordinate = imported.coordinate
        placePin(at: imported.coordinate)
        read(imported.image)
    }

    private func placePin(at coordinate: CLLocationCoordinate2D?) {
        pinStart = coordinate
        pin = coordinate
        showingPhoto = false
    }

    private func read(_ image: UIImage) {
        reading = true
        Task {
            readText = await StationEditorView.readSignText(image)
            reading = false
        }
    }

    private func save() {
        guard let photo else { return }
        saving = true
        message = nil
        Task {
            defer { saving = false }
            var payload: [String: Any] = ["name": fixedName ?? readText ?? fallbackName, "kind": kind.rawValue, "radiusM": 15]
            if let readText { payload["signText"] = readText }
            if let coordinate = pin {
                payload["lat"] = coordinate.latitude
                payload["lng"] = coordinate.longitude
            }
            if let place {
                payload["buildingId"] = place.buildingId
                payload["floorId"] = place.floorId
            }
            do {
                payload["photoId"] = try await store.uploadPhoto(photo)
            } catch {
                message = "Photo upload failed: \(error.localizedDescription)"
                return
            }
            if await submit(payload) {
                Haptics.success()
                reset()
                onSaved()
            }
        }
    }
}
