import SwiftUI

/// Uses the server's available targets in a game, or previews the action without a session.
struct MapKillButton: View {
    @Environment(GameStore.self) private var store
    let state: GameState?
    var size: CGFloat = 96
    @StateObject private var audio = KillAudioPlayer()
    @State private var choosingTarget = false
    @State private var submitting = false
    @State private var previewCooldown: Date?
    @State private var previewKill: KillPresentation?

    private var targets: [PlayerView] {
        guard let state else { return [] }
        return state.me.killTargets.compactMap { state.player($0) }.filter { $0.alive && $0.id != state.me.id }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
            let cooldown = state.map { store.secondsUntil($0.me.killCooldownUntil) ?? 0 }
                ?? Int(ceil(max(0, previewCooldown?.timeIntervalSince(timeline.date) ?? 0)))
            let available = cooldown == 0 && !submitting && (state == nil ||
                (state?.phase == .PLAYING && state?.me.alive == true && store.isSynced && !targets.isEmpty))
            Button {
                guard available else { return }
                if state == nil {
                    audio.play()
                    previewKill = KillPresentation(victimID: "preview", attackerColor: .red, victimColor: .green)
                    previewCooldown = .now.addingTimeInterval(10)
                } else if targets.count == 1, let target = targets.first {
                    kill(target)
                } else {
                    choosingTarget = true
                }
            } label: {
                ZStack {
                    Image("KillIcon").resizable().scaledToFit()
                        .frame(width: size, height: size)
                        .opacity(available ? 1 : 0.4)
                    if cooldown > 0 {
                        Text("\(cooldown)")
                            .font(.system(size: size / 3, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                            .shadow(color: .black, radius: 2)
                    } else if submitting {
                        ProgressView().tint(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!available)
            .accessibilityLabel("Kill")
            .accessibilityValue(cooldown > 0 ? "Cooldown \(cooldown) seconds" : available ? "Ready" : "No players in range")
            .accessibilityIdentifier("map.kill")
        }
        .confirmationDialog("Choose a player", isPresented: $choosingTarget, titleVisibility: .visible) {
            ForEach(targets) { target in
                Button("Kill \(target.name)", role: .destructive) { kill(target) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onDisappear { audio.stop() }
        .fullScreenCover(item: $previewKill) { presentation in
            KillAnimationView(presentation: presentation) { previewKill = nil }
                .interactiveDismissDisabled()
        }
    }

    private func kill(_ target: PlayerView) {
        guard !submitting, store.isSynced, state?.phase == .PLAYING,
              state?.me.role == .impostor, state?.me.alive == true,
              (store.secondsUntil(state?.me.killCooldownUntil) ?? 0) == 0,
              targets.contains(where: { $0.id == target.id }) else { return }
        submitting = true
        Task {
            await store.perform("kill", ["targetId": target.id])
            submitting = false
        }
    }
}
