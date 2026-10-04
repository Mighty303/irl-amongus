import SwiftUI
import UIKit

struct BodyReportView: View {
    let presentation: BodyReportPresentation
    var backdrop: UIImage? = nil
    let dismiss: () -> Void
    @State private var startedAt = Date()
    private let duration = 2.4

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSince(startedAt)
                let width = geometry.size.width
                let height = geometry.size.height
                let entrance = min(1, max(0, elapsed / 0.22))
                let exit = min(1, max(0, (elapsed - 2.15) / 0.25))
                let offset = width * (1 - entrance) - width * exit
                ZStack {
                    if let backdrop {
                        Image(uiImage: backdrop).resizable().scaledToFill()
                            .frame(width: width, height: height).clipped()
                    }
                    Color.black.opacity(0.25 * entrance * (1 - exit))
                    Image("BodyReportStreak")
                        .resizable().interpolation(.high)
                        .frame(width: width * 1.25, height: height * 0.90)
                        .offset(x: offset)
                    VStack(spacing: -height * 0.01) {
                        ZStack(alignment: .topLeading) {
                            Image("BodyReportSkull").resizable().scaledToFit()
                                .frame(width: height * 0.18)
                                .offset(x: -height * 0.015, y: -height * 0.11)
                            Image(uiImage: BodyReportArtwork.corpse(color: presentation.color))
                                .resizable().interpolation(.high).scaledToFit()
                                .frame(width: height * 0.30, height: height * 0.19)
                        }
                        Image("BodyReportLettering").resizable().interpolation(.high).scaledToFit()
                            .frame(width: height * 0.65, height: height * 0.32)
                            .shadow(color: .white, radius: 0, x: 1, y: 0)
                            .shadow(color: .white, radius: 0, x: -1, y: 0)
                            .shadow(color: .white, radius: 0, x: 0, y: 1)
                            .shadow(color: .white, radius: 0, x: 0, y: -1)
                    }
                    .offset(x: -offset, y: height * 0.04)
                    .opacity(entrance * (1 - exit))
                }
                .frame(width: width, height: height)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dead body reported")
        .accessibilityIdentifier("bodyReport.animation")
        .task {
            startedAt = .now
            do { try await Task.sleep(for: .seconds(duration)) } catch { return }
            dismiss()
        }
    }
}

enum BodyReportArtwork {
    private static let cache = NSCache<NSString, UIImage>()

    static func corpse(color: PlayerColor) -> UIImage {
        let key = NSString(string: color.name)
        if let image = cache.object(forKey: key) { return image }
        let source = UIImage(named: "BodyReportCorpse") ?? UIImage()
        guard let image = source.cgImage else { return source }
        let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(data: nil, width: image.width, height: image.height,
                                      bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info),
              let data = context.data else { return source }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        let (r, g, b) = color.suitRGB
        for i in stride(from: 0, to: image.width * image.height * 4, by: 4) {
            let red = Double(pixels[i]), green = Double(pixels[i + 1]), blue = Double(pixels[i + 2])
            let rgb: [Double], intensity: Double
            if red > 25 && red > green * 1.4 && red > blue * 1.3 {
                rgb = [Double(r), Double(g), Double(b)]; intensity = red / 255
            } else if blue > 25 && blue > red * 1.4 && blue > green * 1.2 {
                rgb = [Double(r), Double(g), Double(b)]; intensity = blue / 255 * 0.52
            } else if green > 25 && green > red * 1.4 && green > blue * 1.2 {
                rgb = [170, 215, 225]; intensity = green / 255
            } else { continue }
            for channel in 0..<3 { pixels[i + channel] = UInt8((rgb[channel] * intensity).rounded()) }
        }
        guard let result = context.makeImage() else { return source }
        let output = UIImage(cgImage: result)
        cache.setObject(output, forKey: key)
        return output
    }
}

struct BodyReportPreview: View {
    @State private var color = PlayerColor.black
    @State private var showingFlow = false

    var body: some View {
        Form {
            Picker("Reported player's colour", selection: $color) {
                ForEach(PlayerColor.allCases, id: \.self) { Text($0.name).tag($0) }
            }
            Button("Report a body") { showingFlow = true }
                .accessibilityIdentifier("bodyReport.preview.play")
        }
        .fullScreenCover(isPresented: $showingFlow) { BodyReportFlowPreview(color: color) }
    }
}

private struct BodyReportFlowPreview: View {
    let color: PlayerColor
    @Environment(\.dismiss) private var dismiss
    @State private var presentation: BodyReportPresentation?
    @State private var showingMeeting = false

    var body: some View {
        Group {
            if showingMeeting {
                VStack(spacing: 20) {
                    Text("Meeting").font(.largeTitle.bold())
                    Text("Return to the meeting area.")
                    Button("Return to preview") { dismiss() }
                        .accessibilityIdentifier("bodyReport.preview.done")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                PhysicalMapView(showsCloseButton: false, previewRole: .crewmate, requestsPortrait: false)
                    .allowsHitTesting(false)
            }
        }
        .background {
            BodyReportPresenter(presentation: presentation) { _ in
                presentation = nil
                showingMeeting = true
            }.frame(width: 0, height: 0)
        }
        .task {
            // Let the preview map finish appearing before taking its backdrop.
            do { try await Task.sleep(for: .seconds(0.4)) } catch { return }
            presentation = BodyReportPresentation(bodyID: "preview", color: color)
        }
        .onDisappear { OrientationDelegate.requestPortrait() }
    }
}
