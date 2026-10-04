import UIKit
import Vision

/// Recognizes station signage from the live camera without QR codes or NFC tags.
///
/// Two independent signals:
///  1. Image similarity: a Vision feature print of each station's reference photo is compared to the
///     camera frame. Lower distance = more similar. The threshold needs tuning on real signs.
///  2. Text: the sign's text (read when it was photographed, e.g. "AQ 3005"): OCR finding all its words counts.
///
/// Thread-safe: `match` is called from the camera queue while `prepare` may run on another task.
final class SignRecognizer: @unchecked Sendable {
    struct Match {
        let stationId: String
        let distance: Float?   // nil when matched by text
        let byText: Bool
    }

    struct FrameResult {
        let best: Match?
        let distances: [String: Float]
        let recognizedText: [String]
    }

    /// A sign's reference photo as two feature prints: the whole photo, and its centered square (where
    /// the sign is). The square makes a portrait photo and a landscape camera frame comparable.
    private struct Reference {
        let full: VNFeaturePrintObservation
        let square: VNFeaturePrintObservation
    }

    private let lock = NSLock()
    private var prints: [String: Reference] = [:]
    /// Processed photos by photo id, so the same photo under a new station id (another lobby, a saved
    /// game loaded again) is reused instead of skipped.
    private var printsByPhoto: [String: Reference] = [:]
    /// The words of each station's sign text (lowercased).
    private var signWords: [String: [String]] = [:]

    var loadedCount: Int { lock.withLock { prints.count } }

    /// Download reference photos for any station we haven't processed yet and compute feature prints.
    func prepare(stations: [Station], serverURL: URL) async {
        lock.withLock {
            signWords = Dictionary(uniqueKeysWithValues: stations.compactMap { s in
                s.signText.flatMap { text in Self.words(text).nilIfEmpty.map { (s.id, $0) } }
            })
            let ids = Set(stations.map(\.id))
            prints = prints.filter { ids.contains($0.key) }
        }
        for station in stations {
            guard let photoId = station.photoId else { continue }
            if let cached = lock.withLock({ printsByPhoto[photoId] }) {
                lock.withLock { prints[station.id] = cached }
                continue
            }
            let url = serverURL.appendingPathComponent("photos/\(photoId).jpg")
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data)?.cgImage else { continue }
                let reference = try Self.reference(cgImage: image)
                lock.withLock {
                    prints[station.id] = reference
                    printsByPhoto[photoId] = reference
                }
            } catch {
                Swift.print("Failed to prepare sign for \(station.name): \(error)")
            }
        }
    }

    /// Register a reference directly (offline test lab). `text` enables OCR matching for this id.
    func setReference(id: String, image: CGImage, text: String?) throws {
        let reference = try Self.reference(cgImage: image)
        lock.withLock {
            prints[id] = reference
            signWords[id] = text.map(Self.words)?.nilIfEmpty
        }
    }

    func removeReference(id: String) {
        lock.withLock {
            prints[id] = nil
            signWords[id] = nil
        }
    }

    /// `prefer`: the sign being looked for (a task's sign), which wins a tie with another sign's text.
    func analyze(_ buffer: CVPixelBuffer, threshold: Float, useText: Bool = true, prefer: String? = nil) -> FrameResult {
        let (refs, texts) = lock.withLock { (prints, signWords) }
        var distances: [String: Float] = [:]
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        let full = try? Self.featurePrint(pixelBuffer: buffer, region: nil)
        let square = try? Self.featurePrint(pixelBuffer: buffer, region: Self.centerSquare(width: width, height: height))
        for (stationId, ref) in refs {
            // Whichever comparison is closer: whole frame to whole photo, or centered square to square.
            var best: Float?
            for (frame, photo) in [(full, ref.full), (square, ref.square)] {
                var d: Float = 0
                if let frame, (try? frame.computeDistance(&d, to: photo)) != nil { best = min(best ?? d, d) }
            }
            if let best { distances[stationId] = best }
        }
        var lines: [String] = []
        if useText, !texts.isEmpty {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .fast
            try? VNImageRequestHandler(cvPixelBuffer: buffer).perform([request])
            lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        }

        // Text match: every word of the sign's text appears somewhere in view, in any order (signs read
        // over two lines often come back in a different order).
        let seen = Set(Self.words(lines.joined(separator: " ")))
        if let textHit = Self.textMatch(signWords: texts, seen: seen, distances: distances, prefer: prefer) {
            return FrameResult(best: Match(stationId: textHit, distance: nil, byText: true), distances: distances, recognizedText: lines)
        }
        if let (id, d) = distances.min(by: { $0.value < $1.value }), d <= threshold {
            return FrameResult(best: Match(stationId: id, distance: d, byText: false), distances: distances, recognizedText: lines)
        }
        return FrameResult(best: nil, distances: distances, recognizedText: lines)
    }

    /// Which sign's text is in view. Several can be (a short "EXIT" is inside lots of signs): the one with the
    /// most words wins; between equally specific ones, the sign being looked for, else the closest photo.
    /// Still a tie (same text, no photos to tell apart): none, rather than checking in at the wrong sign.
    static func textMatch(signWords: [String: [String]], seen: Set<String>, distances: [String: Float],
                          prefer: String?) -> String? {
        let hits = signWords.filter { !$0.value.isEmpty && $0.value.allSatisfy(seen.contains) }
        guard let most = hits.values.map({ Set($0).count }).max() else { return nil }
        let specific = hits.filter { Set($0.value).count == most }.map(\.key)
        if specific.count == 1 { return specific[0] }
        if let prefer, specific.contains(prefer) { return prefer }
        let ranked = specific.compactMap { id in distances[id].map { (id, $0) } }.sorted { $0.1 < $1.1 }
        guard let first = ranked.first, ranked.count == specific.count, ranked.count < 2 || ranked[1].1 > first.1 else { return nil }
        return first.0
    }

    /// Lowercased words of a sign's text: letters and digits, punctuation dropped.
    static func words(_ text: String) -> [String] {
        text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }

    /// The centered square of an image, in Vision's normalized coordinates.
    private static func centerSquare(width: Int, height: Int) -> CGRect {
        guard width > 0, height > 0 else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        if width >= height {
            let side = CGFloat(height) / CGFloat(width)
            return CGRect(x: (1 - side) / 2, y: 0, width: side, height: 1)
        }
        let side = CGFloat(width) / CGFloat(height)
        return CGRect(x: 0, y: (1 - side) / 2, width: 1, height: side)
    }

    private static func reference(cgImage: CGImage) throws -> Reference {
        Reference(full: try featurePrint(cgImage: cgImage, region: nil),
                  square: try featurePrint(cgImage: cgImage, region: centerSquare(width: cgImage.width, height: cgImage.height)))
    }

    private static func featurePrint(cgImage: CGImage, region: CGRect?) throws -> VNFeaturePrintObservation {
        let request = VNGenerateImageFeaturePrintRequest()
        if let region { request.regionOfInterest = region }
        try VNImageRequestHandler(cgImage: cgImage).perform([request])
        guard let result = request.results?.first else { throw CocoaError(.featureUnsupported) }
        return result
    }

    private static func featurePrint(pixelBuffer: CVPixelBuffer, region: CGRect?) throws -> VNFeaturePrintObservation {
        let request = VNGenerateImageFeaturePrintRequest()
        if let region { request.regionOfInterest = region }
        try VNImageRequestHandler(cvPixelBuffer: pixelBuffer).perform([request])
        guard let result = request.results?.first else { throw CocoaError(.featureUnsupported) }
        return result
    }
}

private extension Array {
    var nilIfEmpty: [Element]? { isEmpty ? nil : self }
}
