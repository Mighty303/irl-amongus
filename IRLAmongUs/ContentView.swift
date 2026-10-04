import AVFoundation
import SwiftUI
import UIKit

struct ContentView: View {
    private static let audioEnabled = !ProcessInfo.processInfo.arguments.contains("-disableAudio")

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

    @Environment(GameStore.self) private var store
    @State private var selectedHotspot: MenuHotspot?
    @State private var showingAppSettings = false
    @State private var developerDestination: DeveloperDestination?
    @State private var pendingDeveloperDestination: DeveloperDestination?
    @State private var showingDeveloperMenu = ProcessInfo.processInfo.arguments.contains("-showDeveloperMenu")
    @State private var travelProgress = 0.0
    @State private var isShowingLocalLobby = false
    @StateObject private var themeAudio = ThemeAudioPlayer()
    @StateObject private var buttonAudio = ButtonPressAudioPlayer()

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let menuWidth = min(size.width * 0.46, 400)
            let primaryHeight = min(size.height * 0.15, 64)
            let iconSize = min(size.height * 0.12, 48)
            let stars = Self.stars.map {
                Star(x: $0.x / 828 * size.width, y: $0.y / 1792 * size.height,
                     radius: $0.radius * 0.4, phase: $0.phase, speed: $0.speed)
            }
            if isShowingLocalLobby {
                LocalLobbyView(stars: Self.stars, buttonAudio: buttonAudio) {
                    isShowingLocalLobby = false
                    travelProgress = 0
                    DispatchQueue.main.async { travelProgress = 1 }
                }
            } else {
                ZStack {
                    Color.black
                    TwinklingStarfield(stars: stars, scale: 1)
                        .allowsHitTesting(false)
                    Image("RedCrewmate")
                        .resizable().scaledToFit()
                        .frame(width: 150, height: 110)
                        .rotationEffect(.degrees(-12))
                        .position(x: -100 + travelProgress * (size.width + 200), y: size.height * 0.48)
                        .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: travelProgress)
                        .allowsHitTesting(false).accessibilityHidden(true)

                    Text("IRL Among Us")
                        .font(.system(size: min(size.height * 0.17, 72), weight: .ultraLight, design: .rounded))
                        .tracking(2).foregroundStyle(.white.opacity(0.85))
                        .position(x: size.width * 0.56, y: size.height * 0.2)
                        .accessibilityAddTraits(.isHeader)

                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            landscapeMenuButton(Self.hotspots[0], artwork: "LocalEnglish", height: primaryHeight)
                            landscapeMenuButton(Self.hotspots[1], artwork: "OnlineEnglish", height: primaryHeight)
                        }
                        HStack(spacing: 12) {
                            landscapeMenuButton(Self.hotspots[2], artwork: "HowToPlayEnglish", height: primaryHeight * 0.68)
                            landscapeMenuButton(Self.hotspots[3], artwork: "FreeplayEnglish", height: primaryHeight * 0.68)
                        }
                        HStack(spacing: 14) {
                            ForEach([4, 7, 8, 6], id: \.self) { index in
                                landscapeMenuButton(Self.hotspots[index], artwork: Self.hotspots[index].title + "MenuIcon", height: iconSize)
                                    .frame(width: iconSize)
                            }
                        }
                    }
                    .frame(width: menuWidth)
                    .position(x: size.width * 0.56, y: size.height * 0.76)

                    Button {
                        buttonAudio.play()
                        selectedHotspot = Self.hotspots[5]
                    } label: {
                        VStack(spacing: 2) {
                            Image("AccountMenuIcon").resizable().scaledToFit().frame(width: 54, height: 54)
                            Text("ACCOUNT").font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .padding(6).overlay(RoundedRectangle(cornerRadius: 6).stroke(.white, lineWidth: 2))
                    }
                    .foregroundStyle(.white).buttonStyle(.plain)
                    .position(x: 48, y: size.height * 0.25)
                    .accessibilityLabel("Account")

                    Button {
                        buttonAudio.play()
                        themeAudio.toggleMuted()
                    } label: {
                        Image(systemName: themeAudio.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.6), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.45), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .position(x: size.width - 28, y: 30)
                    .accessibilityLabel(themeAudio.isMuted ? "Unmute theme music" : "Mute theme music")
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .background {
#if DEBUG
            ShakeDetectorView {
                guard developerDestination == nil else { return }
                showingDeveloperMenu = true
            }
            .allowsHitTesting(false)
#endif
        }
        .onAppear {
            OrientationDelegate.requestLandscape()
            if Self.audioEnabled {
                themeAudio.play()
            }
            travelProgress = 0
            travelProgress = 1
        }
        .onChange(of: store.session, initial: true) { _, session in
            if session != nil { isShowingLocalLobby = true }
        }
        .onChange(of: store.state?.phase, initial: true) { _, phase in
            if let phase, phase != .LOBBY {
                themeAudio.pause()
            } else if Self.audioEnabled {
                themeAudio.play()
            }
        }
        .onChange(of: store.pendingJoinCode, initial: true) { _, code in
            if code != nil { isShowingLocalLobby = true }
        }
        .sheet(isPresented: $showingAppSettings) { AppSettingsView() }
        .alert(item: $selectedHotspot) { hotspot in
            Alert(
                title: Text(hotspot.title),
                message: Text(hotspot.message),
                dismissButton: .default(Text("Back"))
            )
        }
        .sheet(isPresented: $showingDeveloperMenu, onDismiss: openPendingDeveloperDestination) {
            DeveloperMenuView(onOpenPhysicalMap: {
                pendingDeveloperDestination = .physicalMap
                showingDeveloperMenu = false
            }, onOpenVoting: {
                pendingDeveloperDestination = .voting
                showingDeveloperMenu = false
            }, onOpenRoles: {
                pendingDeveloperDestination = .roles
                showingDeveloperMenu = false
            }, onOpenPOC: { destination in
                pendingDeveloperDestination = .poc(destination)
                showingDeveloperMenu = false
            })
            .presentationDetents([.medium])
        }
        .fullScreenCover(item: $developerDestination, onDismiss: {
            OrientationDelegate.requestLandscape()
            if Self.audioEnabled { themeAudio.play() }
        }) { destination in
            switch destination {
            case .physicalMap: PhysicalMapView()
            case .voting: VotingPOCView()
            case .roles: RoleRevealPOCView()
            case .poc(let destination): POCDestinationView(destination: destination)
            }
        }
    }

    private func landscapeMenuButton(_ hotspot: MenuHotspot, artwork: String, height: CGFloat) -> some View {
        Button {
            buttonAudio.play()
            if hotspot.title == "Local" {
                isShowingLocalLobby = true
            } else if hotspot.title == "Settings" {
                showingAppSettings = true
            } else {
                selectedHotspot = hotspot
            }
        } label: {
            Image(artwork).resizable().scaledToFit()
                .frame(maxWidth: .infinity).frame(height: height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hotspot.title)
        .accessibilityHint("Opens \(hotspot.title)")
    }

    private func openPendingDeveloperDestination() {
        guard let destination = pendingDeveloperDestination else { return }
        pendingDeveloperDestination = nil
        themeAudio.pause()
        developerDestination = destination
    }

}

private struct LoopingCrewmate: View {
    let scale: Double
    let origin: CGPoint

    private let duration = 8.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let progress = elapsed.truncatingRemainder(dividingBy: duration) / duration
            let bob = sin(progress * .pi * 4) * 12

            Image("RedCrewmate")
                .resizable()
                .scaledToFit()
                .frame(width: 245 * scale, height: 175 * scale)
                .rotationEffect(.degrees(-7 + sin(progress * .pi * 4) * 2))
                .position(
                    x: origin.x + (-150 + progress * 1_128) * scale,
                    y: origin.y + (870 + bob) * scale
                )
                .accessibilityHidden(true)
        }
    }
}

private struct LocalLobbyView: View {
    let stars: [Star]
    let buttonAudio: ButtonPressAudioPlayer
    let onBack: () -> Void

    @State private var lobbyAlert: LobbyAlert?
    @Environment(GameStore.self) private var store
    @State private var code = ""
    @State private var scanning = false
    @State private var scannedLobbyPayload: String?
    @State private var showingJoinName = false

    var body: some View {
        Group {
            if store.session != nil {
                GameRootView(lobbyContent: { state in
                    AnyView(GameLobbyView(stars: stars, buttonAudio: buttonAudio, state: state))
                })
            } else {
                localGamePicker
                    .transition(.opacity)
            }
        }
        .onChange(of: store.state?.phase, initial: true) { _, phase in
            if let phase, phase != .LOBBY && phase != .ROLE_REVEAL && phase != .PLAYING {
                OrientationDelegate.requestPortrait()
            } else {
                OrientationDelegate.requestLandscape()
            }
        }
        .onChange(of: store.pendingJoinCode, initial: true) { _, pending in
            if let pending {
                code = pending
                store.pendingJoinCode = nil
                showingJoinName = store.playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
    }

    private var localGamePicker: some View {
        GeometryReader { geometry in
            let referenceSize = CGSize(width: 828, height: 1792)
            let scale = max(
                geometry.size.width / referenceSize.width,
                geometry.size.height / referenceSize.height
            )
            let artworkSize = CGSize(
                width: referenceSize.width * scale,
                height: referenceSize.height * scale
            )
            let origin = CGPoint(
                x: (geometry.size.width - artworkSize.width) / 2,
                y: (geometry.size.height - artworkSize.height) / 2
            )

            ZStack(alignment: .topLeading) {
                Color.black

                TwinklingStarfield(stars: stars, scale: scale)
                    .frame(width: artworkSize.width, height: artworkSize.height)
                    .offset(x: origin.x, y: origin.y)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .allowsHitTesting(false)

                ScrollView {
                VStack(spacing: 24) {
                    hostHeader

                    connectionFields

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Create")
                            .font(.system(size: 20, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))

                        HStack(spacing: 12) {
                            lobbyButton("Classic") {
                                Task { await store.createGame() }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Join a Game")
                            .font(.system(size: 19, design: .rounded))
                        TextField(
                            "Room code",
                            text: $code,
                            prompt: Text("Room code").foregroundStyle(.white.opacity(0.75))
                        )
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 18)
                            .frame(minHeight: 64)
                            .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.white, lineWidth: 3)
                                    .allowsHitTesting(false)
                            }
                            .accessibilityIdentifier("local.roomCode")
                        HStack(spacing: 24) {
                            lobbyButton("Join game") { Task { await store.joinGame(code: code) } }
                                .disabled(!store.canEnterLobby || !GameStore.isValidRoomCode(code))
                            lobbyButton("Scan lobby QR") { scanning = true }
                                .disabled(store.isEnteringLobby)
                        }
                        .padding(.top, 12)
                        Text("Use the same server address as the host, then enter the room code or scan their QR. Nearby game discovery is coming soon.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if store.isEnteringLobby { ProgressView("Connecting…") }
                    }

                    HStack(alignment: .bottom) {
                        Button {
                            buttonAudio.play()
                            onBack()
                        } label: {
                            Text("Back")
                                .font(.system(size: 20, weight: .regular, design: .rounded))
                                .frame(width: 112, height: 50)
                        }
                        .buttonStyle(LobbyOutlineButtonStyle())
                        .accessibilityHint("Returns to the main menu")
                        .disabled(store.isEnteringLobby)

                        Spacer()

                        Text("v1.0 (build 1)")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .background(Color.black)
        .sheet(isPresented: $scanning, onDismiss: {
            guard let payload = scannedLobbyPayload else { return }
            scannedLobbyPayload = nil
            Task { await store.handleLobbyQRCode(payload) }
        }) {
            QRScanSheet(title: "Scan lobby QR") { payload in
                scannedLobbyPayload = payload
                scanning = false
            }
        }
        .sheet(isPresented: $showingJoinName) {
            LobbyJoinNameSheet(code: code)
        }
        .alert("Unable to connect", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .alert(item: $lobbyAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("Back"))
            )
        }
    }

    private var connectionFields: some View {
        @Bindable var store = store
        return VStack(alignment: .leading, spacing: 10) {
            TextField("Display name", text: $store.playerName)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("local.playerName")
        }
        .textFieldStyle(.roundedBorder)
        .disabled(store.isEnteringLobby)
    }

    private var hostHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.22, green: 0.31, blue: 0.48), .black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Image("RedCrewmate")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 94, height: 72)
            }
            .frame(width: 108, height: 108)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("HOST")
                    .font(.system(size: 46, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)

                Rectangle()
                    .fill(.white)
                    .frame(height: 3)
            }

            Spacer(minLength: 0)

            Button {
                buttonAudio.play()
                showLobbyMessage(
                    title: "Local Play",
                    message: "Create a game or select an available game to join players nearby."
                )
            } label: {
                Image(systemName: "questionmark")
                    .font(.system(size: 29, weight: .semibold, design: .rounded))
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(LobbyCircleButtonStyle())
            .accessibilityLabel("Local play help")
        }
    }

    private func lobbyButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            buttonAudio.play()
            action()
        } label: {
            Text(title)
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(LobbyOutlineButtonStyle())
        .disabled(title == "Classic" && !store.canEnterLobby)
    }

    private func showLobbyMessage(title: String, message: String) {
        lobbyAlert = LobbyAlert(title: title, message: message)
    }
}

private struct GameLobbyView: View {
    let stars: [Star]
    let buttonAudio: ButtonPressAudioPlayer
    let state: GameState
    @Environment(GameStore.self) private var store
    @State private var showingSettings = false
    @State private var showingInvite = false
    @State private var showingCustomize = false
    @State private var showingMySigns = false
    @StateObject private var spawningAudio = PlayerSpawningAudioPlayer()
    @State private var knownPlayerIDs: Set<String> = []
    @State private var visiblePlayerIDs: Set<String> = []

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let landscape = size.width > size.height
            let screenStars = stars.map {
                Star(x: $0.x / 828 * size.width, y: $0.y / 1792 * size.height,
                     radius: $0.radius * 0.4, phase: $0.phase, speed: $0.speed)
            }

            ZStack {
                Color.black

                TwinklingStarfield(stars: screenStars, scale: 1)
                    .frame(width: size.width, height: size.height)
                    .allowsHitTesting(false)

                VStack(spacing: 14) {
                    lobbyTopBar

                    if landscape {
                        HStack(spacing: 20) {
                            waitingRoom
                            lobbyControls
                                .frame(width: min(340, size.width * 0.4))
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        waitingRoom
                        lobbyControls
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(width: size.width, height: size.height)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .overlay {
                if showingCustomize {
                    CustomizePanel(state: state) { showingCustomize = false }
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingCustomize)
            .overlay {
                if showingMySigns {
                    MySignsView { showingMySigns = false }
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingMySigns)
        }
        .background(Color.black)
        .onChange(of: Set(state.players.map(\.id)), initial: true) { _, playerIDs in
            let joinedPlayerIDs = playerIDs.subtracting(knownPlayerIDs)
            let departedPlayerIDs = knownPlayerIDs.subtracting(playerIDs)
            knownPlayerIDs = playerIDs

            withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) {
                visiblePlayerIDs.subtract(departedPlayerIDs)
                visiblePlayerIDs.formUnion(joinedPlayerIDs)
            }

            if !joinedPlayerIDs.isEmpty { spawningAudio.play() }
        }
        .sheet(isPresented: $showingSettings) {
            LobbyView(state: store.state ?? state)
        }
        .sheet(isPresented: $showingInvite) {
            VStack(spacing: 16) {
                Text(state.code).font(.largeTitle.monospaced().bold())
                QRCodeImage(payload: QRPayload.join(code: state.code, server: store.serverURLString).string, size: 180)
                Text("Scan to join this game").font(.caption)
                Button("Done") { showingInvite = false }
            }
            .padding()
        }
    }

    private var waitingRoom: some View {
        ZStack(alignment: .bottomLeading) {
            WaitingRoomScene()
            LobbyPlayerStage(players: state.players, visiblePlayerIDs: visiblePlayerIDs)

            VStack(alignment: .leading, spacing: 6) {
                Text(!state.playersMissingSigns.isEmpty ? "Waiting for everyone's signs…"
                     : state.isHost ? "Waiting for players…" : "Waiting for the host to start…")
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(state.players) { player in
                            HStack {
                                Text("\(player.connected ? "●" : "○") \(player.name)\(player.id == state.me.id ? " (you)" : "")\(player.isHost ? " · Host" : "")")
                                Spacer(minLength: 8)
                                signStatus(for: player)
                            }
                            .font(.caption)
                        }
                    }
                }
                .frame(maxHeight: 100)
            }
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, 15)
                .padding(.vertical, 9)
                .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
                .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.75), lineWidth: 3))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("lobby.waitingRoom")
        .overlay(alignment: .bottomTrailing) {
            // The Customize laptop, like the one in the game's lobby.
            Button {
                buttonAudio.play()
                showingCustomize = true
            } label: {
                Image("CustomizeActionIcon").resizable().scaledToFit().frame(width: 72, height: 72)
            }
            .buttonStyle(.plain)
            .padding(8)
            .accessibilityLabel("Customize your crewmate")
        }
    }

    private var lobbyControls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                lobbyCode
                playersCard
            }

            if state.requiredSigns > 0 { mySignsCard }

            HStack(spacing: 12) {
                Button {
                    buttonAudio.play()
                    showingSettings = true
                } label: {
                    Label("SETTINGS", systemImage: "gearshape.fill")
                        .frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(LobbyOutlineButtonStyle())

                Button {
                    buttonAudio.play()
                    Task { await store.perform("start_game") }
                } label: {
                    Text("START")
                        .frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(LobbyStartButtonStyle())
                .disabled(!state.isHost || state.players.count < state.settings.minPlayers
                          || !state.playersMissingSigns.isEmpty || !store.isSynced)
            }

            Text(startCaption)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                buttonAudio.play()
                store.leave()
            } label: {
                Text("Leave Game")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                    .underline()
            }
            .buttonStyle(.plain)
            .padding(.bottom, 4)
        }
    }

    private var startCaption: String {
        let missing = state.playersMissingSigns
        if !missing.isEmpty {
            let names = missing.map { $0.id == state.me.id ? "you" : $0.name }.joined(separator: ", ")
            return "Waiting on \(missing.count) player\(missing.count == 1 ? "" : "s") to add signs (\(names))"
        }
        let base = state.isHost ? "Minimum \(state.settings.minPlayers) players to start" : "The host will start the game"
        return state.gameset.map { "Using saved game “\($0.name)” · \(base)" } ?? base
    }

    @ViewBuilder
    private func signStatus(for player: PlayerView) -> some View {
        let required = state.requiredSigns
        if player.isBot == true {
            Text("bot").foregroundStyle(.white.opacity(0.55))
        } else if required > 0 {
            let count = min(state.signs(addedBy: player.id).count, required)
            Text(count >= required ? "\(count)/\(required) ✓" : "\(count)/\(required)")
                .fontWeight(.heavy)
                .foregroundStyle(count >= required ? Self.signsReady : Self.signsMissing)
        }
    }

    private static let signsReady = Color(red: 0.56, green: 0.84, blue: 0.69)
    private static let signsMissing = Color(red: 0.96, green: 0.78, blue: 0.30)

    /// Every player photographs `requiredSigns` signs before the host can start.
    private var mySignsCard: some View {
        let required = state.requiredSigns
        let count = min(state.mySigns.count, required)
        let done = count >= required
        let accent = done ? Self.signsReady : Self.signsMissing
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("MY SIGNS")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                    (Text("\(count)") + Text("/\(required)").foregroundColor(.white.opacity(0.5)))
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    if done {
                        Text("READY")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(accent)
                    }
                }
                HStack(spacing: 5) {
                    ForEach(0..<required, id: \.self) { index in
                        Capsule().fill(index < count ? accent : Color(white: 0.3)).frame(height: 6)
                    }
                }
            }
            if done {
                Button { buttonAudio.play(); showingMySigns = true } label: {
                    Text("EDIT").font(.system(size: 15, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 16).frame(minHeight: 44)
                }
                .buttonStyle(LobbyOutlineButtonStyle())
            } else {
                Button { buttonAudio.play(); showingMySigns = true } label: {
                    Label("ADD SIGNS", systemImage: "plus")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 14).frame(minHeight: 44)
                }
                .buttonStyle(LobbyFilledButtonStyle())
            }
        }
        .padding(.vertical, 9).padding(.leading, 12).padding(.trailing, 10)
        .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent, lineWidth: 2))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lobby.mySigns")
    }

    private var lobbyTopBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(state.mapId.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Text("GAME LOBBY")
                    .font(.system(size: 31, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                buttonAudio.play()
                showingInvite = true
            } label: {
                Image(systemName: "qrcode")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(LobbyCircleButtonStyle())
            .accessibilityLabel("Share lobby QR")
        }
    }

    private var lobbyCode: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("CODE")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
            Text(state.code)
                .font(.system(size: 30, weight: .bold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(.white)
            Text(state.isHost ? "Share code or QR with friends" : "Waiting for the host")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.35), lineWidth: 1.5))
    }

    private var playersCard: some View {
        VStack(spacing: 5) {
            Text("PLAYERS")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
            Text("\(state.players.count)")
                .accessibilityIdentifier("lobby.playerCount")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            if state.isHost {
                Button("Add bot") { Task { await store.perform("add_bot") } }
            } else {
                Text("Joined").font(.caption)
            }
        }
        .frame(width: 132, height: 105)
        .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.35), lineWidth: 1.5))
    }
}

private struct LobbyPlayerStage: View {
    @Environment(GameStore.self) private var store
    let players: [PlayerView]
    let visiblePlayerIDs: Set<String>

    private static let roomAspectRatio: CGFloat = 1229 / 995
    private static let anchors = [
        CGPoint(x: 0.50, y: 0.54),
        CGPoint(x: 0.59, y: 0.55),
        CGPoint(x: 0.41, y: 0.55),
        CGPoint(x: 0.55, y: 0.63),
        CGPoint(x: 0.46, y: 0.63),
        CGPoint(x: 0.65, y: 0.62),
        CGPoint(x: 0.36, y: 0.62),
        CGPoint(x: 0.63, y: 0.47),
        CGPoint(x: 0.38, y: 0.47),
        CGPoint(x: 0.54, y: 0.45),
        CGPoint(x: 0.46, y: 0.45),
        CGPoint(x: 0.70, y: 0.54)
    ]

    var body: some View {
        GeometryReader { geometry in
            let roomFrame = aspectFitFrame(in: geometry.size)
            let spriteHeight = min(max(roomFrame.height * 0.095, 38), 58)

            ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                if visiblePlayerIDs.contains(player.id) {
                    let anchor = Self.anchors[index % Self.anchors.count]
                    let playerColor = player.color ?? PlayerColor.allCases[index % PlayerColor.allCases.count]

                    VStack(spacing: 2) {
                        ZStack(alignment: .topTrailing) {
                            CrewmateView(color: playerColor, faceURL: store.faceURL(player.faceId), height: spriteHeight)

                            if player.isHost {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.yellow)
                                    .shadow(color: .black, radius: 1)
                            }
                        }

                        Text(player.name)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.72), in: Capsule())
                    }
                    .position(
                        x: roomFrame.minX + roomFrame.width * anchor.x,
                        y: roomFrame.minY + roomFrame.height * anchor.y
                    )
                    .transition(.scale(scale: 0.05, anchor: .bottom).combined(with: .opacity))
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("lobby.playerSprite.\(index)")
                    .accessibilityLabel("\(player.name) \(playerColor.rawValue) player icon\(player.isHost ? ", host" : "")")
                }
            }
        }
        .allowsHitTesting(false)
        .animation(.spring(response: 0.55, dampingFraction: 0.62), value: visiblePlayerIDs)
    }

    private func aspectFitFrame(in size: CGSize) -> CGRect {
        if size.width / size.height > Self.roomAspectRatio {
            let width = size.height * Self.roomAspectRatio
            return CGRect(x: (size.width - width) / 2, y: 0, width: width, height: size.height)
        }

        let height = size.width / Self.roomAspectRatio
        return CGRect(x: 0, y: (size.height - height) / 2, width: size.width, height: height)
    }
}

private struct WaitingRoomScene: View {
    var body: some View {
        GeometryReader { geometry in
            Image("LobbyRoom")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .accessibilityHidden(true)
        }
    }
}

private struct LobbyAlert: Identifiable {
    let title: String
    let message: String

    var id: String { title }
}

private struct LobbyOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? .black : .white)
            .background(configuration.isPressed ? Color.white : Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white, lineWidth: 3)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

private struct LobbyStartButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(configuration.isPressed ? Color.black.opacity(0.75) : .black.opacity(0.55))
            .background(Color(red: 0.52, green: 0.64, blue: 0.62).opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.4), lineWidth: 2))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private struct LobbyFilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.72 : 1))
            .background(
                Color(red: 0.31, green: 0.56, blue: 0.55)
                    .opacity(configuration.isPressed ? 0.72 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct LobbyCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.black)
            .background(.white.opacity(configuration.isPressed ? 0.7 : 0.95), in: Circle())
            .overlay(Circle().stroke(Color(white: 0.55), lineWidth: 3))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

private struct GameMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed {
                    Color(red: 0.28, green: 0.95, blue: 0.32)
                        .opacity(0.72)
                        .blendMode(.screen)
                }
            }
            .overlay {
                if configuration.isPressed {
                    Rectangle()
                        .stroke(Color(red: 0.63, green: 1, blue: 0.68), lineWidth: 2)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
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

private enum DeveloperDestination: Identifiable {
    case physicalMap, voting, roles
    case poc(POCDestination)

    var id: String {
        switch self {
        case .physicalMap: return "physicalMap"
        case .voting: return "voting"
        case .roles: return "roles"
        case .poc(let destination): return "poc.\(destination.rawValue)"
        }
    }
}

private struct DeveloperMenuView: View {
    let onOpenPhysicalMap: () -> Void
    let onOpenVoting: () -> Void
    let onOpenRoles: () -> Void
    let onOpenPOC: (POCDestination) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Screens") {
                    Button(action: onOpenPhysicalMap) {
                        Label("Open Map", systemImage: "map.fill")
                    }
                    .accessibilityIdentifier("developer.openPhysicalMap")

                    Button(action: onOpenVoting) {
                        Label("Open Voting", systemImage: "checkmark.bubble.fill")
                    }
                    .accessibilityIdentifier("developer.openVoting")

                    Button(action: onOpenRoles) {
                        Label("Open Role Reveal", systemImage: "person.fill.questionmark")
                    }
                    .accessibilityIdentifier("developer.openRoles")

                    ForEach(POCDestination.allCases) { destination in
                        Button { onOpenPOC(destination) } label: {
                            Label(destination.title, systemImage: destination.systemImage)
                        }
                        .accessibilityIdentifier("developer.\(destination.rawValue)")
                    }
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

struct PhysicalMapView: View {
    var showsCloseButton = true
    var previewRole: Role? = nil
    var gameState: GameState? = nil

    private var isImpostor: Bool { (gameState?.me.role ?? previewRole) == .impostor }
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
                    .padding(.bottom, isImpostor ? 120 : 24)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isImpostor {
                    MapKillButton(state: gameState)
                        .padding(16)
                }
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCloseButton {
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
        }
        .preferredColorScheme(.dark)
        .onAppear { OrientationDelegate.requestPortrait() }
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

struct POCFloorPlan: View {
    let rooms: [POCRoom]
    let stations: [POCStation]
    let meetingPoint: CGPoint?
    let completedStationIDs: Set<String>
    let selectedStation: POCStation?
    let ownLastCheckpoint: POCCheckpoint
    let onSelectStation: (POCStation) -> Void

    private static let playerZoomScale: CGFloat = 2.2

    @State private var zoomScale: CGFloat = Self.playerZoomScale
    @GestureState private var gestureZoomScale: CGFloat = 1
    @State private var panOffset: CGSize = .zero
    @GestureState private var gesturePanOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            let projection = POCMapProjection(bounds: POCMapBounds.covering(rooms), size: geometry.size)
            let visibleScale = min(max(zoomScale * gestureZoomScale, 1), 4)
            let visibleOffset = CGSize(
                width: panOffset.width + gesturePanOffset.width,
                height: panOffset.height + gesturePanOffset.height
            )

            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(red: 0.06, green: 0.09, blue: 0.11))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(.cyan.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    }

                mapContent(projection: projection, zoomScale: visibleScale)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(visibleScale)
                    .offset(visibleOffset)
                    .contentShape(Rectangle())
                    .highPriorityGesture(panGesture(in: geometry.size))
                    .simultaneousGesture(zoomGesture(in: geometry.size))

                VStack {
                    HStack {
                        Spacer()
                        Button {
                            focusOnPlayer(projection: projection, size: geometry.size)
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(.black.opacity(0.72), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("map.resetViewport")
                        .accessibilityLabel("Focus on player")
                    }

                    Spacer()

                    HStack {
                        Label("Drag to move · Pinch to zoom", systemImage: "hand.draw.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.86))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.7), in: Capsule())
                            .allowsHitTesting(false)
                        Spacer()
                    }
                }
                .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .onAppear {
                focusOnPlayer(projection: projection, size: geometry.size)
            }
            .onChange(of: ownLastCheckpoint.stationID) {
                focusOnPlayer(projection: projection, size: geometry.size)
            }
            .onChange(of: geometry.size) {
                focusOnPlayer(projection: projection, size: geometry.size)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map.floorPlan")
        .accessibilityLabel("Simon Fraser University Student Union Building Level 2 floor map")
        .accessibilityHint("Drag to move the map and pinch to zoom")
    }

    @ViewBuilder
    private func mapContent(projection: POCMapProjection, zoomScale: CGFloat) -> some View {
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
                .scaleEffect(1 / zoomScale)
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
            .scaleEffect(1 / zoomScale)
            .position(projection.point(station.position))
            .accessibilityLabel("\(station.displayName) station, \(station.roomLabel), \(isCompleted ? "completed" : "assigned")")
        }

        if let meetingPoint {
            VStack(spacing: 2) {
                Image(systemName: "megaphone.fill")
                Text("MEETING")
                    .font(.system(size: 8, weight: .black))
            }
            .foregroundStyle(.white)
            .padding(8)
            .background(.red, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .scaleEffect(1 / zoomScale)
            .position(projection.point(meetingPoint))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Emergency meeting point")
        }

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
            // Preserve the accepted size at the default player-focused zoom,
            // while still letting the crewmate grow and shrink with the map.
            .scaleEffect(1 / Self.playerZoomScale)
            .position(playerMarkerPosition(for: checkpointStation, projection: projection))
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("map.ownCheckpoint")
            .accessibilityLabel("You, last verified at \(ownLastCheckpoint.stationName), \(ownLastCheckpoint.roomLabel), \(ownLastCheckpoint.verifiedAt.formatted(date: .omitted, time: .shortened))")
        }
    }

    private func panGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($gesturePanOffset) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                let proposed = CGSize(
                    width: panOffset.width + value.translation.width,
                    height: panOffset.height + value.translation.height
                )
                panOffset = constrainedOffset(proposed, in: size, scale: zoomScale)
            }
    }

    private func zoomGesture(in size: CGSize) -> some Gesture {
        MagnificationGesture()
            .updating($gestureZoomScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                zoomScale = min(max(zoomScale * value, 1), 4)
                panOffset = constrainedOffset(panOffset, in: size, scale: zoomScale)
            }
    }

    private func constrainedOffset(_ proposed: CGSize, in size: CGSize, scale: CGFloat) -> CGSize {
        let horizontalLimit = max(48, (size.width * (scale - 1) / 2) + 36)
        let verticalLimit = max(48, (size.height * (scale - 1) / 2) + 36)

        return CGSize(
            width: min(max(proposed.width, -horizontalLimit), horizontalLimit),
            height: min(max(proposed.height, -verticalLimit), verticalLimit)
        )
    }

    private func focusOnPlayer(projection: POCMapProjection, size: CGSize) {
        guard let station = stations.first(where: { $0.id == ownLastCheckpoint.stationID }) else {
            return
        }

        let playerPosition = playerMarkerPosition(for: station, projection: projection)
        let offset = CGSize(
            width: (size.width / 2 - playerPosition.x) * Self.playerZoomScale,
            height: (size.height / 2 - playerPosition.y) * Self.playerZoomScale
        )

        withAnimation(.snappy) {
            zoomScale = Self.playerZoomScale
            panOffset = constrainedOffset(offset, in: size, scale: Self.playerZoomScale)
        }
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
                    Text("Completion is saved on this device.")
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

struct POCRoom: Identifiable {
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

struct POCMapBounds {
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

struct POCMapProjection {
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

enum SUBLevel2Map {
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

struct POCStation: Identifiable {
    let id: String
    let displayName: String
    let taskType: String
    let roomID: String
    let roomLabel: String
    let position: CGPoint
}

struct POCCheckpoint {
    let stationID: String
    let stationName: String
    let roomLabel: String
    let verifiedAt: Date
}

#Preview {
    ContentView()
}
