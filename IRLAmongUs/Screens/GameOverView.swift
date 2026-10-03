import SwiftUI

struct GameOverView: View {
    @Environment(GameStore.self) private var store
    let state: GameState

    var body: some View {
        let crewWon = state.winner == "crewmates"
        NavigationStack {
            List {
                Section {
                    Text(crewWon ? "CREWMATES WIN" : "IMPOSTORS WIN")
                        .font(.system(size: 40, weight: .black))
                        .foregroundStyle(crewWon ? .cyan : .red)
                    if let reason = state.winReason { Text(reason) }
                    Text("\(state.taskProgress.done) / \(state.taskProgress.total) tasks completed").font(.caption)
                }
                Section("Roles") {
                    ForEach(state.players) { p in
                        HStack {
                            Text(p.name)
                            Spacer()
                            Text(p.role == .impostor ? "Impostor" : "Crewmate").foregroundStyle(p.role == .impostor ? .red : .cyan)
                            Text(p.alive ? "" : (p.ejected ? "🚀" : "💀"))
                        }
                    }
                }
                Section {
                    if state.isHost {
                        Button("Play again (back to lobby)") { Task { await store.perform("restart") } }
                    } else {
                        Text("Waiting for the host to start a new round…").foregroundStyle(.secondary)
                    }
                    Button("Leave", role: .destructive) { store.leave() }
                }
            }
            .navigationTitle("Game over")
        }
    }
}
