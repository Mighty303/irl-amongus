import AVFoundation
import SwiftUI
import UIKit

struct ContentView: View {
    private static let referenceSize = CGSize(width: 828, height: 1792)
    private static let audioEnabled = !ProcessInfo.processInfo.arguments.contains("-disableAudio")
    private static let animatedSceneHeight = 1288.0

    private static let stars = [
        Star(x: 31, y: 128, radius: 16, phase: 0.1, speed: 1.1),
        Star(x: 103, y: 147, radius: 8, phase: 1.8, speed: 1.5),
        Star(x: 212, y: 54, radius: 9, phase: 2.7, speed: 1.2),
        Star(x: 531, y: 22, radius: 14, phase: 4.2, speed: 1.7),
        Star(x: 799, y: 128, radius: 9, phase: 3.4, speed: 1.3),
        Star(x: 446, y: 142, radius: 7, phase: 5.1, speed: 1.9),
        Star(x: 734, y: 207, radius: 9, phase: 0.9, speed: 1.4),
        Star(x: 329, y: 294, radius: 7, phase: 2.1, speed: 1.8),
        Star(x: 568, y: 248, radius: 7, phase: 3.8, speed: 1.3),
        Star(x: 95, y: 438, radius: 8, phase: 1.2, speed: 1.7),
        Star(x: 160, y: 414, radius: 10, phase: 4.7, speed: 1.4),
        Star(x: 298, y: 432, radius: 10, phase: 2.9, speed: 1.6),
        Star(x: 366, y: 448, radius: 12, phase: 0.5, speed: 1.2),
        Star(x: 637, y: 468, radius: 9, phase: 5.7, speed: 1.8),
        Star(x: 154, y: 571, radius: 9, phase: 3.1, speed: 1.5),
        Star(x: 510, y: 635, radius: 9, phase: 1.4, speed: 1.9),
        Star(x: 68, y: 696, radius: 9, phase: 4.4, speed: 1.3),
        Star(x: 297, y: 649, radius: 16, phase: 2.3, speed: 1.6),
        Star(x: 799, y: 747, radius: 16, phase: 5.3, speed: 1.4),
        Star(x: 63, y: 820, radius: 8, phase: 0.8, speed: 1.8),
        Star(x: 340, y: 865, radius: 7, phase: 3.7, speed: 1.5),
        Star(x: 451, y: 901, radius: 10, phase: 1.9, speed: 1.2),
        Star(x: 18, y: 1152, radius: 14, phase: 4.9, speed: 1.7),
        Star(x: 307, y: 1118, radius: 8, phase: 2.5, speed: 1.4),
        Star(x: 538, y: 1221, radius: 9, phase: 0.3, speed: 1.9),
        Star(x: 767, y: 1152, radius: 10, phase: 3.3, speed: 1.3)
    ]

    private static let hotspots = [
        MenuHotspot(
            title: "Local",
            message: "Create or join a game with people nearby.",
            frame: CGRect(x: 94, y: 1300, width: 310, height: 132)
        ),
        MenuHotspot(
            title: "Online",
            message: "Online matchmaking is coming soon.",
            frame: CGRect(x: 418, y: 1300, width: 315, height: 132)
        ),
        MenuHotspot(
            title: "How to Play",
            message: "Complete your tasks, find the impostor, and survive.",
            frame: CGRect(x: 94, y: 1445, width: 310, height: 90)
        ),
        MenuHotspot(
            title: "Freeplay",
            message: "Freeplay mode is coming soon.",
            frame: CGRect(x: 418, y: 1445, width: 315, height: 90)
        ),
        MenuHotspot(
            title: "Announcements",
            message: "There are no new announcements.",
            frame: CGRect(x: 244, y: 1540, width: 105, height: 108)
        ),
        MenuHotspot(
            title: "Account",
            message: "Player profiles are coming soon.",
            frame: CGRect(x: 357, y: 1540, width: 110, height: 108)
        ),
        MenuHotspot(
            title: "Store",
            message: "The store is coming soon.",
            frame: CGRect(x: 477, y: 1540, width: 108, height: 108)
        ),
        MenuHotspot(
            title: "Settings",
            message: "Game settings are coming soon.",
            frame: CGRect(x: 302, y: 1645, width: 110, height: 108)
        ),
        MenuHotspot(
            title: "Statistics",
            message: "Player statistics are coming soon.",
            frame: CGRect(x: 426, y: 1645, width: 110, height: 108)
        )
    ]

    @State private var selectedHotspot: MenuHotspot?
    @State private var showingPhysicalMap = false
    @State private var showingDeveloperMenu = ProcessInfo.processInfo.arguments.contains("-showDeveloperMenu")
    @State private var openMapAfterDeveloperMenu = false
    @State private var travelProgress = 0.0
    @StateObject private var themeAudio = ThemeAudioPlayer()
    @StateObject private var buttonAudio = ButtonPressAudioPlayer()

    var body: some View {
        GeometryReader { geometry in
            let scale = max(
                geometry.size.width / Self.referenceSize.width,
                geometry.size.height / Self.referenceSize.height
            )
            let artworkSize = CGSize(
                width: Self.referenceSize.width * scale,
                height: Self.referenceSize.height * scale
            )
            let origin = CGPoint(
                x: (geometry.size.width - artworkSize.width) / 2,
                y: (geometry.size.height - artworkSize.height) / 2
            )

            ZStack(alignment: .topLeading) {
                Color.black

                Image("MainMenu")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: artworkSize.width, height: artworkSize.height)
                    .offset(x: origin.x, y: origin.y)
                    .accessibilityHidden(true)

                Color.black
                    .frame(
                        width: artworkSize.width,
                        height: Self.animatedSceneHeight * scale
                    )
                    .offset(x: origin.x, y: origin.y)

                TwinklingStarfield(stars: Self.stars, scale: scale)
                    .frame(width: artworkSize.width, height: artworkSize.height)
                    .offset(x: origin.x, y: origin.y)
                    .allowsHitTesting(false)

                Text("IRL Among Us")
                    .font(.system(size: 92 * scale, weight: .ultraLight, design: .rounded))
                    .tracking(2 * scale)
                    .foregroundStyle(Color(white: 0.68))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 700 * scale)
                    .position(
                        x: origin.x + Self.referenceSize.width * scale / 2,
                        y: origin.y + 225 * scale
                    )
                    .accessibilityAddTraits(.isHeader)

                Image("RedCrewmate")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 245 * scale, height: 175 * scale)
                    .rotationEffect(.degrees(-7))
                    .position(
                        x: origin.x + (-150 + travelProgress * 1_128) * scale,
                        y: origin.y + 870 * scale
                    )
                    .accessibilityHidden(true)

                ForEach(Self.hotspots) { hotspot in
                    Button {
                        buttonAudio.play()
                        if hotspot.title == "Local" {
                            themeAudio.pause()
                            showingPhysicalMap = true
                        } else {
                            selectedHotspot = hotspot
                        }
                    } label: {
                        Color.clear
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(
                        width: hotspot.frame.width * scale,
                        height: hotspot.frame.height * scale
                    )
                    .offset(
                        x: origin.x + hotspot.frame.minX * scale,
                        y: origin.y + hotspot.frame.minY * scale
                    )
                    .accessibilityLabel(hotspot.title)
                    .accessibilityHint("Opens \(hotspot.title)")
                }

                Button {
                    buttonAudio.play()
                    themeAudio.toggleMuted()
                } label: {
                    Image(systemName: themeAudio.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(.black.opacity(0.6), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.45), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .position(x: geometry.size.width - 40, y: 56)
                .accessibilityLabel(themeAudio.isMuted ? "Unmute theme music" : "Mute theme music")
                .accessibilityHint("Toggles the opening theme music")
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .background {
#if DEBUG
            ShakeDetectorView {
                guard !showingPhysicalMap else { return }
                showingDeveloperMenu = true
            }
            .allowsHitTesting(false)
#endif
        }
        .onAppear {
            if Self.audioEnabled {
                themeAudio.play()
            }
            travelProgress = 0
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                travelProgress = 1
            }
        }
        .alert(item: $selectedHotspot) { hotspot in
            Alert(
                title: Text(hotspot.title),
                message: Text(hotspot.message),
                dismissButton: .default(Text("Back"))
            )
        }
        .sheet(isPresented: $showingDeveloperMenu, onDismiss: openPendingDeveloperDestination) {
            DeveloperMenuView {
                openMapAfterDeveloperMenu = true
                showingDeveloperMenu = false
            }
            .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $showingPhysicalMap, onDismiss: {
            if Self.audioEnabled {
                themeAudio.play()
            }
        }) {
            PhysicalMapPOCView()
        }
    }

    private func openPendingDeveloperDestination() {
        guard openMapAfterDeveloperMenu else { return }
        openMapAfterDeveloperMenu = false
        themeAudio.pause()
        showingPhysicalMap = true
    }
}

@MainActor
private final class ButtonPressAudioPlayer: ObservableObject {
    private var player: AVAudioPlayer?

    func play() {
        if player == nil {
            guard let url = Bundle.main.url(forResource: "button-press", withExtension: "mp3") else {
                return
            }

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                self.player = player
            } catch {
                // Button actions still work if audio is unavailable on a device.
                return
            }
        }

        player?.currentTime = 0
        player?.play()
    }
}

@MainActor
private final class ThemeAudioPlayer: ObservableObject {
    @Published private(set) var isMuted = false

    private var player: AVAudioPlayer?

    func play() {
        guard player == nil else {
            if !isMuted { player?.play() }
            return
        }

        guard let url = Bundle.main.url(forResource: "among-us-theme-song", withExtension: "mp3") else {
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.prepareToPlay()
            player.play()
            self.player = player
        } catch {
            // The menu remains usable if audio is unavailable on a device.
        }
    }

    func toggleMuted() {
        isMuted.toggle()
        if isMuted {
            player?.pause()
        } else {
            player?.play()
        }
    }

    func pause() {
        player?.pause()
    }
}

private struct Star: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
    let radius: Double
    let phase: Double
    let speed: Double
}

private struct TwinklingStarfield: View {
    let stars: [Star]
    let scale: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            Canvas { context, _ in
                let time = timeline.date.timeIntervalSinceReferenceDate

                for star in stars {
                    let pulse = (sin(time * star.speed + star.phase) + 1) / 2
                    let radius = star.radius * (0.65 + pulse * 0.35) * scale
                    let center = CGPoint(x: star.x * scale, y: star.y * scale)
                    var starContext = context
                    starContext.opacity = 0.35 + pulse * 0.65

                    let glowRect = CGRect(
                        x: center.x - radius * 0.45,
                        y: center.y - radius * 0.45,
                        width: radius * 0.9,
                        height: radius * 0.9
                    )
                    starContext.fill(
                        Path(ellipseIn: glowRect),
                        with: .color(.white.opacity(0.8))
                    )

                    var rays = Path()
                    rays.move(to: CGPoint(x: center.x, y: center.y - radius))
                    rays.addLine(to: CGPoint(x: center.x, y: center.y + radius))
                    rays.move(to: CGPoint(x: center.x - radius, y: center.y))
                    rays.addLine(to: CGPoint(x: center.x + radius, y: center.y))
                    starContext.stroke(
                        rays,
                        with: .color(.white),
                        lineWidth: max(0.8, 1.4 * scale)
                    )
                }
            }
        }
    }
}

private struct MenuHotspot: Identifiable {
    let title: String
    let message: String
    let frame: CGRect

    var id: String { title }
}

private struct DeveloperMenuView: View {
    let onOpenPhysicalMap: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Proofs of concept") {
                    Button(action: onOpenPhysicalMap) {
                        Label("Open Physical Map POC", systemImage: "map.fill")
                    }
                    .accessibilityIdentifier("developer.openPhysicalMap")
                }

                Section("Developer shortcut") {
                    Label("Shake the device to open this menu.", systemImage: "iphone.gen3.radiowaves.left.and.right")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Developer Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#if DEBUG
private struct ShakeDetectorView: UIViewControllerRepresentable {
    let onShake: () -> Void

    func makeUIViewController(context: Context) -> ShakeDetectorViewController {
        let controller = ShakeDetectorViewController()
        controller.onShake = onShake
        return controller
    }

    func updateUIViewController(_ controller: ShakeDetectorViewController, context: Context) {
        controller.onShake = onShake
    }
}

private final class ShakeDetectorViewController: UIViewController {
    var onShake: (() -> Void)?

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else {
            super.motionEnded(motion, with: event)
            return
        }

        onShake?()
    }
}
#endif

private struct PhysicalMapPOCView: View {
    private static let rooms = SUBLevel2Map.rooms

    private static let stations = [
        POCStation(id: "electrical", displayName: "Electrical", taskType: "Fix Wiring", roomID: "2125", roomLabel: "SUB 2125 · Community Kitchen", position: SUBLevel2Map.center(of: "2125")),
        POCStation(id: "reactor-a", displayName: "Reactor A", taskType: "Start Reactor", roomID: "2310", roomLabel: "SUB 2310 · Dining", position: SUBLevel2Map.center(of: "2310")),
        POCStation(id: "reactor-b", displayName: "Reactor B", taskType: "Start Reactor", roomID: "2400", roomLabel: "SUB 2400 · Gamers' Lounge", position: SUBLevel2Map.center(of: "2400")),
        POCStation(id: "communications", displayName: "Communications", taskType: "Upload Data", roomID: "2410", roomLabel: "SUB 2410 · Rehearsal Room", position: SUBLevel2Map.center(of: "2410")),
        POCStation(id: "medbay", displayName: "Medbay", taskType: "Submit Scan", roomID: "2440", roomLabel: "SUB 2440 · Meeting Room", position: SUBLevel2Map.center(of: "2440"))
    ]
    private static let meetingPoint = SUBLevel2Map.center(of: "2430")

    @Environment(\.dismiss) private var dismiss
    @State private var selectedStation: POCStation?
    @State private var completedStationIDs: Set<String> = ["reactor-a"]
    @State private var ownLastCheckpoint = POCCheckpoint(
        stationID: "reactor-a",
        stationName: "Reactor A",
        roomLabel: "SUB 2310 · Dining",
        verifiedAt: Date().addingTimeInterval(-420)
    )

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.025, green: 0.04, blue: 0.055)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PHYSICAL MAP")
                                .font(.caption.weight(.bold))
                                .tracking(2)
                                .foregroundStyle(.cyan)

                            Text("SFU Student Union Building · Level 2")
                                .font(.title2.bold())

                            Text("Bundled offline room geometry · SUB / 2000")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        POCFloorPlan(
                            rooms: Self.rooms,
                            stations: Self.stations,
                            meetingPoint: Self.meetingPoint,
                            completedStationIDs: completedStationIDs,
                            selectedStation: selectedStation,
                            ownLastCheckpoint: ownLastCheckpoint,
                            onSelectStation: { selectedStation = $0 }
                        )
                        .frame(height: 430)

                        Label("Your icon marks the last verified checkpoint, not live indoor position.", systemImage: "clock.badge.checkmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Label("Room geometry from SFU Companion by Akki Singh; underlying data from Simon Fraser University.", systemImage: "info.circle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        checkpointCard

                        VStack(alignment: .leading, spacing: 10) {
                            Text("ASSIGNED TASKS")
                                .font(.caption.weight(.bold))
                                .tracking(1.5)
                                .foregroundStyle(.secondary)

                            ForEach(Self.stations) { station in
                                taskRow(station)
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Map POC")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Close", systemImage: "xmark")
                    }
                    .accessibilityLabel("Close physical map")
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $selectedStation) { station in
            POCStationDetailView(
                station: station,
                isCompleted: completedStationIDs.contains(station.id),
                onVerifyCompletion: {
                    completedStationIDs.insert(station.id)
                    ownLastCheckpoint = POCCheckpoint(
                        stationID: station.id,
                        stationName: station.displayName,
                        roomLabel: station.roomLabel,
                        verifiedAt: .now
                    )
                }
            )
            .presentationDetents([.medium, .large])
        }
    }

    private var checkpointCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.fill")
                .foregroundStyle(.cyan)
                .frame(width: 34, height: 34)
                .background(.cyan.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("YOUR LAST VERIFIED CHECKPOINT")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text("\(ownLastCheckpoint.stationName) · \(ownLastCheckpoint.roomLabel)")
                    .font(.subheadline.weight(.semibold))
                Text(ownLastCheckpoint.verifiedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private func taskRow(_ station: POCStation) -> some View {
        let isCompleted = completedStationIDs.contains(station.id)

        return Button {
            selectedStation = station
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCompleted ? .green : .orange)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(station.displayName)
                        .font(.body.weight(.semibold))
                    Text("\(station.roomLabel) · Level 2 · \(station.taskType)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(station.displayName), \(station.roomLabel), Level 2, \(isCompleted ? "completed" : "assigned")")
    }
}

private struct POCFloorPlan: View {
    let rooms: [POCRoom]
    let stations: [POCStation]
    let meetingPoint: CGPoint
    let completedStationIDs: Set<String>
    let selectedStation: POCStation?
    let ownLastCheckpoint: POCCheckpoint
    let onSelectStation: (POCStation) -> Void

    var body: some View {
        GeometryReader { geometry in
            let projection = POCMapProjection(bounds: POCMapBounds.covering(rooms), size: geometry.size)

            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(red: 0.06, green: 0.09, blue: 0.11))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(.cyan.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    }

                Canvas { context, _ in
                    for room in rooms {
                        let isHighlighted = selectedStation?.roomID == room.roomID
                        let isCorridor = room.roomType.localizedCaseInsensitiveContains("corridor")
                        let path = room.path(using: projection)
                        let fill = isHighlighted
                            ? Color.orange.opacity(0.42)
                            : isCorridor ? Color.cyan.opacity(0.10) : Color.white.opacity(0.12)
                        let stroke = isHighlighted ? Color.orange : Color.white.opacity(0.34)

                        context.fill(path, with: .color(fill))
                        context.stroke(path, with: .color(stroke), lineWidth: isHighlighted ? 2.5 : 0.8)
                    }
                }

                ForEach(rooms.filter(shouldShowLabel)) { room in
                    Text(room.mapLabel)
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.65)
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(width: 54)
                        .position(projection.point(room.center))
                }

                ForEach(stations) { station in
                    let isCompleted = completedStationIDs.contains(station.id)

                    Button {
                        onSelectStation(station)
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: isCompleted ? "checkmark" : "wrench.and.screwdriver.fill")
                                .font(.caption.weight(.black))
                                .foregroundStyle(.black)
                                .frame(width: 32, height: 32)
                                .background(isCompleted ? Color.green : Color.orange, in: Circle())
                                .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 2))
                                .shadow(color: (isCompleted ? Color.green : Color.orange).opacity(0.45), radius: 7)

                            Text(station.roomID)
                                .font(.system(size: 8, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.black.opacity(0.76), in: Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                    .position(projection.point(station.position))
                    .accessibilityLabel("\(station.displayName) station, \(station.roomLabel), \(isCompleted ? "completed" : "assigned")")
                }

                VStack(spacing: 2) {
                    Image(systemName: "megaphone.fill")
                    Text("MEETING")
                        .font(.system(size: 8, weight: .black))
                }
                .foregroundStyle(.white)
                .padding(8)
                .background(.red, in: Circle())
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .position(projection.point(meetingPoint))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Emergency meeting point, SUB 2430 public study area, Level 2")

                if let checkpointStation = stations.first(where: { $0.id == ownLastCheckpoint.stationID }) {
                    VStack(spacing: 0) {
                        Image("PlayerMarker")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 58, height: 58)
                            .shadow(color: .cyan.opacity(0.75), radius: 8)

                        Text("YOU")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.cyan, in: Capsule())
                    }
                    .position(playerMarkerPosition(for: checkpointStation, projection: projection))
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("map.ownCheckpoint")
                    .accessibilityLabel("You, last verified at \(ownLastCheckpoint.stationName), \(ownLastCheckpoint.roomLabel), \(ownLastCheckpoint.verifiedAt.formatted(date: .omitted, time: .shortened))")
                }
            }
            .padding(4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Simon Fraser University Student Union Building Level 2 floor map")
    }

    private func shouldShowLabel(_ room: POCRoom) -> Bool {
        room.priority == 30
            && room.roomID != "2430"
            && !stations.contains(where: { $0.roomID == room.roomID })
    }

    private func playerMarkerPosition(for station: POCStation, projection: POCMapProjection) -> CGPoint {
        let stationPoint = projection.point(station.position)
        return CGPoint(x: stationPoint.x + 31, y: stationPoint.y - 34)
    }
}

private struct POCStationDetailView: View {
    let station: POCStation
    let isCompleted: Bool
    let onVerifyCompletion: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Station") {
                    LabeledContent("Name", value: station.displayName)
                    LabeledContent("Task", value: station.taskType)
                    LabeledContent("Room", value: station.roomLabel)
                    LabeledContent("Floor", value: "SFU SUB · Level 2")
                    LabeledContent("Station ID", value: station.id)
                }

                Section("Checkpoint route") {
                    Text("/game/ABCD/station/\(station.id)")
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }

                Section {
                    Button(isCompleted ? "Verified complete" : "Simulate server verification") {
                        onVerifyCompletion()
                        dismiss()
                    }
                    .disabled(isCompleted)
                } footer: {
                    Text("POC only: completion is simulated locally. Production state remains server-authoritative.")
                }
            }
            .navigationTitle(station.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct POCRoom: Identifiable {
    let id: String
    let label: String
    let roomID: String
    let roomType: String
    let priority: Int
    let rings: [[CGPoint]]
    let center: CGPoint

    var mapLabel: String {
        label.hasPrefix("SUB ") ? roomID : "\(roomID)\n\(label)"
    }

    func path(using projection: POCMapProjection) -> Path {
        var path = Path()

        for ring in rings {
            guard let first = ring.first else { continue }
            path.move(to: projection.point(first))
            for coordinate in ring.dropFirst() {
                path.addLine(to: projection.point(coordinate))
            }
            path.closeSubpath()
        }

        return path
    }
}

private struct POCMapBounds {
    let minX: CGFloat
    let maxX: CGFloat
    let minY: CGFloat
    let maxY: CGFloat

    static func covering(_ rooms: [POCRoom]) -> POCMapBounds {
        let coordinates = rooms.flatMap(\.rings).flatMap { $0 }
        guard let first = coordinates.first else {
            return POCMapBounds(minX: -122.918639, maxX: -122.917862, minY: 49.278239, maxY: 49.278905)
        }

        return coordinates.dropFirst().reduce(
            POCMapBounds(minX: first.x, maxX: first.x, minY: first.y, maxY: first.y)
        ) { bounds, coordinate in
            POCMapBounds(
                minX: min(bounds.minX, coordinate.x),
                maxX: max(bounds.maxX, coordinate.x),
                minY: min(bounds.minY, coordinate.y),
                maxY: max(bounds.maxY, coordinate.y)
            )
        }
    }
}

private struct POCMapProjection {
    private let bounds: POCMapBounds
    private let longitudeCorrection: CGFloat
    private let scale: CGFloat
    private let origin: CGPoint

    init(bounds: POCMapBounds, size: CGSize) {
        self.bounds = bounds

        let middleLatitude = (bounds.minY + bounds.maxY) / 2
        longitudeCorrection = CGFloat(cos(Double(middleLatitude) * .pi / 180))

        let horizontalSpan = max((bounds.maxX - bounds.minX) * longitudeCorrection, 0.000_001)
        let verticalSpan = max(bounds.maxY - bounds.minY, 0.000_001)
        let availableWidth = max(size.width - 28, 1)
        let availableHeight = max(size.height - 28, 1)
        scale = min(availableWidth / horizontalSpan, availableHeight / verticalSpan)

        let renderedWidth = horizontalSpan * scale
        let renderedHeight = verticalSpan * scale
        origin = CGPoint(
            x: (size.width - renderedWidth) / 2,
            y: (size.height - renderedHeight) / 2
        )
    }

    func point(_ coordinate: CGPoint) -> CGPoint {
        CGPoint(
            x: origin.x + ((coordinate.x - bounds.minX) * longitudeCorrection * scale),
            y: origin.y + ((bounds.maxY - coordinate.y) * scale)
        )
    }
}

private enum SUBLevel2Map {
    static let rooms: [POCRoom] = loadRooms()

    static func center(of roomID: String) -> CGPoint {
        rooms.first(where: { $0.roomID == roomID })?.center
            ?? CGPoint(x: -122.91825, y: 49.27855)
    }

    private static func loadRooms() -> [POCRoom] {
        guard let asset = NSDataAsset(name: "SUBLevel2Map") else {
            assertionFailure("Missing bundled SUB level 2 map data")
            return []
        }

        do {
            let collection = try JSONDecoder().decode(SFUGeoJSONFeatureCollection.self, from: asset.data)
            return collection.features.compactMap { feature in
                let rings = feature.geometry.coordinates.map { ring in
                    ring.compactMap { coordinate -> CGPoint? in
                        guard coordinate.count >= 2 else { return nil }
                        return CGPoint(x: coordinate[0], y: coordinate[1])
                    }
                }

                guard let exteriorRing = rings.first, exteriorRing.count >= 3 else { return nil }

                return POCRoom(
                    id: feature.id,
                    label: feature.properties.name,
                    roomID: feature.properties.roomID,
                    roomType: feature.properties.roomType,
                    priority: feature.properties.priority,
                    rings: rings,
                    center: polygonCenter(exteriorRing)
                )
            }
        } catch {
            assertionFailure("Unable to decode SUB level 2 map data: \(error)")
            return []
        }
    }

    private static func polygonCenter(_ ring: [CGPoint]) -> CGPoint {
        guard let reference = ring.first else { return .zero }

        var crossSum: CGFloat = 0
        var longitudeSum: CGFloat = 0
        var latitudeSum: CGFloat = 0

        for index in ring.indices {
            let nextIndex = ring.index(after: index) == ring.endIndex ? ring.startIndex : ring.index(after: index)
            let current = CGPoint(x: ring[index].x - reference.x, y: ring[index].y - reference.y)
            let next = CGPoint(x: ring[nextIndex].x - reference.x, y: ring[nextIndex].y - reference.y)
            let cross = (current.x * next.y) - (next.x * current.y)
            crossSum += cross
            longitudeSum += (current.x + next.x) * cross
            latitudeSum += (current.y + next.y) * cross
        }

        guard abs(crossSum) > .ulpOfOne else {
            let count = CGFloat(ring.count)
            return CGPoint(
                x: ring.reduce(0) { $0 + $1.x } / count,
                y: ring.reduce(0) { $0 + $1.y } / count
            )
        }

        return CGPoint(
            x: reference.x + (longitudeSum / (3 * crossSum)),
            y: reference.y + (latitudeSum / (3 * crossSum))
        )
    }
}

private struct SFUGeoJSONFeatureCollection: Decodable {
    let features: [SFUGeoJSONFeature]
}

private struct SFUGeoJSONFeature: Decodable {
    let id: String
    let properties: SFUGeoJSONProperties
    let geometry: SFUGeoJSONGeometry
}

private struct SFUGeoJSONProperties: Decodable {
    let name: String
    let roomID: String
    let roomType: String
    let priority: Int

    enum CodingKeys: String, CodingKey {
        case name
        case roomID = "roomId"
        case roomType
        case priority
    }
}

private struct SFUGeoJSONGeometry: Decodable {
    let coordinates: [[[Double]]]
}

private struct POCStation: Identifiable {
    let id: String
    let displayName: String
    let taskType: String
    let roomID: String
    let roomLabel: String
    let position: CGPoint
}

private struct POCCheckpoint {
    let stationID: String
    let stationName: String
    let roomLabel: String
    let verifiedAt: Date
}

#Preview {
    ContentView()
}
