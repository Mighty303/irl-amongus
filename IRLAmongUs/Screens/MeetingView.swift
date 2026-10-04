import SwiftUI

/// Uses the voting tablet for the server's gathering, discussion, voting and result phases.
struct MeetingView: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var scanning = false

    /// Where everyone gathers: the meeting point, or the red button when there's no separate one (as on the server).
    private var meetingStation: Station? {
        state.stations.first { $0.kind == .meeting } ?? state.stations.first { $0.kind == .emergency }
    }

    var body: some View {
        VotingPOCView(liveState: state,
                      secondsRemaining: { store.secondsUntil(state.phaseDeadline) ?? 0 },
                      submitVote: { target in
                          let id: String? = if case .player(let id) = target { id } else { nil }
                          return await store.perform("vote", ["targetId": id as Any? ?? NSNull()])
                      },
                      checkIn: { scanning = true },
                      advance: { Task { await store.perform("host_advance") } })
            .overlay {
                if scanning {
                    SignScanPanel(state: state, target: meetingStation) {
                        scanning = false
                    }
                }
            }
            .onChange(of: state.phase) { _, _ in scanning = false }
    }
}
