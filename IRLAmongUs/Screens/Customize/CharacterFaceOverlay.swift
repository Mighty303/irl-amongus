import SwiftUI

/// A head position in the artwork's original pixel coordinates, before aspect fitting or rotation.
struct CharacterFacePlacement: Codable, Equatable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    var rotation: Double = 0
}

struct CharacterFaceOverlay: View {
    let url: URL?
    let sourceSize: CGSize
    let placement: CharacterFacePlacement?

    var body: some View {
        GeometryReader { geometry in
            if let placement {
                let scale = min(geometry.size.width / sourceSize.width, geometry.size.height / sourceSize.height)
                CrewmateFace(url: url)
                    .frame(width: placement.width * scale, height: placement.width * scale / FaceCrop.aspect)
                    .rotationEffect(.degrees(placement.rotation))
                    .position(x: (geometry.size.width - sourceSize.width * scale) / 2 + placement.x * scale,
                              y: (geometry.size.height - sourceSize.height * scale) / 2 + placement.y * scale)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Decorative menu art represents this phone's selected character.
struct MenuCrewmateArtwork: View {
    @Environment(GameStore.self) private var store
    var body: some View {
        Image("RedCrewmate").resizable().scaledToFit()
            .overlay {
                CharacterFaceOverlay(url: store.faceURL(store.preferredFaceId), sourceSize: CGSize(width: 1536, height: 1024),
                    placement: CharacterFacePlacement(x: 810, y: 440, width: 290, rotation: 40))
            }
    }
}
