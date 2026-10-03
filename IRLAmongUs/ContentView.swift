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
    @State private var travelProgress = 0.0

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
                        selectedHotspot = hotspot
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
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .onAppear {
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
