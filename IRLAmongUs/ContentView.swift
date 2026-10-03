import AVFoundation
import SwiftUI

struct ContentView: View {
    private static let referenceSize = CGSize(width: 828, height: 1792)
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
    @State private var isShowingLocalLobby = false
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

            if isShowingLocalLobby {
                LocalLobbyView(stars: Self.stars, buttonAudio: buttonAudio) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isShowingLocalLobby = false
                    }
                }
                .transition(.opacity)
            } else {
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

                LoopingCrewmate(scale: scale, origin: origin)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .allowsHitTesting(false)

                ForEach(Self.hotspots) { hotspot in
                    Button {
                        buttonAudio.play()
                        if hotspot.title == "Local" {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isShowingLocalLobby = true
                            }
                        } else {
                            selectedHotspot = hotspot
                        }
                    } label: {
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(
                                width: hotspot.frame.width * scale,
                                height: hotspot.frame.height * scale
                            )
                    }
                    .buttonStyle(GameMenuButtonStyle())
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
                .transition(.opacity)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .onAppear {
            themeAudio.play()
        }
        .alert(item: $selectedHotspot) { hotspot in
            Alert(
                title: Text(hotspot.title),
                message: Text(hotspot.message),
                dismissButton: .default(Text("Back"))
            )
        }
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
    @State private var isShowingGameLobby = false

    var body: some View {
        Group {
            if isShowingGameLobby {
                GameLobbyView(stars: stars, buttonAudio: buttonAudio) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingGameLobby = false
                    }
                }
                .transition(.opacity)
            } else {
                localGamePicker
                    .transition(.opacity)
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
                    .allowsHitTesting(false)

                VStack(spacing: 16) {
                    playerBar

                    hostHeader

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Create")
                            .font(.system(size: 20, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))

                        HStack(spacing: 12) {
                            lobbyButton("Classic") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isShowingGameLobby = true
                                }
                            }

                            lobbyButton("Hide n Seek") {
                                showLobbyMessage(
                                    title: "Hide n Seek",
                                    message: "A Hide n Seek local lobby is ready to be created."
                                )
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Available Games")
                            .font(.system(size: 19, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))

                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(.white, lineWidth: 3)

                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.white.opacity(0.85), lineWidth: 1.5)
                                .padding(6)

                            VStack(spacing: 10) {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .font(.system(size: 28, weight: .light))
                                Text("Searching for nearby games…")
                                    .font(.system(size: 15, design: .rounded))
                            }
                            .foregroundStyle(.white.opacity(0.35))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Available Games")
                        .accessibilityValue("Searching for nearby games")
                    }
                    .frame(maxHeight: .infinity)

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
        .background(Color.black)
        .alert(item: $lobbyAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("Back"))
            )
        }
    }

    private var playerBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.black.opacity(0.7))
                .frame(width: 42, height: 42)
                .background(Color(white: 0.48), in: RoundedRectangle(cornerRadius: 4))

            Circle()
                .fill(Color(red: 0.05, green: 1, blue: 0.38))
                .frame(width: 22, height: 22)
                .shadow(color: Color.green.opacity(0.9), radius: 9)

            Text("XXXXXXXXXX")
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 6)

            Button {
                buttonAudio.play()
                showLobbyMessage(title: "Friends", message: "Your local friends list is empty.")
            } label: {
                Text("FRIENDS")
                    .font(.system(size: 16, weight: .light, design: .rounded))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(LobbyFilledButtonStyle())
            .frame(width: 105, height: 42)
        }
        .padding(7)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.14))
                .shadow(color: Color(red: 0, green: 0.8, blue: 0.55).opacity(0.22), radius: 8)
        )
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
    }

    private func showLobbyMessage(title: String, message: String) {
        lobbyAlert = LobbyAlert(title: title, message: message)
    }
}

private struct GameLobbyView: View {
    let stars: [Star]
    let buttonAudio: ButtonPressAudioPlayer
    let onLeave: () -> Void

    @State private var playerCount = 1
    @State private var isPrivate = true
    @State private var lobbyAlert: LobbyAlert?

    var body: some View {
        GeometryReader { geometry in
            let scale = max(geometry.size.width / 828, geometry.size.height / 1792)

            ZStack {
                Color.black

                TwinklingStarfield(stars: stars, scale: scale)
                    .frame(width: 828 * scale, height: 1792 * scale)
                    .allowsHitTesting(false)

                VStack(spacing: 14) {
                    lobbyTopBar

                    ZStack(alignment: .bottomLeading) {
                        WaitingRoomScene()
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(.white.opacity(0.75), lineWidth: 3)
                            )

                        Text("Waiting for players…")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))
                            .padding(.horizontal, 15)
                            .padding(.vertical, 9)
                            .background(.black.opacity(0.72), in: Capsule())
                            .padding(16)
                    }
                    .frame(maxHeight: .infinity)

                    HStack(spacing: 12) {
                        lobbyCode
                        playersCard
                    }

                    HStack(spacing: 12) {
                        Button {
                            buttonAudio.play()
                            lobbyAlert = LobbyAlert(
                                title: "Customize",
                                message: "Color, hats, pets, and name customization will live here."
                            )
                        } label: {
                            Label("CUSTOMIZE", systemImage: "tshirt.fill")
                                .frame(maxWidth: .infinity, minHeight: 54)
                        }
                        .buttonStyle(LobbyOutlineButtonStyle())

                        Button {
                            buttonAudio.play()
                            lobbyAlert = LobbyAlert(
                                title: "Need more players",
                                message: "Invite at least three more crewmates before starting the game."
                            )
                        } label: {
                            Text("START")
                                .frame(maxWidth: .infinity, minHeight: 54)
                        }
                        .buttonStyle(LobbyStartButtonStyle())
                    }

                    Button {
                        buttonAudio.play()
                        onLeave()
                    } label: {
                        Text("Leave Game")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
        }
        .background(Color.black)
        .alert(item: $lobbyAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var lobbyTopBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("THE SKELD")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Text("GAME LOBBY")
                    .font(.system(size: 31, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                buttonAudio.play()
                isPrivate.toggle()
            } label: {
                Image(systemName: isPrivate ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(LobbyCircleButtonStyle())
            .accessibilityLabel(isPrivate ? "Private lobby" : "Public lobby")
        }
    }

    private var lobbyCode: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("CODE")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
            Text("IRLUS")
                .font(.system(size: 30, weight: .bold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(.white)
            Text(isPrivate ? "Private • share with friends" : "Public • open to join")
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
            Text("\(playerCount) / 15")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Stepper("", value: $playerCount, in: 1...15)
                .labelsHidden()
                .tint(.mint)
        }
        .frame(width: 132, height: 105)
        .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.35), lineWidth: 1.5))
    }
}

private struct WaitingRoomScene: View {
    var body: some View {
        GeometryReader { geometry in
            let unit = min(geometry.size.width / 360, geometry.size.height / 470)

            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.09, green: 0.15, blue: 0.23), Color(red: 0.02, green: 0.04, blue: 0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 0) {
                    HStack(spacing: 22 * unit) {
                        wallLight
                        Spacer()
                        wallLight
                    }
                    .padding(.horizontal, 32 * unit)
                    .padding(.top, 24 * unit)

                    Spacer()
                }

                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height * 0.72))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height * 0.62))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(Color(red: 0.17, green: 0.22, blue: 0.29))

                ForEach(0..<5, id: \.self) { index in
                    Rectangle()
                        .fill(.black.opacity(0.25))
                        .frame(width: 2)
                        .rotationEffect(.degrees(-30))
                        .offset(x: CGFloat(index - 2) * 92 * unit, y: 110 * unit)
                }

                VStack {
                    Spacer()
                    HStack(spacing: 44 * unit) {
                        LobbyCrewmate(color: .red)
                        LobbyLaptop()
                        LobbyCrewmate(color: Color(red: 0.1, green: 0.82, blue: 0.92))
                            .opacity(0.18)
                    }
                    .padding(.bottom, 45 * unit)
                }
            }
        }
    }

    private var wallLight: some View {
        Capsule()
            .fill(Color(red: 0.25, green: 0.82, blue: 1))
            .frame(width: 60, height: 7)
            .shadow(color: Color.cyan.opacity(0.9), radius: 10)
    }
}

private struct LobbyCrewmate: View {
    let color: Color

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 25)
                .fill(color)
                .frame(width: 70, height: 94)
                .overlay(RoundedRectangle(cornerRadius: 25).stroke(.black.opacity(0.58), lineWidth: 5))
                .offset(y: 12)

            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: [.white.opacity(0.9), Color(red: 0.22, green: 0.69, blue: 0.86)], startPoint: .top, endPoint: .bottom))
                .frame(width: 49, height: 29)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.black.opacity(0.65), lineWidth: 5))
                .offset(x: 12, y: 25)
        }
        .frame(width: 88, height: 110)
    }
}

private struct LobbyLaptop: View {
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.58, green: 0.66, blue: 0.7))
                .frame(width: 73, height: 55)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(red: 0.25, green: 0.98, blue: 0.54))
                        .padding(7)
                )
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(.black.opacity(0.65), lineWidth: 4))
            Capsule()
                .fill(Color(red: 0.48, green: 0.54, blue: 0.58))
                .frame(width: 95, height: 13)
                .overlay(Capsule().stroke(.black.opacity(0.6), lineWidth: 3))
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

#Preview {
    ContentView()
}
