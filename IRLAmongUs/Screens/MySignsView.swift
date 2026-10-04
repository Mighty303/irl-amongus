import CoreLocation
import PhotosUI
import SwiftUI

/// The white Among Us style pop-up (same look as Customize) where a player adds the signs they owe
/// before the game can start. Adding a sign happens in the same panel: take a photo or pick one from
/// Photos, the app reads what the sign says, then save. No naming.
struct MySignsView: View {
    @Environment(GameStore.self) private var store
    let close: () -> Void

    // Customize panel palette.
    private static let ink = Color(white: 0.106)
    private static let muted = Color(white: 0.3)
    private static let well = Color(red: 0.91, green: 0.925, blue: 0.945)
    private static let ready = Color(red: 0.2, green: 0.62, blue: 0.36)

    @State private var capturing = false
    @State private var latestFrame = FrameBox()
    @State private var photo: UIImage?
    @State private var fromLibrary = false
    @State private var photoCoordinate: CLLocationCoordinate2D?
    @State private var readText: String?
    @State private var reading = false
    @State private var saving = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var message: String?

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.width < 560
            ZStack {
                Color.black.opacity(0.6).ignoresSafeArea()
                    .onTapGesture {} // the lobby underneath isn't interactive while this is open
                if let state = store.state {
                    panel(state: state, compact: compact)
                        .frame(maxWidth: 640, maxHeight: compact ? 600 : 340)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                }
            }
        }
        .onAppear { store.location.start() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await usePicked(item) }
        }
    }

    private func panel(state: GameState, compact: Bool) -> some View {
        let required = max(state.requiredSigns, 1)
        return VStack(alignment: .leading, spacing: 12) {
            header(mine: state.mySigns.count, required: required)
            if capturing {
                captureStep(compact: compact, number: min(state.mySigns.count + 1, required), required: required)
            } else {
                slots(state.mySigns, required: required)
            }
            if let message {
                Text(message).font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.7, green: 0.08, blue: 0.08))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .foregroundStyle(Self.ink)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Self.ink, lineWidth: 4))
        .overlay(alignment: .topLeading) {
            Button { capturing ? stopCapturing() : close() } label: {
                Image("CloseMenuIcon").resizable().frame(width: 44, height: 44)
            }
            .offset(x: -16, y: -16)
            .accessibilityLabel(capturing ? "Back to my signs" : "Close my signs")
        }
        .font(.system(size: 15, weight: .heavy, design: .rounded))
    }

    private func header(mine: Int, required: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(capturing ? "Add a sign" : "My signs").font(.system(size: 20, weight: .black, design: .rounded))
            Text(capturing ? "Fill the frame with the sign · no naming needed"
                 : "\(min(mine, required)) of \(required) · point and shoot, the app reads each sign")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Self.muted)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(height: 40)
        .padding(.leading, 26)
    }

    // MARK: - Slots

    private func slots(_ mine: [Station], required: Int) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(mine.enumerated()), id: \.element.id) { index, sign in
                    filledSlot(sign, number: index + 1)
                }
                if mine.count < required {
                    ForEach(mine.count..<required, id: \.self) { index in
                        emptySlot(number: index + 1, of: required, next: index == mine.count)
                    }
                }
            }
            .padding(2)
        }
        .frame(maxHeight: .infinity)
    }

    private func filledSlot(_ sign: Station, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Self.well
                .overlay {
                    if let photoId = sign.photoId, let base = store.serverURL {
                        AsyncImage(url: base.appendingPathComponent("photos/\(photoId).jpg")) { $0.resizable().scaledToFill() }
                            placeholder: { ProgressView() }
                    }
                }
                .frame(width: 168, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    Text("SIGN \(number)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Self.ready, in: Capsule())
                        .padding(6)
                }
            HStack(alignment: .center, spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(sign.signText.map { "Reads “\($0)”" } ?? sign.name)
                        .font(.system(size: 13, weight: .black, design: .rounded)).lineLimit(1)
                    Text(sign.lat != nil ? "Location tagged" : "No GPS (photo only)")
                        .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Self.muted)
                }
                Spacer(minLength: 0)
                Button {
                    Task { await store.perform("delete_station", ["stationId": sign.id]) }
                } label: {
                    Image(systemName: "trash").font(.system(size: 13, weight: .bold))
                        .frame(width: 32, height: 32)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Self.ink, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete sign \(number)")
            }
            .frame(width: 168)
        }
        .padding(8)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(white: 0.8), lineWidth: 2))
    }

    private func emptySlot(number: Int, of required: Int, next: Bool) -> some View {
        Button { startCapturing() } label: {
            VStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(next ? .white : Self.ink)
                    .frame(width: 52, height: 52)
                    .background(next ? Self.ink : Self.well, in: Circle())
                Text("Add sign").font(.system(size: 15, weight: .black, design: .rounded))
                Text("Sign \(number) of \(required)").font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Self.muted)
            }
            .frame(width: 150, height: 172)
            .background(Self.well.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(Self.ink.opacity(next ? 1 : 0.35), style: StrokeStyle(lineWidth: 3, dash: [8, 6])))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mySigns.add.\(number)")
    }

    // MARK: - Capture

    private func captureStep(compact: Bool, number: Int, required: Int) -> some View {
        let layout = compact ? AnyLayout(VStackLayout(spacing: 14)) : AnyLayout(HStackLayout(alignment: .top, spacing: 18))
        return layout {
            ZStack {
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                } else {
                    CameraView(onFrame: { buffer in latestFrame.buffer = buffer }, frameInterval: 0.2)
                }
            }
            .frame(width: compact ? nil : 300)
            .frame(maxWidth: compact ? .infinity : nil, maxHeight: compact ? 260 : .infinity)
            .background(Self.well)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(white: 0.8), lineWidth: 2))

            VStack(alignment: .leading, spacing: 10) {
                Text("Sign \(number) of \(required)").font(.system(size: 20, weight: .black, design: .rounded))
                if photo == nil {
                    filledButton("TAKE PHOTO", systemImage: "camera.fill") { takePhoto() }
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        outlineLabel("CHOOSE FROM PHOTOS", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.plain)
                } else {
                    Label(reading ? "Reading the sign…" : readText.map { "Reads “\($0)”" } ?? "No readable text, the photo is enough",
                          systemImage: "text.viewfinder")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .lineLimit(2)
                }
                Label(locationText, systemImage: hasLocation ? "location.fill" : "location.slash")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Self.muted)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if photo != nil {
                    HStack(spacing: 10) {
                        Button { photo = nil; readText = nil; fromLibrary = false; photoCoordinate = nil } label: {
                            outlineLabel("RETAKE", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.plain)
                        filledButton(saving ? "SAVING…" : "SAVE SIGN", systemImage: "checkmark") { save(number: number) }
                            .disabled(saving || reading)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var hasLocation: Bool {
        fromLibrary ? photoCoordinate != nil : store.location.location != nil
    }

    private var locationText: String {
        if fromLibrary {
            return photoCoordinate == nil ? "This photo has no saved location: no map pin" : "Location from the photo"
        }
        if let loc = store.location.location { return String(format: "Location tagged · ±%.0f m", loc.horizontalAccuracy) }
        return "Waiting for GPS (saved without a map pin if none)"
    }

    private func filledButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(.white)
                .background(Self.ink, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func outlineLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 15, weight: .black, design: .rounded))
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(Self.ink)
            .background(.white, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Self.ink, lineWidth: 3))
    }

    // MARK: - Actions

    private func startCapturing() {
        message = nil
        photo = nil
        readText = nil
        fromLibrary = false
        photoCoordinate = nil
        capturing = true
    }

    private func stopCapturing() {
        capturing = false
        photo = nil
        message = nil
    }

    private func takePhoto() {
        guard let image = latestFrame.buffer?.toUIImage() else {
            message = "No camera frame yet"
            return
        }
        photo = image
        fromLibrary = false
        read(image)
    }

    private func usePicked(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        guard let imported = await SignPhotoImport.load(item) else {
            message = "Couldn't open that photo."
            return
        }
        photo = imported.image
        fromLibrary = true
        photoCoordinate = imported.coordinate
        read(imported.image)
    }

    private func read(_ image: UIImage) {
        reading = true
        Task {
            readText = await StationEditorView.readSignText(image)
            reading = false
        }
    }

    private func save(number: Int) {
        guard let photo else { return }
        saving = true
        message = nil
        Task {
            defer { saving = false }
            var payload: [String: Any] = ["name": readText ?? "Sign \(number)", "kind": "task", "radiusM": 15]
            if let readText { payload["signText"] = readText }
            if let coordinate = fromLibrary ? photoCoordinate : store.location.location?.coordinate {
                payload["lat"] = coordinate.latitude
                payload["lng"] = coordinate.longitude
            }
            do {
                payload["photoId"] = try await store.uploadPhoto(photo)
            } catch {
                message = "Photo upload failed: \(error.localizedDescription)"
                return
            }
            if await store.perform("add_station", payload) {
                Haptics.success()
                stopCapturing()
            }
        }
    }
}
