import SwiftUI

/// Offline sign-recognition test bench: capture reference signs, then point the camera around
/// and watch live similarity distances. No server or game needed. References persist on-device.
struct SignsLabView: View {
    @State private var lab = SignsLab()
    @State private var latestFrame = FrameBox()
    @State private var threshold: Float = 0.6
    @State private var distances: [String: Float] = [:]
    @State private var ocr: [String] = []
    @State private var match: (id: String, hits: Int, byText: Bool)?
    @State private var analysisMs = 0
    @State private var pendingImage: UIImage?
    @State private var newName = ""
    @State private var newText = ""
    @State private var useOCR = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CameraView(onFrame: { [recognizer = lab.recognizer, threshold, useOCR, latestFrame] buffer in
                    latestFrame.buffer = buffer
                    let start = Date()
                    let result = recognizer.analyze(buffer, threshold: threshold, useText: useOCR)
                    let ms = Int(Date().timeIntervalSince(start) * 1000)
                    DispatchQueue.main.async { handle(result, ms: ms) }
                })
                .frame(height: 340)
                .overlay(alignment: .top) { banner }
                .overlay(alignment: .bottom) {
                    Button {
                        if let image = latestFrame.buffer?.toUIImage() { pendingImage = image; newName = ""; newText = "" }
                    } label: {
                        Label("Capture reference", systemImage: "camera.circle.fill")
                            .padding(10).background(.thinMaterial, in: Capsule())
                    }
                    .padding(10)
                }

                List {
                    Section {
                        VStack(alignment: .leading) {
                            Text("Match if distance ≤ \(threshold, specifier: "%.2f")   ·   \(analysisMs) ms/frame").font(.caption)
                            Slider(value: $threshold, in: 0.1...1.5)
                        }
                        Toggle("Also match by sign text (OCR)", isOn: $useOCR)
                        if useOCR && !ocr.isEmpty {
                            Text("OCR: " + ocr.joined(separator: " | ")).font(.caption2).foregroundStyle(.secondary)
                        }
                    } footer: {
                        Text("Lower distance = more similar. Point at each reference sign AND at other things nearby. A good threshold sits between the two.")
                    }

                    Section("Reference signs (\(lab.signs.count))") {
                        if lab.signs.isEmpty {
                            Text("Point at a sign and tap Capture reference.").foregroundStyle(.secondary)
                        }
                        ForEach(lab.signs) { sign in
                            HStack {
                                if let img = lab.images[sign.id] {
                                    Image(uiImage: img).resizable().scaledToFill().frame(width: 50, height: 50).clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                VStack(alignment: .leading) {
                                    Text(sign.name).font(.headline)
                                    if !sign.text.isEmpty { Text("text: “\(sign.text)”").font(.caption) }
                                }
                                Spacer()
                                if let d = distances[sign.id] {
                                    Text(String(format: "%.3f", d))
                                        .font(.body.monospaced().bold())
                                        .foregroundStyle(d <= threshold ? .green : .secondary)
                                }
                            }
                            .listRowBackground(match?.id == sign.id ? Color.green.opacity(0.2) : nil)
                        }
                        .onDelete { lab.remove(at: $0) }
                    }
                }
            }
            .navigationTitle("Sign recognition")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Name this sign", isPresented: Binding(get: { pendingImage != nil }, set: { if !$0 { pendingImage = nil } })) {
                TextField("Name (e.g. Electrical)", text: $newName)
                TextField("Text on sign (optional)", text: $newText)
                Button("Save") {
                    if let img = pendingImage { lab.add(name: newName.isEmpty ? "Sign \(lab.signs.count + 1)" : newName, text: newText, image: img) }
                    pendingImage = nil
                }
                Button("Cancel", role: .cancel) { pendingImage = nil }
            }
        }
    }

    @ViewBuilder private var banner: some View {
        if let match, match.hits >= 2, let sign = lab.signs.first(where: { $0.id == match.id }) {
            Text("✅ MATCH: \(sign.name)\(match.byText ? " (text)" : "")")
                .font(.headline).padding(10).background(.green, in: Capsule()).foregroundStyle(.white).padding(8)
        } else if !lab.signs.isEmpty {
            Text("No match").font(.caption).padding(6).background(.thinMaterial, in: Capsule()).padding(8)
        }
    }

    private func handle(_ result: SignRecognizer.FrameResult, ms: Int) {
        distances = result.distances
        ocr = result.recognizedText
        analysisMs = ms
        guard let best = result.best else { match = nil; return }
        let hits = match?.id == best.stationId ? (match?.hits ?? 0) + 1 : 1
        if hits == 2 { Haptics.success() } // same 2-frame rule the game uses before checking in
        match = (best.stationId, hits, best.byText)
    }
}

@Observable
final class SignsLab {
    struct Sign: Identifiable, Codable {
        let id: String
        var name: String
        var text: String
    }

    private(set) var signs: [Sign] = []
    private(set) var images: [String: UIImage] = [:]
    @ObservationIgnored let recognizer = SignRecognizer()

    private let dir: URL = {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("lab-signs")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    init() {
        if let data = try? Data(contentsOf: dir.appendingPathComponent("signs.json")),
           let saved = try? JSONDecoder().decode([Sign].self, from: data) {
            for sign in saved {
                guard let img = UIImage(contentsOfFile: dir.appendingPathComponent("\(sign.id).jpg").path) else { continue }
                register(sign, image: img)
            }
        }
    }

    func add(name: String, text: String, image: UIImage) {
        let sign = Sign(id: UUID().uuidString, name: name, text: text)
        // Same downscale the station editor applies before uploading, so results match real games.
        let resized = image.resized(maxDimension: 800)
        try? resized.jpegData(compressionQuality: 0.8)?.write(to: dir.appendingPathComponent("\(sign.id).jpg"))
        register(sign, image: resized)
        save()
    }

    func remove(at offsets: IndexSet) {
        for i in offsets {
            let sign = signs[i]
            recognizer.removeReference(id: sign.id)
            images[sign.id] = nil
            try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(sign.id).jpg"))
        }
        signs.remove(atOffsets: offsets)
        save()
    }

    private func register(_ sign: Sign, image: UIImage) {
        guard let cg = image.cgImage, (try? recognizer.setReference(id: sign.id, image: cg, text: sign.text)) != nil else { return }
        signs.append(sign)
        images[sign.id] = image
    }

    private func save() {
        try? JSONEncoder().encode(signs).write(to: dir.appendingPathComponent("signs.json"))
    }
}
