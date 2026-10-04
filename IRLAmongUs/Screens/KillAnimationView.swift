import SwiftUI
import UIKit

struct NeckKillFrames: @unchecked Sendable {
    let images: [UIImage]
    let durations: [Double]
    var duration: Double { durations.reduce(0, +) }

    func frameIndex(at elapsed: Double) -> Int {
        var end = 0.0
        for (index, delay) in durations.enumerated() {
            end += delay
            if elapsed < end { return index }
        }
        return max(0, durations.count - 1)
    }

    static func load(attacker: PlayerColor?, victim: PlayerColor) throws -> Self {
        struct Timing: Decodable { let durations: [Double] }
        guard let data = NSDataAsset(name: "NeckKillTiming")?.data else { throw AssetError.missing }
        let timing = try JSONDecoder().decode(Timing.self, from: data)
        var images: [UIImage] = []
        for index in timing.durations.indices {
            guard let original = UIImage(named: String(format: "NeckKillFrame%02d", index))?.cgImage,
                  let mask = UIImage(named: String(format: "NeckKillMask%02d", index))?.cgImage else {
                throw AssetError.missing
            }
            images.append(try recolor(original, mask: mask, attacker: attacker, victim: victim))
        }
        return Self(images: images, durations: timing.durations)
    }

    static func recolor(_ image: CGImage, mask: CGImage, attacker: PlayerColor?, victim: PlayerColor) throws -> UIImage {
        let width = image.width, height = image.height
        let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let pixels = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info),
              let masks = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                   bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info),
              let pixelData = pixels.data, let maskData = masks.data else { throw AssetError.missing }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        pixels.draw(image, in: rect)
        masks.draw(mask, in: rect)
        let rgba = pixelData.assumingMemoryBound(to: UInt8.self)
        let labels = maskData.assumingMemoryBound(to: UInt8.self)
        for i in stride(from: 0, to: width * height * 4, by: 4) {
            let color: PlayerColor
            let shade: Double
            if labels[i] > 0, let attacker {
                color = attacker
                shade = Double(rgba[i]) / 207
            } else if labels[i + 1] > 0 {
                color = victim
                shade = Double(rgba[i + 1]) / 124
            } else { continue }
            let (r, g, b) = color.suitRGB
            for (channel, value) in [r, g, b].enumerated() {
                rgba[i + channel] = UInt8(min(255, (Double(value) * shade).rounded()))
            }
        }
        guard let result = pixels.makeImage() else { throw AssetError.missing }
        return UIImage(cgImage: result)
    }

    enum AssetError: Error { case missing }
}

/// Uses source frame delays, including delays shorter than UIImage animation's uniform interval.
struct KillAnimationView: View {
    let presentation: KillPresentation
    let dismiss: () -> Void
    @State private var frames: NeckKillFrames?
    @State private var startedAt: Date?

    var body: some View {
        ZStack {
            Color.black
            if let frames, let startedAt {
                TimelineView(.animation) { context in
                    let index = frames.frameIndex(at: context.date.timeIntervalSince(startedAt))
                    Image(uiImage: frames.images[index])
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Kill animation")
        .accessibilityIdentifier("kill.animation")
        .task(id: presentation) {
            let attacker = presentation.attackerColor, victim = presentation.victimColor
            let loaded = await Task.detached(priority: .userInitiated) {
                try? NeckKillFrames.load(attacker: attacker, victim: victim)
            }.value
            guard !Task.isCancelled else { return }
            guard let loaded else { dismiss(); return }
            frames = loaded
            if startedAt == nil { startedAt = .now }
            let remaining = max(0, loaded.duration - Date.now.timeIntervalSince(startedAt!))
            do { try await Task.sleep(for: .seconds(remaining)) } catch { return }
            dismiss()
        }
    }
}

struct KillAnimationPreview: View {
    @State private var attacker = PlayerColor.red
    @State private var victim = PlayerColor.green
    @State private var presentation: KillPresentation?
    @StateObject private var audio = KillAudioPlayer()

    var body: some View {
        Form {
            Picker("Attacker", selection: $attacker) {
                ForEach(PlayerColor.allCases, id: \.self) { Text($0.name).tag($0) }
            }
            Picker("Victim", selection: $victim) {
                ForEach(PlayerColor.allCases, id: \.self) { Text($0.name).tag($0) }
            }
            Button("Play neck kill") {
                presentation = KillPresentation(victimID: "preview", attackerColor: attacker, victimColor: victim)
                audio.play(.victim)
            }
            .accessibilityIdentifier("kill.preview.play")
        }
        .fullScreenCover(item: $presentation) { kill in
            KillAnimationView(presentation: kill) { presentation = nil }
                .interactiveDismissDisabled()
                .onAppear { OrientationDelegate.requestLandscape() }
                .onDisappear { OrientationDelegate.requestPortrait() }
        }
        .onDisappear { audio.stop() }
    }
}
