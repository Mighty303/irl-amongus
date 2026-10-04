import PhotosUI
import SwiftUI

/// The Among Us style customize window that pops up over the lobby: pick a suit color nobody else
/// is wearing, and put your own head on your crewmate (selfie or photo, fitted in an oval, with the
/// background cut out on the phone).
struct CustomizePanel: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let close: () -> Void

    private enum Tab { case color, face }

    @State private var tab = Tab.color
    @State private var showingCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var cutOut = true
    /// The photo being fitted (upright, resized) and its background-free version when segmentation worked.
    @State private var photo: UIImage?
    @State private var cutOutPhoto: UIImage?
    @State private var segmenting = false
    @State private var zoom: CGFloat = 1.2
    @State private var offset = CGSize.zero
    @State private var saving = false
    @State private var message: String?

    private static let ink = Color(white: 0.106)
    private static let muted = Color(white: 0.3)
    private static let well = Color(red: 0.91, green: 0.925, blue: 0.945)

    private var me: PlayerView? { state.player(state.me.id) }
    private var myColor: PlayerColor { me?.color ?? .red }

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.width < 560
            ZStack {
                Color.black.opacity(0.6).ignoresSafeArea()
                    .onTapGesture {} // the lobby underneath isn't interactive while customizing
                panel(compact: compact)
                    .frame(maxWidth: 640, maxHeight: compact ? 560 : 340)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
            }
        }
        .sheet(isPresented: $showingCamera) {
            SelfieCamera { startFitting($0) }.ignoresSafeArea()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    startFitting(image)
                } else {
                    message = "Couldn't open that photo."
                }
                photoItem = nil
            }
        }
    }

    private func panel(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Group {
                    if photo == nil { tabs } else { fitHeader }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: close) {
                    Image("CloseMenuIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close customize")
                .accessibilityIdentifier("customize.close")
            }
            let layout = compact ? AnyLayout(VStackLayout(spacing: 14)) : AnyLayout(HStackLayout(alignment: .top, spacing: 18))
            layout {
                preview(height: compact ? 96 : (photo == nil ? 130 : 110))
                    .frame(width: compact ? nil : (photo == nil ? 196 : 140))
                    .frame(maxWidth: compact ? .infinity : nil, maxHeight: compact ? 150 : .infinity)
                Group {
                    if photo != nil {
                        fitControls
                    } else if tab == .color {
                        colorGrid
                    } else {
                        faceOptions
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .foregroundStyle(Self.ink)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Self.ink, lineWidth: 4))
        .font(.system(size: 15, weight: .heavy, design: .rounded))
    }

    // MARK: - Header

    private var tabs: some View {
        HStack(spacing: 8) {
            tabButton("COLOR", systemImage: "paintpalette.fill", tab: .color)
            tabButton("FACE", systemImage: "face.smiling", tab: .face)
        }
    }

    private func tabButton(_ title: String, systemImage: String, tab: Tab) -> some View {
        let selected = self.tab == tab
        return Button {
            self.tab = tab
            message = nil
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .padding(.horizontal, 16)
                .frame(height: 40)
                .foregroundStyle(selected ? .white : Self.ink)
                .background(selected ? Self.ink : .white, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Self.ink, lineWidth: selected ? 0 : 3))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var fitHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Fit your face").font(.system(size: 20, weight: .black, design: .rounded))
            Text("Face in the oval, eyes on the line · drag · pinch to zoom")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Self.muted)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(height: 40)
    }

    // MARK: - Preview

    private func preview(height: CGFloat) -> some View {
        VStack(spacing: 10) {
            if let fitting = displayedPhoto {
                CrewmateView(color: myColor, height: height) { FaceCrop(image: fitting, zoom: zoom, offset: offset) }
            } else {
                CrewmateView(color: myColor, faceURL: store.faceURL(me?.faceId), height: height)
            }
            Text(state.me.name)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(Self.ink, in: Capsule())
        }
        .padding(.top, height * 0.06) // room for the head above the helmet
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Self.well, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(white: 0.8), lineWidth: 2))
    }

    // MARK: - Color

    private var colorGrid: some View {
        let owners = Dictionary(state.players.compactMap { p in p.color.map { ($0, p) } }, uniquingKeysWith: { a, _ in a })
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(myColor.name).font(.system(size: 20, weight: .black, design: .rounded))
                Spacer()
                Text("One crewmate per color").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(Self.muted)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 6) {
                ForEach(PlayerColor.allCases, id: \.self) { color in
                    let owner = owners[color]
                    let mine = owner?.id == state.me.id
                    let taken = owner != nil && !mine
                    VStack(spacing: 2) {
                        Button {
                            guard !mine else { return }
                            Task { await store.perform("set_color", ["color": color.rawValue]) }
                        } label: {
                            swatch(color, taken: taken, selected: mine)
                        }
                        .buttonStyle(.plain)
                        .disabled(taken)
                        .accessibilityLabel(taken ? "\(color.name), taken by \(owner?.name ?? "")" : color.name)
                        .accessibilityAddTraits(mine ? .isSelected : [])
                        Text(taken ? owner?.name ?? "" : " ")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(Self.muted)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func swatch(_ color: PlayerColor, taken: Bool, selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(color.swatch)
            .overlay(alignment: .bottom) { Rectangle().fill(.black.opacity(0.28)).frame(height: 12) }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                if taken {
                    ZStack {
                        Color.white.opacity(0.55)
                        Image(systemName: "xmark").font(.system(size: 22, weight: .black)).foregroundStyle(Color(red: 0.82, green: 0.1, blue: 0.1))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Self.ink, in: Circle())
                        .padding(3)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Self.ink, lineWidth: 3))
            .padding(selected ? 3 : 0)
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(selected ? Self.ink : .clear, lineWidth: 3))
            .frame(height: 46)
            .frame(minWidth: 44)
    }

    // MARK: - Face

    private var faceOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Put your head on your crewmate").font(.system(size: 20, weight: .black, design: .rounded))
                Text("Everyone in the lobby sees it.")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Self.muted)
            }
            HStack(spacing: 10) {
                if SelfieCamera.isAvailable {
                    Button { showingCamera = true } label: {
                        Label("TAKE SELFIE", systemImage: "camera")
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .foregroundStyle(.white)
                            .background(Self.ink, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("CHOOSE PHOTO", systemImage: "photo")
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Self.ink, lineWidth: 3))
                }
                .buttonStyle(.plain)
            }
            Toggle(isOn: $cutOut) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Cut out my head")
                    Text("Removes the photo background so only your head shows")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Self.muted)
                }
            }
            .tint(Self.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Self.well, in: RoundedRectangle(cornerRadius: 10))
            if me?.faceId != nil {
                Button("Remove my face") {
                    Task { await store.perform("set_face", ["faceId": NSNull()]) }
                }
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.7, green: 0.08, blue: 0.08))
            }
            if let message {
                Text(message).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Color(red: 0.7, green: 0.08, blue: 0.08))
            }
        }
    }

    // MARK: - Fit

    private var displayedPhoto: UIImage? {
        guard let photo else { return nil }
        return cutOut ? (cutOutPhoto ?? photo) : photo
    }

    private var fitControls: some View {
        HStack(alignment: .top, spacing: 14) {
            if let image = displayedPhoto {
                FaceFitter(image: image, zoom: $zoom, offset: $offset)
                    .overlay {
                        if segmenting {
                            ProgressView("Cutting out…").padding(10).background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Zoom").font(.system(size: 13, weight: .black, design: .rounded))
                Slider(value: $zoom, in: 1...4).tint(Self.ink)
                Toggle("Cut out head", isOn: $cutOut).tint(Self.ink).disabled(segmenting)
                if cutOut, !segmenting, cutOutPhoto == nil {
                    Text("No person found, so the whole photo is used.")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Self.muted)
                }
                if let message {
                    Text(message).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(Color(red: 0.7, green: 0.08, blue: 0.08))
                }
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    Button { stopFitting() } label: {
                        Text("RETAKE")
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Self.ink, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                    Button { useFace() } label: {
                        Text(saving ? "SAVING…" : "USE FACE")
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .foregroundStyle(.white)
                            .background(Self.ink, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(saving || segmenting)
                }
            }
        }
    }

    private func startFitting(_ image: UIImage) {
        let prepared = FaceCutout.prepare(image)
        photo = prepared
        cutOutPhoto = nil
        zoom = 1.2
        offset = .zero
        message = nil
        segmenting = true
        Task {
            cutOutPhoto = await FaceCutout.removeBackground(prepared)
            segmenting = false
        }
    }

    private func stopFitting() {
        photo = nil
        cutOutPhoto = nil
        message = nil
    }

    private func useFace() {
        guard let image = displayedPhoto, let png = FaceCutout.headPNG(image, zoom: zoom, offset: offset) else { return }
        saving = true
        message = nil
        Task {
            defer { saving = false }
            do {
                let faceId = try await store.uploadFace(png)
                if await store.perform("set_face", ["faceId": faceId]) {
                    stopFitting()
                    tab = .face
                } else {
                    message = store.errorMessage
                    store.errorMessage = nil
                }
            } catch {
                message = "Upload failed: \(error.localizedDescription)"
            }
        }
    }
}

/// The photo behind a head-shaped window. Drag to move it, pinch (or the slider) to zoom.
private struct FaceFitter: View {
    let image: UIImage
    @Binding var zoom: CGFloat
    @Binding var offset: CGSize
    @State private var dragStart: CGSize?
    @State private var zoomStart: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let ovalHeight = min(geo.size.height - 16, (geo.size.width - 16) / FaceCrop.aspect)
            let ovalWidth = ovalHeight * FaceCrop.aspect
            let oval = CGRect(x: (geo.size.width - ovalWidth) / 2, y: (geo.size.height - ovalHeight) / 2,
                              width: ovalWidth, height: ovalHeight)
            ZStack {
                // The photo extends past the oval (dimmed) so you can see what you're framing.
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: oval.width, height: oval.height)
                    .scaleEffect(zoom)
                    .offset(x: offset.width * oval.width, y: offset.height * oval.width)
                    .position(x: oval.midX, y: oval.midY)
                Path { p in
                    p.addRect(CGRect(origin: .zero, size: geo.size))
                    p.addEllipse(in: oval)
                }
                .fill(.white.opacity(0.82), style: FillStyle(eoFill: true))
                Ellipse().stroke(Color(white: 0.106), lineWidth: 4)
                    .frame(width: oval.width, height: oval.height)
                    .position(x: oval.midX, y: oval.midY)
                Path { p in
                    let y = oval.minY + oval.height * 0.47
                    p.move(to: CGPoint(x: oval.minX + 8, y: y))
                    p.addLine(to: CGPoint(x: oval.maxX - 8, y: y))
                }
                .stroke(Color(white: 0.106), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let start = dragStart ?? offset
                        dragStart = start
                        offset = CGSize(width: start.width + value.translation.width / oval.width,
                                        height: start.height + value.translation.height / oval.width)
                    }
                    .onEnded { _ in dragStart = nil }
                    .simultaneously(with: MagnifyGesture()
                        .onChanged { value in
                            let start = zoomStart ?? zoom
                            zoomStart = start
                            zoom = min(4, max(1, start * value.magnification))
                        }
                        .onEnded { _ in zoomStart = nil })
            )
        }
        .frame(width: 220)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(white: 0.8), lineWidth: 2))
        .accessibilityLabel("Your photo inside the head-shaped crop window")
    }
}

extension PlayerColor {
    /// The suit color, for the customize swatches and map dots.
    var swatch: Color {
        switch self {
        case .red: return Color(hex: 0xC51111)
        case .blue: return Color(hex: 0x132ED1)
        case .green: return Color(hex: 0x117F2D)
        case .pink: return Color(hex: 0xED54BA)
        case .orange: return Color(hex: 0xEF7D0D)
        case .yellow: return Color(hex: 0xF5F557)
        case .black: return Color(hex: 0x3F474E)
        case .white: return Color(hex: 0xD6E0F0)
        case .purple: return Color(hex: 0x6B2FBB)
        case .brown: return Color(hex: 0x71491E)
        case .cyan: return Color(hex: 0x38FEDC)
        case .lime: return Color(hex: 0x50EF39)
        case .maroon: return Color(hex: 0x6B2B3C)
        case .rose: return Color(hex: 0xECC0D3)
        case .banana: return Color(hex: 0xFFFEBE)
        }
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}
