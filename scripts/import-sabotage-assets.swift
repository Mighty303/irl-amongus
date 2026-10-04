// Import the sabotage panels from https://github.com/AlvajoyAsante/among-us-assets (Tasks folder): the reactor
// meltdown hand scanner and its glow bar (unchanged), and the O2 keypad and its sticky note (cropped from the
// KeypadGame atlas, transparent edges trimmed, neighbouring sprites cleared). No redrawing. Also the map arrow
// (Gui folder, unchanged; tinted in the app, yellow for tasks and flashing red in a crisis) and the Varela Round
// font Among Us's text uses (Google Fonts, SIL Open Font License), as a data asset the app registers itself.
// Usage from the repository root: swift scripts/import-sabotage-assets.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let base = "https://raw.githubusercontent.com/AlvajoyAsante/among-us-assets/main/Tasks/"
let folder = URL(fileURLWithPath: "IRLAmongUs/Assets.xcassets/Tasks")

func download(_ file: String) -> CGImage {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent((file as NSString).lastPathComponent)
    let curl = Process()
    curl.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
    curl.arguments = ["-sfL", "-o", url.path, base + file]
    try! curl.run()
    curl.waitUntilExit()
    guard curl.terminationStatus == 0, let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Couldn't load \(file)") }
    return image
}

func save(_ image: CGImage, as name: String) {
    let set = folder.appendingPathComponent("\(name).imageset")
    try! FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
    let destination = CGImageDestinationCreateWithURL(set.appendingPathComponent("\(name).png") as CFURL,
                                                      UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
    let contents = ["images": [["filename": "\(name).png", "idiom": "universal", "scale": "1x"]],
                    "info": ["author": "xcode", "version": 1]] as [String: Any]
    try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
        .write(to: set.appendingPathComponent("Contents.json"))
    print(name, image.width, "x", image.height)
}

/// The sprite connected to `seed` (8-way, inside `region`), alone on a transparent background.
/// `exclude`: a neighbour touching it on the sheet (the note's corner touches the "2" key).
func sprite(_ atlas: CGImage, region: CGRect, seed: (Int, Int), exclude: CGRect = .null) -> CGImage {
    let width = atlas.width, height = atlas.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let context = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(atlas, in: CGRect(x: 0, y: 0, width: width, height: height))
    func opaque(_ x: Int, _ y: Int) -> Bool { bytes[(y * width + x) * 4 + 3] > 8 }
    var keep = Set([seed.1 * width + seed.0])
    var stack = [seed]
    while let (x, y) = stack.popLast() {
        for dy in -1...1 { for dx in -1...1 {
            let nx = x + dx, ny = y + dy
            let point = CGPoint(x: nx, y: ny)
            guard region.contains(point), !exclude.contains(point), opaque(nx, ny), keep.insert(ny * width + nx).inserted else { continue }
            stack.append((nx, ny))
        } }
    }
    let xs = keep.map { $0 % width }, ys = keep.map { $0 / width }
    let minX = xs.min()!, minY = ys.min()!, w = xs.max()! - minX + 1, h = ys.max()! - minY + 1
    var out = [UInt8](repeating: 0, count: w * h * 4)
    for index in keep {
        let x = index % width - minX, y = index / width - minY
        for c in 0..<4 { out[(y * w + x) * 4 + c] = bytes[index * 4 + c] }
    }
    return CGContext(data: &out, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                     space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
}

save(download("reactorMeltdown_handprintBase-sharedassets0.assets-124.png"), as: "SabotageReactorHand")
save(download("reactorMeltdown_glowBar-sharedassets0.assets-209.png"), as: "SabotageReactorGlow")
let keypad = download("KeypadGame-sharedassets0.assets-148.png")
save(sprite(keypad, region: CGRect(x: 0, y: 0, width: 376, height: 503), seed: (20, 250)), as: "SabotageKeypad")
save(sprite(keypad, region: CGRect(x: 0, y: 507, width: 250, height: 190), seed: (120, 600),
            exclude: CGRect(x: 196, y: 500, width: 60, height: 96)), as: "SabotageKeypadNote")

save(download("../Gui/Arrow-sharedassets0.assets-197.png"), as: "MapArrow")

let fontFolder = URL(fileURLWithPath: "IRLAmongUs/Assets.xcassets/FontVarelaRound.dataset")
try! FileManager.default.createDirectory(at: fontFolder, withIntermediateDirectories: true)
let curl = Process()
curl.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
curl.arguments = ["-sfL", "-o", fontFolder.appendingPathComponent("VarelaRound-Regular.ttf").path,
                  "https://github.com/google/fonts/raw/main/ofl/varelaround/VarelaRound-Regular.ttf"]
try! curl.run()
curl.waitUntilExit()
precondition(curl.terminationStatus == 0, "Couldn't download Varela Round")
try! JSONSerialization.data(withJSONObject: ["data": [["filename": "VarelaRound-Regular.ttf", "idiom": "universal"]],
                                            "info": ["author": "xcode", "version": 1]] as [String: Any],
                            options: [.prettyPrinted, .sortedKeys])
    .write(to: fontFolder.appendingPathComponent("Contents.json"))
print("FontVarelaRound")
