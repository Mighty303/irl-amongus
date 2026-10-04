// Extract the emergency meeting sprites from the BeforeVoting atlas (the body report's sheet).
// Usage from the repository root: swift scripts/import-emergency-meeting-assets.swift
// Each region is cropped, then trimmed to its non-transparent pixels; a sprite with a seed point keeps only
// the pixels connected to it, so neighbouring sprites on the sheet don't leak in. No redrawing.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let source = "https://raw.githubusercontent.com/AlvajoyAsante/among-us-assets/main/Voting/BeforeVoting-sharedassets0.assets-196.png"
let assets = URL(fileURLWithPath: "IRLAmongUs/Assets.xcassets")
// Loose regions (x, y, width, height) on the 948 x 736 sheet; trimming finds the exact edges.
let regions: [(String, CGRect, seed: (x: Int, y: Int)?)] = [
    ("EmergencyMeetingLettering", CGRect(x: 415, y: 428, width: 390, height: 185), nil),
    ("EmergencyMeetingTable", CGRect(x: 0, y: 620, width: 240, height: 116), (100, 705)),
    ("EmergencyMeetingHand", CGRect(x: 215, y: 625, width: 90, height: 60), (255, 655)),
    ("EmergencyMeetingCrewmate", CGRect(x: 740, y: 600, width: 208, height: 136), (800, 680)),
    // The red button on its hazard pad (with its glass lid), for the map's emergency pin.
    ("EmergencyButtonIcon", CGRect(x: 64, y: 641, width: 128, height: 68), nil),
]

let download = Process()
download.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
let atlasURL = FileManager.default.temporaryDirectory.appendingPathComponent("BeforeVoting.png")
download.arguments = ["-sfL", "-o", atlasURL.path, source]
try download.run()
download.waitUntilExit()
guard download.terminationStatus == 0,
      let imageSource = CGImageSourceCreateWithURL(atlasURL as CFURL, nil),
      let atlas = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else { fatalError("Couldn't load \(source)") }

/// Pixels as RGBA bytes, top row first.
func rgba(_ image: CGImage) -> (bytes: [UInt8], width: Int, height: Int) {
    let width = image.width, height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let context = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return (bytes, width, height)
}

let pixels = rgba(atlas)
func opaque(_ x: Int, _ y: Int) -> Bool { pixels.bytes[(y * pixels.width + x) * 4 + 3] > 8 }

for (name, region, seed) in regions {
    // The sprite's pixels: everything opaque in the region, or only what's connected to the seed.
    var keep = Set<Int>()
    if let seed {
        precondition(opaque(seed.x, seed.y), "\(name): seed isn't on the sprite")
        var stack = [(seed.x, seed.y)]
        keep.insert(seed.y * pixels.width + seed.x)
        while let (x, y) = stack.popLast() {
            for dy in -1...1 { for dx in -1...1 {
                let nx = x + dx, ny = y + dy
                guard region.contains(CGPoint(x: nx, y: ny)), opaque(nx, ny),
                      keep.insert(ny * pixels.width + nx).inserted else { continue }
                stack.append((nx, ny))
            } }
        }
    } else {
        for y in Int(region.minY)..<Int(region.maxY) {
            for x in Int(region.minX)..<Int(region.maxX) where opaque(x, y) { keep.insert(y * pixels.width + x) }
        }
    }
    let xs = keep.map { $0 % pixels.width }, ys = keep.map { $0 / pixels.width }
    guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else {
        fatalError("\(name): nothing in \(region)")
    }
    let crop = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    // Copy the kept pixels only (straight from the sheet), everything else transparent.
    let width = Int(crop.width), height = Int(crop.height)
    var out = [UInt8](repeating: 0, count: width * height * 4)
    for index in keep {
        let x = index % pixels.width - minX, y = index / pixels.width - minY
        for c in 0..<4 { out[(y * width + x) * 4 + c] = pixels.bytes[index * 4 + c] }
    }
    let context = CGContext(data: &out, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    guard let cropped = context.makeImage() else { fatalError("\(name): couldn't build the image") }
    let folder = assets.appendingPathComponent("\(name).imageset")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let file = folder.appendingPathComponent("\(name).png")
    let destination = CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, cropped, nil)
    CGImageDestinationFinalize(destination)
    let contents = ["images": [["filename": "\(name).png", "idiom": "universal", "scale": "1x"]],
                    "info": ["author": "xcode", "version": 1]] as [String: Any]
    try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
        .write(to: folder.appendingPathComponent("Contents.json"))
    print(name, crop)
}
