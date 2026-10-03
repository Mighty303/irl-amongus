import UIKit
import Vision

/// Recognizes station signage from the live camera without QR codes or NFC tags.
///
/// Two independent signals:
///  1. Image similarity: a Vision feature print of each station's reference photo is compared to the
///     camera frame. Lower distance = more similar. The threshold needs tuning on real signs.
///  2. Text: if the host entered the sign's text (e.g. "AQ 3005"), OCR finding it counts as a match.
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

    private let lock = NSLock()
    private var prints: [String: VNFeaturePrintObservation] = [:]
    private var preparedPhotoIds: Set<String> = []
    private var signTexts: [String: String] = [:]

    var loadedCount: Int { lock.withLock { prints.count } }

    /// Download reference photos for any station we haven't processed yet and compute feature prints.
    func prepare(stations: [Station], serverURL: URL) async {
        lock.withLock {
            signTexts = Dictionary(uniqueKeysWithValues: stations.compactMap { s in
                s.signText.map { (s.id, $0.lowercased()) }
            })
            let ids = Set(stations.map(\.id))
            prints = prints.filter { ids.contains($0.key) }
        }
        for station in stations {
            guard let photoId = station.photoId,
                  !lock.withLock({ preparedPhotoIds.contains(photoId) }) else { continue }
            let url = serverURL.appendingPathComponent("photos/\(photoId).jpg")
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data)?.cgImage else { continue }
                let print = try Self.featurePrint(cgImage: image)
                lock.withLock {
                    prints[station.id] = print
                    preparedPhotoIds.insert(photoId)
                }
            } catch {
                Swift.print("Failed to prepare sign for \(station.name): \(error)")
            }
        }
    }

    /// Register a reference directly (offline test lab). `text` enables OCR matching for this id.
    func setReference(id: String, image: CGImage, text: String?) throws {
        let print = try Self.featurePrint(cgImage: image)
        lock.withLock {
            prints[id] = print
            let t = text?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
            signTexts[id] = t.isEmpty ? nil : t
        }
    }

    func removeReference(id: String) {
        lock.withLock {
            prints[id] = nil
            signTexts[id] = nil
        }
    }

    func analyze(_ buffer: CVPixelBuffer, threshold: Float, useText: Bool = true) -> FrameResult {
        let (refs, texts) = lock.withLock { (prints, signTexts) }
        var distances: [String: Float] = [:]
        if let framePrint = try? Self.featurePrint(pixelBuffer: buffer) {
            for (stationId, ref) in refs {
                var d: Float = 0
                if (try? framePrint.computeDistance(&d, to: ref)) != nil { distances[stationId] = d }
            }
        }
        var lines: [String] = []
        if useText, !texts.isEmpty {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .fast
            try? VNImageRequestHandler(cvPixelBuffer: buffer).perform([request])
            lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        }

        let joined = lines.joined(separator: " ").lowercased()
        if let textHit = texts.first(where: { !$0.value.isEmpty && joined.contains($0.value) }) {
            return FrameResult(best: Match(stationId: textHit.key, distance: nil, byText: true), distances: distances, recognizedText: lines)
        }
        if let (id, d) = distances.min(by: { $0.value < $1.value }), d <= threshold {
            return FrameResult(best: Match(stationId: id, distance: d, byText: false), distances: distances, recognizedText: lines)
        }
        return FrameResult(best: nil, distances: distances, recognizedText: lines)
    }

    private static func featurePrint(cgImage: CGImage) throws -> VNFeaturePrintObservation {
        let request = VNGenerateImageFeaturePrintRequest()
        try VNImageRequestHandler(cgImage: cgImage).perform([request])
        guard let result = request.results?.first else { throw CocoaError(.featureUnsupported) }
        return result
    }

    private static func featurePrint(pixelBuffer: CVPixelBuffer) throws -> VNFeaturePrintObservation {
        let request = VNGenerateImageFeaturePrintRequest()
        try VNImageRequestHandler(cvPixelBuffer: pixelBuffer).perform([request])
        guard let result = request.results?.first else { throw CocoaError(.featureUnsupported) }
        return result
    }
}
