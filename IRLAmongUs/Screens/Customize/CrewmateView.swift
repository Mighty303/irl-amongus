import SwiftUI

/// A lobby crewmate in the player's suit color, with their cut-out head (if they added one)
/// covering the visor and its top just above the helmet.
struct CrewmateView<Head: View>: View {
    let color: PlayerColor
    let height: CGFloat
    @ViewBuilder let head: () -> Head

    /// Where the head oval sits, relative to the lobby sprite's width (the sprites are 147×190 px):
    /// over the visor, its top just above the helmet dome.
    static func headFrame(spriteWidth w: CGFloat) -> CGRect {
        let width = w * 0.514
        return CGRect(x: w * 0.416, y: -w * 0.041, width: width, height: width / FaceCrop.aspect)
    }

    var body: some View {
        let width = height * 147 / 190
        let frame = Self.headFrame(spriteWidth: width)
        Image(color.lobbyAssetName)
            .resizable()
            .interpolation(.high)
            .frame(width: width, height: height)
            .overlay(alignment: .topLeading) {
                head()
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)
            }
    }
}

extension CrewmateView where Head == CrewmateFace {
    /// A crewmate wearing the head the server serves at `faceURL` (none when nil).
    init(color: PlayerColor, faceURL: URL?, height: CGFloat) {
        self.init(color: color, height: height) { CrewmateFace(url: faceURL) }
    }
}

/// A player's uploaded head, or nothing while it loads or when they haven't added one.
struct CrewmateFace: View {
    let url: URL?

    private let cache = PlayerFaceCache.shared

    var body: some View {
        Group {
            if let url, let image = cache.images[url] {
                Image(uiImage: image).resizable().interpolation(.high)
            } else { Color.clear }
        }
        .task(id: url) { await cache.load(url) }
    }
}
