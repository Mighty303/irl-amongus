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
    @FocusState private var codeFocused: Bool
    @State private var showingNameEditor = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize


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
            let size = geometry.size
            // Same star mapping as the game lobby, so the two screens match.
            let screenStars = stars.map {
                Star(x: $0.x / 828 * size.width, y: $0.y / 1792 * size.height,
                     radius: $0.radius * 0.4, phase: $0.phase, speed: $0.speed)
            }

            ZStack(alignment: .topLeading) {
                Color.black

                TwinklingStarfield(stars: screenStars, scale: 1)
                    .frame(width: size.width, height: size.height)
                    .allowsHitTesting(false)

                FloatingMenuCrewmate()
                    .frame(width: 120, height: 80)
                    .position(x: size.width * 0.66, y: 46)
                    .allowsHitTesting(false)

                if dynamicTypeSize.isAccessibilitySize {
                    ScrollView {
                        pickerContent(compact: false)
                            .frame(minHeight: size.height - 24)
                            .padding(12)
                    }
                } else {
                    pickerContent(compact: size.height < 340)
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 10)
                }

                if showingNameEditor {
                    LocalPlayerNameEditor { showingNameEditor = false }
                        .transition(.opacity)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .animation(.easeOut(duration: 0.2), value: showingNameEditor)
        }
        // The name popup sits above the keyboard, so the screen behind it stays put.
        .ignoresSafeArea(.keyboard)
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

    // The lobby's look: dark cards with a light border, black buttons with a white border, the teal START.
    private static let cardColor = Color(white: 0.12)
    private static let fieldColor = Color(white: 0.07)
    private static let startColor = Color(red: 0.52, green: 0.64, blue: 0.62)

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Self.cardColor, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.35), lineWidth: 1.5))
    }

    private func pickerContent(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 12) {
            HStack(spacing: 14) {
                Button {
                    buttonAudio.play()
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(LobbyCircleButtonStyle())
                .accessibilityLabel("Back")
                .accessibilityHint("Returns to the main menu")
                VStack(alignment: .leading, spacing: 1) {
                    Text("IRL AMONG US")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("LOCAL")
                        .font(.system(size: compact ? 26 : 31, weight: .light, design: .rounded))
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer()
                Button {
                    buttonAudio.play()
                    showLobbyMessage(
                        title: "Local Play",
                        message: "Create a Classic game and share its room code or QR. To join, enter the host’s code or scan their lobby QR. Everyone uses the hosted game server. Nearby discovery is coming soon."
                    )
                } label: {
                    Image("HelpMenuIcon").resizable().frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Local play help")
            }
            .disabled(store.isEnteringLobby)

            HStack(spacing: 16) {
                crewmateCard(compact: compact)
                    .frame(width: compact ? 190 : 220)
                createCard(compact: compact)
                joinCard(compact: compact)
            }
            .frame(maxHeight: .infinity)

            HStack {
                if store.isEnteringLobby {
                    ProgressView("Connecting…").tint(.white)
                } else {
                    Text("Play together in person")
                }
                Spacer()
                Text("v1.0 (build 1)")
            }
            .font(.system(size: 11, design: .rounded))
            .foregroundStyle(.white.opacity(0.62))
            .frame(minHeight: 14)
        }
        .foregroundStyle(.white)
    }

    private func crewmateCard(compact: Bool) -> some View {
        card {
            VStack(spacing: compact ? 4 : 8) {
                Text("YOUR CREWMATE")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image("LobbyPlayerRed")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(height: compact ? 64 : 92)
                    .accessibilityHidden(true)
                Text(store.playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Enter name" : store.playerName)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityIdentifier("local.username")
                Button {
                    buttonAudio.play()
                    showingNameEditor = true
                } label: {
                    Label("EDIT NAME", systemImage: "pencil")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(LobbyOutlineButtonStyle())
                .accessibilityLabel("Edit name")
                .accessibilityIdentifier("local.editName")
                .disabled(store.isEnteringLobby)
                if !compact {
                    Text("Pick your color and face in the lobby")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private func cardHeader(_ title: String, subtitle: String, @ViewBuilder icon: () -> some View) -> some View {
        HStack(spacing: 12) {
            icon()
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private func createCard(compact: Bool) -> some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                cardHeader("CREATE GAME", subtitle: "Host a lobby, then share its code") {
                    Image("GameModeCrewmate").resizable().frame(width: 52, height: 52).accessibilityHidden(true)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Classic").font(.system(size: 14, weight: .heavy, design: .rounded))
                        Text("Tasks, impostors & meetings")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    Spacer()
                    Image(systemName: "checkmark").font(.system(size: 15, weight: .bold))
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 48)
                .background(Self.fieldColor, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.35), lineWidth: 1.5))
                Spacer(minLength: 0)
                Button {
                    buttonAudio.play()
                    Task { await store.createGame() }
                } label: {
                    Text("CREATE").frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(LobbyStartButtonStyle())
                .accessibilityIdentifier("local.createGame")
                .disabled(!store.canEnterLobby)
            }
        }
    }

    private func joinCard(compact: Bool) -> some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                cardHeader("JOIN GAME", subtitle: "Enter the host’s code or scan it") {
                    Image(systemName: "qrcode")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 52, height: 52)
                        .background(.white.opacity(0.95), in: Circle())
                        .overlay(Circle().stroke(Color(white: 0.55), lineWidth: 3))
                        .accessibilityHidden(true)
                }
                roomCodeBoxes
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    Button {
                        buttonAudio.play()
                        Task { await store.joinGame(code: code) }
                    } label: {
                        Text("JOIN").frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(LobbyStartButtonStyle())
                    .accessibilityIdentifier("local.joinGame")
                    .disabled(!store.canEnterLobby || !GameStore.isValidRoomCode(code))
                    Button {
                        buttonAudio.play()
                        scanning = true
                    } label: {
                        Label("SCAN QR", systemImage: "qrcode.viewfinder")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(LobbyOutlineButtonStyle())
                    .accessibilityLabel("Scan lobby QR")
                    .disabled(store.isEnteringLobby)
                }
            }
        }
    }

    /// Four code boxes like the lobby's CODE card. A clear text field on top takes the typing.
    private var roomCodeBoxes: some View {
        let letters = Array(code)
        return HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
                Text(i < letters.count ? String(letters[i]) : "–")
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundStyle(i < letters.count ? .white : .white.opacity(0.3))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Self.fieldColor, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(i == min(letters.count, 3) && codeFocused ? .white : .white.opacity(0.35), lineWidth: 1.5))
            }
        }
        .overlay {
            TextField("", text: $code)
                .font(.system(size: 40, weight: .bold, design: .monospaced)) // invisible; sized so the field is a 44 pt target
                .foregroundStyle(.clear)
                .tint(.clear)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(.go)
                .focused($codeFocused)
                .onChange(of: code) { _, newValue in
                    let cleaned = String(newValue.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(4))
                    if cleaned != newValue { code = cleaned }
                }
                .onSubmit {
                    guard store.canEnterLobby && GameStore.isValidRoomCode(code) else { return }
                    Task { await store.joinGame(code: code) }
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .accessibilityLabel("Room code")
                .accessibilityIdentifier("local.roomCode")
                .disabled(store.isEnteringLobby)
        }
    }

    private func showLobbyMessage(title: String, message: String) {
        lobbyAlert = LobbyAlert(title: title, message: message)
    }
}

/// The main menu's floating red crewmate, bobbing gently above the Local screen.
private struct FloatingMenuCrewmate: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Image("RedCrewmate")
                .resizable()
                .scaledToFit()
                .rotationEffect(.degrees(-8 + sin(t * 0.8) * 3))
                .offset(y: sin(t * 1.1) * 5)
                .accessibilityHidden(true)
        }
    }
}

/// Edit your display name in the white Among Us style popup, kept near the top so the keyboard
/// doesn't cover it in landscape.
private struct LocalPlayerNameEditor: View {
    @Environment(GameStore.self) private var store
    let close: () -> Void
    @State private var name = ""
    @FocusState private var focused: Bool

    private static let ink = Color(white: 0.106)

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture { close() }
            VStack(alignment: .leading, spacing: 10) {
                Text("Your name")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .padding(.leading, 22)
                TextField("Display name", text: $name)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(save)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 50)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Self.ink, lineWidth: 3))
                    .accessibilityIdentifier("local.playerName")
                Text("Shown above your crewmate · up to 20 characters")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(white: 0.3))
                HStack(spacing: 10) {
                    Button(action: close) {
                        Text("CANCEL")
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Self.ink, lineWidth: 3))
                    }
                    Button(action: save) {
                        Text("SAVE")
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .foregroundStyle(.white)
                            .background(Self.ink, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .accessibilityIdentifier("local.saveName")
                }
                .buttonStyle(.plain)
                .font(.system(size: 15, weight: .black, design: .rounded))
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 16)
            .foregroundStyle(Self.ink)
            .frame(maxWidth: 440)
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Self.ink, lineWidth: 4))
            .overlay(alignment: .topLeading) {
                Button(action: close) {
                    Image("CloseMenuIcon").resizable().frame(width: 40, height: 40)
                }
                .offset(x: -14, y: -14)
                .accessibilityLabel("Close")
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
        }
        .onAppear {
            name = store.playerName
            focused = true
        }
    }

    private func save() {
        store.playerName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        close()
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
    @State private var showingLiveMap = false
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

                VStack(spacing: 10) {
                    lobbyTopBar

                    if landscape {
                        HStack(spacing: 12) {
                            waitingRoom
                            signsPanel
                                .frame(width: min(220, size.width * 0.28))
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        waitingRoom
                        signsPanel.frame(maxHeight: 230)
                    }

                    lobbyDock
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(width: size.width, height: size.height)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .overlay {
                ZStack {
                    if showingCustomize {
                        CustomizePanel(state: state) { showingCustomize = false }
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                }
                .allowsHitTesting(showingCustomize)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingCustomize)
            .overlay {
                ZStack {
                    if showingMySigns {
                        MySignsView { showingMySigns = false }
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                }
                .allowsHitTesting(showingMySigns)
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
        LobbyPlayerStage(state: state, visiblePlayerIDs: visiblePlayerIDs)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            WaitingRoomScene().accessibilityHidden(true).allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.25), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lobby.waitingRoom")
    }

    private var canStart: Bool {
        state.isHost && state.players.count >= state.settings.minPlayers
            && state.playersMissingSigns.isEmpty && store.isSynced
    }

    private var startCaption: String {
        if !store.isSynced { return "Reconnecting…" }
        if !state.playersMissingSigns.isEmpty {
            let count = state.playersMissingSigns.count
            return "Waiting for signs (\(count) player\(count == 1 ? "" : "s"))"
        }
        if !state.isHost { return "Waiting for the host" }
        if state.players.count < state.settings.minPlayers {
            return "Need \(state.settings.minPlayers - state.players.count) more player\(state.settings.minPlayers - state.players.count == 1 ? "" : "s")"
        }
        return "Everyone is ready"
    }

    private var lobbyDock: some View {
        HStack(spacing: 12) {
            Button {
                buttonAudio.play()
                showingCustomize = true
            } label: {
                Label("CUSTOMIZE", systemImage: "person.crop.square")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(LobbyOutlineButtonStyle())
            .accessibilityLabel("Customize your crewmate")

            Button {
                buttonAudio.play()
                showingSettings = true
            } label: {
                Label("SETTINGS", systemImage: "gearshape.fill")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(LobbyOutlineButtonStyle())

            Button {
                buttonAudio.play()
                Task { await store.perform("start_game") }
            } label: {
                VStack(spacing: 2) {
                    Text("START GAME")
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                    Text(startCaption)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 8)
            }
            .buttonStyle(LobbyStartButtonStyle())
            .disabled(!canStart)
            .accessibilityLabel("START")
            .accessibilityValue(startCaption)
        }
        .font(.system(size: 15, weight: .bold, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private static let signsReady = Color(red: 0.56, green: 0.84, blue: 0.69)
    private static let signsMissing = Color(red: 0.96, green: 0.78, blue: 0.30)

    private var signsPanel: some View {
        let required = state.requiredSigns
        let count = min(state.mySigns.count, required)
        let done = count >= required
        return ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MY SIGNS")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                    Text(required > 0 ? "\(count) / \(required) added" : "No signs required")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.bottom, 4)

                if required > 0 {
                    signThumbnails
                    Button { buttonAudio.play(); showingMySigns = true } label: {
                        Label(done ? "VIEW SIGNS" : "ADD SIGN", systemImage: done ? "photo.on.rectangle" : "plus")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(LobbyFilledButtonStyle())
                    .accessibilityLabel(done ? "Edit my signs" : "Add signs")
                }

                Divider().overlay(.white.opacity(0.15))
                Label {
                    Text(state.playersMissingSigns.isEmpty ? "All signs added" : "\(state.playersMissingSigns.count) player\(state.playersMissingSigns.count == 1 ? "" : "s") still adding signs")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                } icon: {
                    Image(systemName: state.playersMissingSigns.isEmpty ? "checkmark.circle.fill" : "person.2.fill")
                        .foregroundStyle(state.playersMissingSigns.isEmpty ? Self.signsReady : Self.signsMissing)
                }
                if let gameset = state.gameset {
                    Text("Saved game: \(gameset.name)")
                        .font(.caption).foregroundStyle(.white.opacity(0.65))
                }
                if state.isHost {
                    Button {
                        buttonAudio.play()
                        Task { await store.perform("add_bot") }
                    } label: {
                        Text("Add bot")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(LobbyOutlineButtonStyle())
                }
            }
            .padding(10)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.06, green: 0.09, blue: 0.11), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lobby.mySigns")
    }

    private var signThumbnails: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(state.mySigns) { sign in
                    ZStack {
                        Color(white: 0.18)
                        if let photoId = sign.photoId, let base = store.serverURL {
                            AsyncImage(url: base.appendingPathComponent("photos/\(photoId).jpg")) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Image(systemName: "photo").foregroundStyle(.white.opacity(0.5))
                            }
                        } else {
                            Image(systemName: "photo").foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.6), lineWidth: 1))
                    .accessibilityLabel(sign.signText ?? sign.name)
                }
                if state.mySigns.count < state.requiredSigns {
                    Button { buttonAudio.play(); showingMySigns = true } label: {
                        Image(systemName: "plus").font(.title3)
                            .frame(width: 44, height: 44)
                            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4])))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add signs")
                }
            }
            .padding(1)
        }
    }

    private var lobbyTopBar: some View {
        HStack(spacing: 10) {
            Button {
                buttonAudio.play()
                store.leave()
            } label: {
                Label("LEAVE", systemImage: "chevron.left")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .padding(.horizontal, 12).frame(height: 44)
            }
            .buttonStyle(LobbyOutlineButtonStyle())
            .accessibilityLabel("Leave Game")

            Text("LOBBY")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 0) {
                Text("ROOM CODE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                Text(state.code)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .accessibilityElement(children: .contain)

            Button {
                buttonAudio.play()
                UIPasteboard.general.string = state.code
            } label: {
                Image(systemName: "doc.on.doc").frame(width: 44, height: 44)
            }
            .buttonStyle(LobbyOutlineButtonStyle())
            .accessibilityLabel("Copy room code")

            Button {
                buttonAudio.play()
                showingLiveMap = true
            } label: {
                Image(systemName: "map.fill")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(LobbyCircleButtonStyle())
            .accessibilityLabel("Live map (testing)")
            .fullScreenCover(isPresented: $showingLiveMap) { LiveMapView() }

            Button {
                buttonAudio.play()
                showingInvite = true
            } label: {
                Label("INVITE", systemImage: "qrcode")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10).frame(height: 44)
            }
            .buttonStyle(LobbyOutlineButtonStyle())
            .accessibilityLabel("Share lobby QR")

            VStack(spacing: 1) {
                Text("\(state.players.count)")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .accessibilityIdentifier("lobby.playerCount")
                Text("PLAYERS").font(.system(size: 9, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.8))
        }
        .lineLimit(1)
    }
}

private struct LobbyPlayerStage: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let visiblePlayerIDs: Set<String>

    var body: some View {
        GeometryReader { geometry in
            let columns = min(max(state.players.count, 1), 6)
            let rows = max(1, Int(ceil(Double(state.players.count) / 6)))
            let spriteHeight = min(58, max(32, geometry.size.height * (rows > 1 ? 0.22 : 0.3)))
            let cellWidth = geometry.size.width * 0.88 / CGFloat(columns)

            ForEach(Array(state.players.enumerated()), id: \.element.id) { index, player in
                if visiblePlayerIDs.contains(player.id) {
                    let playerColor = player.color ?? PlayerColor.allCases[index % PlayerColor.allCases.count]
                    let signs = min(state.signs(addedBy: player.id).count, state.requiredSigns)
                    VStack(spacing: 3) {
                        HStack(spacing: 3) {
                            if player.isHost {
                                Image(systemName: "crown.fill").foregroundStyle(.yellow)
                            }
                            Text(player.name + (player.id == state.me.id ? " (You)" : ""))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 5))

                        CrewmateView(color: playerColor, faceURL: store.faceURL(player.faceId), height: spriteHeight)
                            .opacity(player.connected ? 1 : 0.45)

                        if state.requiredSigns > 0 && player.isBot != true {
                            Text("\(signs)/\(state.requiredSigns) \(signs >= state.requiredSigns ? "✓" : "")")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(signs >= state.requiredSigns ? .green : .yellow)
                                .padding(.horizontal, 4)
                                .background(.black.opacity(0.75), in: Capsule())
                        }
                    }
                    .frame(width: cellWidth - 4)
                    .position(
                        x: geometry.size.width * 0.06 + cellWidth * (CGFloat(index % columns) + 0.5),
                        y: geometry.size.height * (rows == 1 ? 0.62 : 0.43 + CGFloat(index / columns) * 0.35)
                    )
                    .transition(.scale(scale: 0.05, anchor: .bottom).combined(with: .opacity))
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("lobby.playerSprite.\(index)")
                    .accessibilityLabel("\(player.name) \(playerColor.rawValue) player icon\(player.isHost ? ", host" : "")")
                    .accessibilityValue(player.connected ? (player.isBot == true ? "Bot" : "\(signs) of \(state.requiredSigns) signs") : "Disconnected")
                }
            }
        }
        .allowsHitTesting(false)
        .animation(.spring(response: 0.55, dampingFraction: 0.62), value: visiblePlayerIDs)
    }
}

private struct WaitingRoomScene: View {
    var body: some View {
        GeometryReader { geometry in
            // Frame the cabin interior, rather than shrinking the entire ship into the room.
            let width = max(geometry.size.width / 0.64, geometry.size.height * 1229 / 995 / 0.54)
            let height = width * 995 / 1229
            Image("LobbyRoom")
                .resizable()
                .interpolation(.high)
                .frame(width: width, height: height)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2 + height * 0.04)
                .accessibilityHidden(true)
        }
        .clipped()
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
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? Color.black : Color.white.opacity(0.5))
            .background(isEnabled ? Color(red: 0.48, green: 0.87, blue: 0.38) : Color(white: 0.2))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isEnabled ? Color.green : Color.white.opacity(0.25), lineWidth: 2))
            .opacity(configuration.isPressed ? 0.8 : 1)
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
    /// Live positions (testing): estimated positions with their uncertainty circles. When this
    /// includes `isMe`, the YOU marker follows it instead of the last check-in.
    var players: [POCPlayerDot] = []

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

        ForEach(players) { player in
            let center = projection.point(player.position)
            let radius = max(projection.points(meters: player.accuracyM), 3)
            Circle()
                .fill(player.color.opacity(player.faded ? 0.07 : 0.16))
                .overlay(Circle().stroke(player.color.opacity(player.faded ? 0.3 : 0.75), lineWidth: 1 / zoomScale))
                .frame(width: radius * 2, height: radius * 2)
                .position(center)
                .allowsHitTesting(false)
            if !player.isMe {
                VStack(spacing: 1) {
                    Circle()
                        .fill(player.color)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                    Text(player.name)
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.black.opacity(0.76), in: Capsule())
                }
                .opacity(player.faded ? 0.45 : 1)
                .scaleEffect(1 / zoomScale)
                .position(center)
                .allowsHitTesting(false)
                .accessibilityLabel("\(player.name), within about \(Int(player.accuracyM.rounded())) meters")
            }
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

        if let me = players.first(where: \.isMe) {
            ownMarker
                .scaleEffect(1 / Self.playerZoomScale)
                .position(projection.point(me.position))
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("map.ownPosition")
                .accessibilityLabel("You, estimated within about \(Int(me.accuracyM.rounded())) meters")
        } else if let checkpointStation = stations.first(where: { $0.id == ownLastCheckpoint.stationID }) {
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

    /// The YOU crewmate, for the live position.
    private var ownMarker: some View {
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
    }

    private func focusOnPlayer(projection: POCMapProjection, size: CGSize) {
        let playerPosition: CGPoint
        if let me = players.first(where: \.isMe) {
            playerPosition = projection.point(me.position)
        } else if let station = stations.first(where: { $0.id == ownLastCheckpoint.stationID }) {
            playerPosition = playerMarkerPosition(for: station, projection: projection)
        } else {
            return
        }
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

    /// Screen points for a distance on the ground, e.g. an uncertainty radius.
    func points(meters: Double) -> CGFloat {
        CGFloat(meters / 111_320) * scale
    }
}

/// A player's estimated position on the floor plan (live positions, testing).
struct POCPlayerDot: Identifiable {
    let id: String
    let name: String
    let color: Color
    /// x = longitude, y = latitude, like the room geometry.
    let position: CGPoint
    let accuracyM: Double
    let isMe: Bool
    /// No fresh input for a while.
    let faded: Bool
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
