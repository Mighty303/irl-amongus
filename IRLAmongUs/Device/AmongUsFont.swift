import CoreText
import SwiftUI
import UIKit

/// Varela Round, the font Among Us's text uses (Google Fonts, SIL Open Font License). It's a data asset that
/// registers itself on first use, so it needs no Info.plist entry.
enum AmongUsFont {
    static let name = "VarelaRound-Regular"
    @MainActor private static var registered = false

    @MainActor static func font(size: CGFloat) -> Font {
        register()
        return .custom(name, size: size)
    }

    @MainActor private static func register() {
        guard !registered else { return }
        registered = true
        guard let data = NSDataAsset(name: "FontVarelaRound")?.data, let provider = CGDataProvider(data: data as CFData),
              let font = CGFont(provider) else { return }
        CTFontManagerRegisterGraphicsFont(font, nil)
    }
}

/// Text with Among Us's font and its black outline, e.g. the red crisis text over the map.
struct AmongUsText: View {
    let text: String
    var size: CGFloat = 20
    var color: Color = .white

    init(_ text: String, size: CGFloat = 20, color: Color = .white) {
        self.text = text
        self.size = size
        self.color = color
    }

    var body: some View {
        let outline = max(1.5, size / 12)
        Text(text)
            .font(AmongUsFont.font(size: size))
            .foregroundStyle(color)
            .shadow(color: .black, radius: 0, x: outline, y: outline)
            .shadow(color: .black, radius: 0, x: -outline, y: -outline)
            .shadow(color: .black, radius: 0, x: outline, y: -outline)
            .shadow(color: .black, radius: 0, x: -outline, y: outline)
    }
}
