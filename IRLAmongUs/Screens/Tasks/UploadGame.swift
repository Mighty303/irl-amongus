import SwiftUI

/// Upload Data: press Upload and stay on the screen while files fly from one folder to the other.
/// Leaving the app cancels it; the server separately enforces the duration.
/// Coordinates are pixels of the 500×326 tablet art.
struct UploadGame: View {
    @Environment(\.scenePhase) private var scenePhase
    let seconds: Int
    /// Tells the server the upload began (it enforces the duration). Returns false if rejected.
    let start: () async -> Bool
    let onDone: () -> Void
    @State private var startedAt: Date?
    @State private var progress = 0.0
    /// The silly "Estimated Time" the game counts down from.
    @State private var fakeTotal = Double.random(in: 2...5) * 86_400

    private static let fromFolder = CGPoint(x: 111, y: 125)
    private static let toFolder = CGPoint(x: 389, y: 125)

    var body: some View {
        SpriteStage(width: 500, height: 326) {
            ZStack {
                Image("TaskUploadBase")
                if startedAt != nil {
                    folderLid(at: Self.fromFolder)
                    folderLid(at: Self.toFolder)
                    TimelineView(.animation) { context in flyingFiles(at: context.date) }
                    Text(progress >= 1 ? "Complete" : "Estimated Time: \(estimate)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .at(250, 192)
                    progressBar.at(250, 222)
                } else {
                    Button { begin() } label: { Image("TaskUploadButton").scaleEffect(1.6) }
                        .at(250, 215)
                }
            }
        }
        .task(id: startedAt) {
            guard let startedAt else { return }
            while !Task.isCancelled {
                progress = min(1, Date().timeIntervalSince(startedAt) / Double(seconds))
                if progress >= 1 { onDone(); return }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { startedAt = nil; progress = 0 } // server also enforces duration
        }
    }

    private var estimate: String {
        let left = Int(fakeTotal * (1 - progress)) + Int.random(in: 0...59)
        return "\(left / 86_400)d \(left % 86_400 / 3600)hr \(left % 3600 / 60)m \(left % 60)s"
    }

    private func folderLid(at point: CGPoint) -> some View {
        Image("TaskUploadFolderOpen5").scaleEffect(0.85).at(point.x + 6, point.y - 22)
    }

    /// Three pages at a time arcing from folder to folder.
    private func flyingFiles(at date: Date) -> some View {
        let t = date.timeIntervalSinceReferenceDate
        return ZStack {
            ForEach(0..<3, id: \.self) { i in
                let f = (t / 1.2 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                let x = Self.fromFolder.x + (Self.toFolder.x - Self.fromFolder.x) * f
                let y = Self.fromFolder.y - 10 - 70 * sin(.pi * f)
                Image("TaskUploadFile").scaleEffect(0.45).rotationEffect(.degrees(f * 40 - 20)).at(x, y)
            }
        }
        .opacity(progress >= 1 ? 0 : 1)
    }

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Image("TaskUploadBar")
            Capsule().fill(Color(red: 0.27, green: 0.85, blue: 0.27))
                .frame(width: max(0, 382 * progress), height: 15)
                .padding(.leading, 4)
        }
    }

    private func begin() {
        TaskSound.select.play()
        Task {
            if await start() {
                fakeTotal = Double.random(in: 2...5) * 86_400
                startedAt = Date()
            }
        }
    }
}
