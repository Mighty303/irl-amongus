#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

// A deterministic, asymmetric, feature-rich reference image. Print the entire square.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent("IRLAmongUs/Assets.xcassets/ARAlignmentMarker.imageset")
let size = 800
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                             isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
let ctx = graphics.cgContext
ctx.setFillColor(NSColor.white.cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
var seed: UInt64 = 0x1A11_6E42
func random(_ limit: Int) -> Int {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return Int((seed >> 32) % UInt64(limit))
}
// Irregular geometry at multiple scales creates distinguishable grayscale corners.
for i in 0..<340 {
    let x = CGFloat(25 + random(740)), y = CGFloat(25 + random(740))
    let w = CGFloat(8 + random(56)), h = CGFloat(8 + random(52))
    let gray = CGFloat(random(100)) / 160
    ctx.setFillColor(NSColor(white: gray, alpha: 1).cgColor)
    let rect = CGRect(x: x, y: y, width: min(w, 780 - x), height: min(h, 780 - y))
    if i % 3 == 0 { ctx.fillEllipse(in: rect) } else { ctx.fill(rect) }
}
ctx.setFillColor(NSColor.black.cgColor)
ctx.fill(CGRect(x: 180, y: 275, width: 450, height: 245))
let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
func text(_ value: String, rect: CGRect, font: CGFloat, color: NSColor) {
    (value as NSString).draw(in: rect, withAttributes: [.font: NSFont.boldSystemFont(ofSize: font),
                            .foregroundColor: color, .paragraphStyle: paragraph])
}
text("ALIGN", rect: CGRect(x: 185, y: 385, width: 440, height: 85), font: 72, color: .white)
text("THIS SIDE UP", rect: CGRect(x: 185, y: 325, width: 440, height: 42), font: 30, color: .white)
ctx.setFillColor(NSColor.white.cgColor)
ctx.beginPath(); ctx.move(to: CGPoint(x: 385, y: 480)); ctx.addLine(to: CGPoint(x: 405, y: 505)); ctx.addLine(to: CGPoint(x: 425, y: 480)); ctx.closePath(); ctx.fillPath()
ctx.setStrokeColor(NSColor.black.cgColor)
ctx.setLineWidth(2)
ctx.stroke(CGRect(x: 1, y: 1, width: 798, height: 798))
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("ARAlignmentMarker.png"))
try "{\"images\":[{\"filename\":\"ARAlignmentMarker.png\",\"idiom\":\"universal\"}],\"info\":{\"author\":\"xcode\",\"version\":1}}\n".write(to: output.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

// US Letter PDF: the entire image is exactly 200 mm wide at Actual Size / 100%.
let pdfURL = root.appendingPathComponent("docs/ar-alignment/print-marker-20cm.pdf")
var page = CGRect(x: 0, y: 0, width: 612, height: 792)
let pdf = CGContext(pdfURL as CFURL, mediaBox: &page, nil)!
pdf.beginPDFPage(nil)
pdf.setFillColor(NSColor.white.cgColor); pdf.fill(page)
let width = 200.0 / 25.4 * 72
pdf.draw(bitmap.cgImage!, in: CGRect(x: (612 - width) / 2, y: 120, width: width, height: width))
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: pdf, flipped: false)
text("IRL AMONG US · AR ALIGNMENT", rect: CGRect(x: 20, y: 735, width: 572, height: 25), font: 18, color: .black)
text("Print at Actual Size / 100%. Entire square must measure 20 cm.", rect: CGRect(x: 20, y: 85, width: 572, height: 20), font: 12, color: .black)
text("Mount upright on a wall. Measure image centre height above the floor.", rect: CGRect(x: 20, y: 60, width: 572, height: 20), font: 12, color: .black)
text("Set that height in the POC map setup. Map origin is directly below the centre.", rect: CGRect(x: 20, y: 35, width: 572, height: 20), font: 11, color: .black)
NSGraphicsContext.restoreGraphicsState()
pdf.endPDFPage(); pdf.closePDF()
let dataset = root.appendingPathComponent("IRLAmongUs/Assets.xcassets/ARAlignmentPrintable.dataset")
try FileManager.default.createDirectory(at: dataset, withIntermediateDirectories: true)
try Data(contentsOf: pdfURL).write(to: dataset.appendingPathComponent("print-marker-20cm.pdf"))
try "{\"data\":[{\"filename\":\"print-marker-20cm.pdf\",\"idiom\":\"universal\"}],\"info\":{\"author\":\"xcode\",\"version\":1}}\n".write(to: dataset.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print(pdfURL.path)
