#!/usr/bin/env swift
// Extract the supplied GIF without redrawing; isolate enclosed suit colour regions.
import Foundation
import ImageIO
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("IRLAmongUs/Assets/KillAnimation/Neck_Kill.gif")
let assets = root.appendingPathComponent("IRLAmongUs/Assets.xcassets/KillAnimation")
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
let gif = CGImageSourceCreateWithURL(source as CFURL, nil)!
let width = 338, height = 200
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = ["magick", source.path, "-coalesce", "-depth", "8", "rgba:-"]
let pipe = Pipe()
process.standardOutput = pipe
try process.run()
let raw = [UInt8](pipe.fileHandleForReading.readDataToEndOfFile())
process.waitUntilExit()
precondition(process.terminationStatus == 0)
let count = CGImageSourceGetCount(gif)
precondition(raw.count == count * width * height * 4)
var durations: [Double] = []

func writeAsset(_ name: String, _ bytes: [UInt8]) throws {
    let folder = assets.appendingPathComponent("\(name).imageset")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let provider = CGDataProvider(data: Data(bytes) as CFData)!
    let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    let destination = CGImageDestinationCreateWithURL(folder.appendingPathComponent("\(name).png") as CFURL,
                                                     "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    precondition(CGImageDestinationFinalize(destination))
    let contents: [String: Any] = ["images": [["filename": "\(name).png", "idiom": "universal", "scale": "1x"]],
                                  "info": ["author": "xcode", "version": 1]]
    try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
        .write(to: folder.appendingPathComponent("Contents.json"))
}

for frame in 0..<count {
    let pixels = Array(raw[(frame * width * height * 4)..<((frame + 1) * width * height * 4)])
    let properties = CGImageSourceCopyPropertiesAtIndex(gif, frame, nil)! as NSDictionary
    // The supplied .gif is actually animated WebP; preserve its bytes and original timing.
    let timing = (properties[kCGImagePropertyGIFDictionary] ?? properties["{WebP}"]) as! NSDictionary
    durations.append((timing[kCGImagePropertyGIFUnclampedDelayTime] ?? timing[kCGImagePropertyGIFDelayTime]) as! Double)
    var candidates = [UInt8](repeating: 0, count: width * height)
    for y in 35..<174 {
        for x in 80..<270 {
            let p = y * width + x, i = p * 4
            let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2])
            if r > 25 && r > g * 2 && r > b { candidates[p] = 1 }
            if g > 25 && g > r * 2 && g > b * 3 / 2 { candidates[p] = 2 }
        }
    }
    var visited = [Bool](repeating: false, count: width * height)
    var mask = [UInt8](repeating: 0, count: pixels.count)
    for p in 0..<(width * height) where candidates[p] != 0 && !visited[p] {
        let kind = candidates[p]
        var component = [p], cursor = 0, touchesBoundary = false
        visited[p] = true
        while cursor < component.count {
            let q = component[cursor]; cursor += 1
            let x = q % width, y = q / width
            if x == 80 || x == 269 || y == 35 || y == 173 { touchesBoundary = true }
            for next in [q - 1, q + 1, q - width, q + width] {
                if next >= 0 && next < candidates.count && !visited[next] && candidates[next] == kind {
                    visited[next] = true
                    component.append(next)
                }
            }
        }
        // Background streaks run outside the character region; enclosed suit patches do not.
        let minX = component.map { $0 % width }.min()!
        let minY = component.map { $0 / width }.min()!
        // A detached red speed-line sits below/right of the hands. Once the hands
        // withdraw (frame 34), all attacker pixels are in the left body region.
        let speedLine = kind == 1 && minX >= 150 && (minY >= 132 || frame >= 34)
        if !touchesBoundary && !speedLine && component.count >= 2 {
            for q in component { mask[q * 4 + Int(kind) - 1] = 255 }
        }
    }
    // Include dark suit edge pixels adjacent to an identified region, without
    // allowing those compressed edge colours to join the suit to a speed-line.
    var expanded = mask
    for y in 36..<173 {
        for x in 81..<269 {
            let p = y * width + x, i = p * 4
            let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2])
            guard mask[i] == 0 && mask[i + 1] == 0 && r > 18 && r > g * 2 && r * 5 > b * 4 else { continue }
            if [p - 1, p + 1, p - width, p + width].contains(where: { mask[$0 * 4] > 0 }) {
                expanded[i] = 255
            }
        }
    }
    mask = expanded
    for p in 0..<(width * height) { mask[p * 4 + 3] = 255 }
    try writeAsset(String(format: "NeckKillFrame%02d", frame), pixels)
    try writeAsset(String(format: "NeckKillMask%02d", frame), mask)
}
let manifest: [String: Any] = ["width": width, "height": height, "durations": durations]
try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
    .write(to: root.appendingPathComponent("IRLAmongUs/Assets/KillAnimation/timing.json"))
let timingAsset = assets.appendingPathComponent("NeckKillTiming.dataset")
try FileManager.default.createDirectory(at: timingAsset, withIntermediateDirectories: true)
try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
    .write(to: timingAsset.appendingPathComponent("timing.json"))
try Data(#"{"data":[{"filename":"timing.json","idiom":"universal"}],"info":{"author":"xcode","version":1}}"#.utf8)
    .write(to: timingAsset.appendingPathComponent("Contents.json"))
print("Imported \(count) frames; \(durations.reduce(0, +)) seconds")
