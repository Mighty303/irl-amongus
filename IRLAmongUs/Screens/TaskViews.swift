import SwiftUI

/// Opens the mini-game for a task once the player has checked in at the task's station.
/// The server re-validates the checkpoint (and the upload duration) on completion.
struct TaskSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let task: GameTask
    @State private var scanning = false
    @State private var completed = false
    @State private var error: String?
    /// Bumped when the server rejects a completion, so the mini-game starts over.
    @State private var attempt = 0

    var body: some View {
        if let state = store.state {
            let stationId = task.currentStationId
            let station = state.station(stationId)
            TaskPanel(title: station.map { "📍 \($0.name)" }, message: error, completed: completed, close: close) {
                if isCheckedIn(state: state, stationId: stationId) {
                    game(state: state).id(attempt)
                } else {
                    checkInPrompt(station: station)
                }
            }
            .sheet(isPresented: $scanning) { CheckpointScannerView(state: state) }
        }
    }

    private func isCheckedIn(state: GameState, stationId: String?) -> Bool {
        if state.settings.devSkipCheckpoint { return true }
        guard let cp = state.me.lastCheckpoint, cp.stationId == stationId else { return false }
        return store.serverNow() - cp.at < Double(state.settings.checkpointTtlSec) * 1000
    }

    private func checkInPrompt(station: Station?) -> some View {
        HStack(spacing: 24) {
            if let station { SignGuide(station: station) }
            VStack(spacing: 16) {
                Text("Go to \(station?.name ?? "the sign") and scan it to start this task.")
                    .multilineTextAlignment(.center)
                Button("📷 Scan sign") { scanning = true }.buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func game(state: GameState) -> some View {
        TaskGame(task: task, state: state, onDone: complete)
    }

    private func complete() {
        Task {
            error = nil
            if await store.perform("task_complete", ["taskId": task.id]) {
                completed = true
                TaskSound.complete.play()
                Haptics.success()
                try? await Task.sleep(for: .milliseconds(1400))
                close()
            } else {
                // Shown here because the game's alert can't appear over this cover.
                error = store.errorMessage
                store.errorMessage = nil
                attempt += 1
            }
        }
    }

    private func close() {
        TaskSound.panelClose.play()
        dismiss()
    }
}

/// The mini-game for a task's current step. Shared by the task sheet and the in-game HUD's task square;
/// the caller sends `task_complete` when `onDone` fires.
struct TaskGame: View {
    @Environment(GameStore.self) private var store
    let task: GameTask
    let state: GameState
    let onDone: () -> Void

    var body: some View {
        switch task.type {
        case .wiring: WiringGame(onDone: onDone)
        case .upload:
            UploadGame(seconds: state.settings.uploadSec,
                       start: { await store.perform("task_start", ["taskId": task.id]) },
                       onDone: onDone)
        case .sequence: SequenceGame(onDone: onDone)
        case .swipe: SwipeCardGame(onDone: onDone)
        case .shields: ShieldsGame(onDone: onDone)
        case .o2: O2Game(onDone: onDone)
        case .scan:
            ScanGame(seconds: state.settings.scanSec ?? 10, playerName: state.me.name,
                     start: { await store.perform("task_start", ["taskId": task.id]) },
                     onDone: onDone)
        case .divert:
            if task.step == 0 {
                VStack(spacing: 8) {
                    DivertPowerGame(onDone: onDone)
                    if let dest = state.station(task.steps.last) {
                        Text("Then accept the power at \(dest.name)").font(.caption.bold()).foregroundStyle(.white)
                    }
                }
            } else {
                AcceptPowerGame(onDone: onDone)
            }
        case .unknown:
            Text("This task needs a newer version of the app.")
                .font(.headline).foregroundStyle(.white).multilineTextAlignment(.center)
        case .delivery:
            VStack(spacing: 12) {
                Button(task.step == 0 ? "📦 Pick up package" : "📬 Deliver package") { onDone() }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                if task.step == 0, let dest = state.station(task.steps.last) {
                    Text("Then carry it to \(dest.name)").font(.caption).foregroundStyle(.white)
                }
            }
        }
    }
}
