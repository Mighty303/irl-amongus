import SwiftUI

/// Security, like Among Us: a grid of every other player's front camera, for the living right after
/// scanning the Security sign. (Dead players have their own Spectate view.) Frames arrive a few times a
/// second (it's choppy, like the real cams); a phone busy scanning a sign shows static until it's done.
struct SecurityCamsView: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let close: () -> Void

    private var subjects: [PlayerView] {
        state.players.filter { $0.id != state.me.id && $0.isBot != true }
    }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            let columns = subjects.count <= 1 ? 1 : landscape ? min(4, max(2, Int(ceil(Double(subjects.count) / 2)))) : 2
            ZStack {
                Color.black.opacity(0.92).ignoresSafeArea()
                VStack(spacing: 10) {
                    header
                    if subjects.isEmpty {
                        Spacer()
                        Text("No other players' cameras yet.")
                            .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
                                ForEach(subjects) { player in
                                    CamTile(player: player).aspectRatio(4 / 3, contentMode: .fit)
                                }
                            }
                            .padding(2)
                        }
                    }
                }
                .padding(14)
                .background(HUDStyle.panel())
                .overlay(alignment: .topLeading) { HUDCloseButton(action: close) }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
        }
        .task {
            // Watching tells every other phone to start sending its camera.
            if !(await store.watchCams(true)) { close() }
        }
        .onDisappear { Task { await store.watchCams(false) } }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image("SecurityActionIcon").resizable().scaledToFit().frame(width: 30, height: 30)
                .accessibilityHidden(true)
            Text("SECURITY").font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(.white)
            Spacer()
            RecordingTag()
        }
        .padding(.leading, 26)
        .frame(height: 32)
    }
}

/// Blinking red REC, like a security monitor.
struct RecordingTag: View {
    @State private var on = true

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(Color.red).frame(width: 9, height: 9).opacity(on ? 1 : 0.2)
            Text("REC").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(.white)
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { on = false } }
        .accessibilityHidden(true)
    }
}

/// TV static for a camera with no picture.
private struct CamStatic: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.12)) { context in
            Canvas { gc, size in
                var seed = UInt64(context.date.timeIntervalSinceReferenceDate * 1000)
                let cell: CGFloat = 4
                for y in stride(from: 0, to: size.height, by: cell) {
                    for x in stride(from: 0, to: size.width, by: cell) {
                        seed = seed &* 6364136223846793005 &+ 1442695040888963407
                        let v = Double(seed >> 56) / 255
                        gc.fill(Path(CGRect(x: x, y: y, width: cell, height: cell)), with: .color(.white.opacity(v * 0.35)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// One player's camera: their latest frame, with their crewmate and name. Static with "NO SIGNAL" when
/// their phone has never sent a picture, "CAMERA BUSY" when it stopped (scanning a sign).
struct CamTile: View {
    @Environment(GameStore.self) private var store
    let player: PlayerView
    var nameSize: CGFloat = 11

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let feed = store.camFeeds[player.id]
            let live = feed.map { context.date.timeIntervalSince($0.at) < 3 } ?? false
            Color.black
                .overlay {
                    if let feed {
                        Image(uiImage: feed.image).resizable().scaledToFill()
                            .opacity(live ? 1 : 0.35)
                    }
                    if !live { CamStatic() }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.5), lineWidth: 2))
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 4) {
                        if let suit = player.color {
                            Image(suit.lobbyAssetName).resizable().scaledToFit().frame(width: nameSize * 1.7, height: nameSize * 1.7)
                                .opacity(player.alive ? 1 : 0.5)
                        }
                        Text(player.name).font(.system(size: nameSize, weight: .black, design: .rounded)).foregroundStyle(.white)
                    }
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(.black.opacity(0.65), in: Capsule())
                    .padding(6)
                }
                .overlay {
                    if !live {
                        Text(feed == nil ? "NO SIGNAL" : "CAMERA BUSY")
                            .font(.system(size: 12, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.85))
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(player.name)'s camera\(live ? "" : ", no signal")")
        }
    }
}
