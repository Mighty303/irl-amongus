import SwiftUI

struct RoleRevealView: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var revealed = false
    @StateObject private var revealAudio = RoleRevealAudioPlayer()

    var body: some View {
        VStack(spacing: 24) {
            if state.me.ackedRole {
                ProgressView()
                Text("Waiting for everyone to see their role…")
                Countdown(deadline: state.phaseDeadline, font: .title.monospaced())
            } else if !revealed {
                Text("Make sure nobody can see your screen").font(.title2).multilineTextAlignment(.center)
                Button("Reveal my role") {
                    revealed = true
                    revealAudio.play()
                }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            } else {
                let impostor = state.me.role == .impostor
                Text(impostor ? "IMPOSTOR" : "CREWMATE")
                    .font(.system(size: 52, weight: .black))
                    .foregroundStyle(impostor ? .red : .cyan)
                Text(impostor ? "Kill crewmates without getting caught. Fake your tasks." : "Complete your tasks and find the impostor.")
                    .multilineTextAlignment(.center)
                let partners = state.players.filter { $0.role == .impostor && $0.id != state.me.id }
                if impostor && !partners.isEmpty {
                    Text("Fellow impostors: \(partners.map(\.name).joined(separator: ", "))").foregroundStyle(.red)
                }
                Button("Got it") { Task { await store.perform("ack_role") } }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
        }
        .padding(32)
        .onDisappear { revealAudio.stop() }
    }
}
