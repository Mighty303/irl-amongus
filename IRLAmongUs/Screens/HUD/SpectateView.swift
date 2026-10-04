import SwiftUI

/// Spectate, for dead players: everyone's camera at once (front, or the back camera in AR position mode), filling the screen like a video call
/// in Among Us style. Opened from the Spectate button on a ghost's map.
struct SpectateView: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    let close: () -> Void

    private var subjects: [PlayerView] {
        // The living first, so you can watch the game; other ghosts after.
        state.players.filter { $0.id != state.me.id && $0.isBot != true }
            .sorted { ($0.alive ? 0 : 1, $0.name) < ($1.alive ? 0 : 1, $1.name) }
    }

    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = 8
            let header: CGFloat = 40
            let area = CGSize(width: geo.size.width - 28, height: geo.size.height - 28 - header - gap)
            let layout = Self.grid(count: subjects.count, in: area, gap: gap)
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: gap) {
                    HStack(spacing: 10) {
                        SpectateGlyph(size: 30)
                        Text("SPECTATING").font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(.white)
                        Text("\(subjects.filter(\.alive).count) alive")
                            .font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        RecordingTag()
                    }
                    .padding(.leading, 30)
                    .frame(height: header)

                    if subjects.isEmpty {
                        Spacer()
                        Text("Nobody else to watch yet.")
                            .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                        Spacer()
                    } else {
                        // Every camera on screen at once, as big as they fit (no scrolling).
                        VStack(spacing: gap) {
                            ForEach(0..<layout.rows, id: \.self) { row in
                                HStack(spacing: gap) {
                                    ForEach(subjects.indices.filter { $0 / layout.columns == row }, id: \.self) { i in
                                        CamTile(player: subjects[i], nameSize: 13)
                                            .frame(width: layout.tile.width, height: layout.tile.height)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(14)
                .overlay(alignment: .topLeading) { HUDCloseButton(action: close).padding(.leading, 14).padding(.top, 14) }
            }
        }
        .task { if !(await store.watchCams(true)) { close() } }
        .onDisappear { Task { await store.watchCams(false) } }
        .accessibilityLabel("Spectating everyone's cameras")
    }

    /// Rows and columns that make 4:3 tiles as big as possible in `area`.
    static func grid(count: Int, in area: CGSize, gap: CGFloat) -> (rows: Int, columns: Int, tile: CGSize) {
        guard count > 0, area.width > 0, area.height > 0 else { return (0, 1, .zero) }
        var best = (rows: 1, columns: count, tile: CGSize.zero)
        for columns in 1...count {
            let rows = Int(ceil(Double(count) / Double(columns)))
            let w = (area.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
            let h = (area.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
            let tileW = min(w, h * 4 / 3)
            if tileW > best.tile.width { best = (rows, columns, CGSize(width: tileW, height: tileW * 3 / 4)) }
        }
        return best
    }
}

/// The Spectate mark: a white eye in an outlined circle, drawn to sit with Among Us's action icons.
struct SpectateGlyph: View {
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            Circle().fill(Color(white: 0.12))
            Circle().stroke(.white, lineWidth: size * 0.07)
            Image(systemName: "eye.fill")
                .font(.system(size: size * 0.42, weight: .black))
                .foregroundStyle(.white)
                .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(.black, lineWidth: size * 0.04).padding(-size * 0.04))
        .accessibilityHidden(true)
    }
}

/// The Spectate button on a ghost's map: the glyph with an outlined Among Us label, like the action icons.
struct SpectateButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                SpectateGlyph(size: 46)
                TaskText("SPECTATE", size: 10)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Spectate everyone's cameras")
        .accessibilityIdentifier("hud.spectate")
    }
}
