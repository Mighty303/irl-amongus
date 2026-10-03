import SwiftUI

/// Opens the mini-game for a task once the player has checked in at the task's station.
/// The server re-validates the checkpoint (and the upload duration) on completion.
struct TaskSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let task: GameTask
    @State private var scanning = false

    var body: some View {
        if let state = store.state {
            let stationId = task.currentStationId
            let station = state.station(stationId)
            NavigationStack {
                VStack(spacing: 20) {
                    if let station { Text("📍 \(station.name)").font(.headline) }
                    if isCheckedIn(state: state, stationId: stationId) {
                        game(state: state)
                    } else {
                        Text("Go to \(station?.name ?? "the station") and scan its sign to start this task.")
                            .multilineTextAlignment(.center)
                        if let photoId = station?.photoId, let base = store.serverURL {
                            AsyncImage(url: base.appendingPathComponent("photos/\(photoId).jpg")) { $0.resizable().scaledToFit() }
                                placeholder: { ProgressView() }
                                .frame(maxHeight: 240)
                            Text("Look for this sign").font(.caption)
                        }
                        Button("📷 Scan sign") { scanning = true }.buttonStyle(.borderedProminent)
                    }
                    Spacer()
                }
                .padding()
                .toolbar { Button("Close") { dismiss() } }
                .sheet(isPresented: $scanning) { CheckpointScannerView(state: state) }
            }
        }
    }

    private func isCheckedIn(state: GameState, stationId: String?) -> Bool {
        if state.settings.devSkipCheckpoint { return true }
        guard let cp = state.me.lastCheckpoint, cp.stationId == stationId else { return false }
        return store.serverNow() - cp.at < Double(state.settings.checkpointTtlSec) * 1000
    }

    @ViewBuilder private func game(state: GameState) -> some View {
        switch task.type {
        case .wiring: WiringGame(onDone: complete)
        case .upload:
            UploadGame(seconds: state.settings.uploadSec,
                       start: { await store.perform("task_start", ["taskId": task.id]) },
                       onDone: complete)
        case .sequence: SequenceGame(onDone: complete)
        case .delivery:
            Button(task.step == 0 ? "📦 Pick up package" : "📬 Deliver package") { complete() }
                .buttonStyle(.borderedProminent).controlSize(.large)
            if task.step == 0, let dest = state.station(task.steps.last) {
                Text("Then carry it to \(dest.name)").font(.caption)
            }
        }
    }

    private func complete() {
        Task {
            if await store.perform("task_complete", ["taskId": task.id]) {
                Haptics.success()
                dismiss()
            }
        }
    }
}

/// Connect matching colored wires: tap a left wire, then the same color on the right.
struct WiringGame: View {
    let onDone: () -> Void
    private let colors: [Color] = [.red, .blue, .yellow, .pink]
    @State private var left: [Int] = Array(0..<4).shuffled()
    @State private var right: [Int] = Array(0..<4).shuffled()
    @State private var selected: Int?
    @State private var connected: Set<Int> = []

    var body: some View {
        VStack {
            Text("Fix wiring").font(.title2.bold())
            HStack(spacing: 80) {
                column(left) { c in selected = c }
                column(right) { c in
                    guard let s = selected else { return }
                    if s == c {
                        connected.insert(c)
                        Haptics.tap()
                        if connected.count == colors.count { onDone() }
                    } else {
                        Haptics.error()
                    }
                    selected = nil
                }
            }
        }
    }

    private func column(_ order: [Int], tap: @escaping (Int) -> Void) -> some View {
        VStack(spacing: 24) {
            ForEach(order, id: \.self) { c in
                RoundedRectangle(cornerRadius: 6)
                    .fill(colors[c])
                    .frame(width: 70, height: 36)
                    .overlay(connected.contains(c) ? Image(systemName: "checkmark").foregroundStyle(.white) : nil)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(selected == c ? Color.primary : .clear, lineWidth: 3))
                    .onTapGesture { if !connected.contains(c) { tap(c) } }
            }
        }
    }
}

/// Stay on the screen at the station until the upload finishes. Backgrounding cancels it.
struct UploadGame: View {
    @Environment(\.scenePhase) private var scenePhase
    let seconds: Int
    /// Tells the server the upload began (it enforces the duration). Returns false if rejected.
    let start: () async -> Bool
    let onDone: () -> Void
    @State private var startedAt: Date?
    @State private var progress = 0.0

    var body: some View {
        VStack(spacing: 16) {
            Text("Upload data").font(.title2.bold())
            ProgressView(value: progress)
            if startedAt == nil {
                Button("Start upload") { begin() }.buttonStyle(.borderedProminent)
            } else {
                Text("Uploading… don't leave this screen").font(.caption)
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

    private func begin() {
        Task {
            if await start() { startedAt = Date() }
        }
    }
}

/// Simon says: watch the sequence, then repeat it.
struct SequenceGame: View {
    let onDone: () -> Void
    private let colors: [Color] = [.green, .red, .yellow, .blue]
    @State private var sequence: [Int] = (0..<4).map { _ in Int.random(in: 0..<4) }
    @State private var lit: Int?
    @State private var input: [Int] = []
    @State private var showing = true

    var body: some View {
        VStack(spacing: 16) {
            Text(showing ? "Watch…" : "Repeat the sequence (\(input.count)/\(sequence.count))").font(.title3.bold())
            LazyVGrid(columns: [GridItem(), GridItem()], spacing: 12) {
                ForEach(0..<4) { i in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colors[i].opacity(lit == i ? 1 : 0.35))
                        .frame(height: 100)
                        .onTapGesture { tap(i) }
                }
            }
            .disabled(showing)
        }
        .task(id: sequence) { await play() }
    }

    private func play() async {
        showing = true
        input = []
        try? await Task.sleep(for: .milliseconds(600))
        for i in sequence {
            lit = i
            try? await Task.sleep(for: .milliseconds(500))
            lit = nil
            try? await Task.sleep(for: .milliseconds(200))
        }
        showing = false
    }

    private func tap(_ i: Int) {
        input.append(i)
        if input.last != sequence[input.count - 1] {
            Haptics.error()
            sequence = (0..<4).map { _ in Int.random(in: 0..<4) } // restart with a new sequence
        } else if input.count == sequence.count {
            onDone()
        } else {
            Haptics.tap()
        }
    }
}
