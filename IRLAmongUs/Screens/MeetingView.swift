import SwiftUI

/// MEETING (gathering -> discussion), VOTING and RESULT phases.
struct MeetingView: View {
    @Environment(GameStore.self) private var store
    let state: GameState
    @State private var scanning = false

    /// Where everyone gathers: the meeting point, or the red button when there's no separate one (as on the server).
    private var meetingStation: Station? {
        state.stations.first { $0.kind == .meeting } ?? state.stations.first { $0.kind == .emergency }
    }

    var body: some View {
        NavigationStack {
            List {
                header
                switch state.phase {
                case .MEETING where state.meeting?.stage == "gathering": gathering
                case .MEETING: discussion
                case .VOTING: voting
                case .RESULT: result
                default: EmptyView()
                }
                Section("Players") {
                    ForEach(state.players) { p in
                        HStack {
                            Text(p.alive ? "🙂" : (p.ejected ? "🚀" : "💀"))
                            Text(p.name).strikethrough(!p.alive)
                            Spacer()
                            if state.phase == .MEETING, state.meeting?.arrived.contains(p.id) == true { Text("arrived").font(.caption) }
                            if p.hasVoted { Text("voted").font(.caption.bold()) }
                        }
                    }
                }
                if state.isHost && state.phase != .RESULT {
                    Section { Button("Host: skip ahead") { Task { await store.perform("host_advance") } } }
                }
            }
            .navigationTitle(state.phase == .VOTING ? "Vote" : "Meeting")
        }
        .overlay {
            // Same sign scanner as tasks in the HUD: checks you in at the meeting point, then closes.
            if scanning {
                SignScanPanel(state: state, target: meetingStation) { scanning = false }
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: scanning)
    }

    @ViewBuilder private var header: some View {
        if let m = state.meeting {
            Section {
                Text(m.kind == "body" ? "🚨 BODY REPORTED" : "🚨 EMERGENCY MEETING").font(.title.weight(.black))
                if let body = state.player(m.bodyId) { Text("\(body.name) was found dead") }
                if m.kind == "body" {
                    Text(state.player(m.calledBy).map { "Reported by \($0.name)" } ?? "Reported at the body").font(.caption)
                } else if let caller = state.player(m.calledBy) {
                    Text("Called by \(caller.name)").font(.caption)
                }
            }
        }
        if !state.me.alive {
            Section { Text("👻 You're dead. Watch, but don't talk or vote.").foregroundStyle(.secondary) }
        }
    }

    @ViewBuilder private var gathering: some View {
        let living = state.alivePlayers.count
        let arrived = state.meeting?.arrived.count ?? 0
        Section("Return to \(meetingStation?.name ?? "the meeting area")") {
            Text("\(arrived) / \(living) arrived").font(.title2.bold())
            HStack { Text("Starts anyway in"); Countdown(deadline: state.phaseDeadline, font: .body.monospaced()) }
            if state.me.alive && state.meeting?.arrived.contains(state.me.id) != true {
                Button("📷 Check in at meeting point") { scanning = true }.buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder private var discussion: some View {
        Section {
            Text("DISCUSSION").font(.headline)
            Countdown(deadline: state.phaseDeadline)
            Text("Talk it out in person. Voting opens when the timer ends.").font(.caption)
        }
    }

    @ViewBuilder private var voting: some View {
        Section {
            HStack { Text("VOTING").font(.headline); Spacer(); Countdown(deadline: state.phaseDeadline, font: .title2.monospaced()) }
        }
        if state.me.alive && !state.me.hasVoted {
            Section("Who is the impostor?") {
                ForEach(state.alivePlayers) { p in
                    Button(p.name + (p.id == state.me.id ? " (you)" : "")) { vote(p.id) }
                }
                Button("Skip vote") { vote(nil) }.foregroundStyle(.secondary)
            }
        } else if state.me.hasVoted {
            Section { Text("You voted for \(state.player(state.me.voteTarget)?.name ?? "skip"). Waiting for others…") }
        }
    }

    @ViewBuilder private var result: some View {
        if let r = state.result {
            Section("Voting results") {
                ForEach(r.tallies, id: \.targetId) { t in
                    VStack(alignment: .leading) {
                        Text("\(state.player(t.targetId)?.name ?? "Skip") — \(t.count)")
                        if let voters = t.voterIds {
                            Text("by " + voters.compactMap { state.player($0)?.name }.joined(separator: ", ")).font(.caption)
                        }
                    }
                }
            }
            Section {
                if let ejected = state.player(r.ejectedId) {
                    Text("\(ejected.name) was ejected.").font(.title2.bold())
                    if let wasImpostor = r.ejectedWasImpostor {
                        Text(wasImpostor ? "\(ejected.name) was the Impostor." : "\(ejected.name) was NOT the Impostor.")
                    }
                } else {
                    Text(r.tie ? "Tie. No one was ejected." : "No one was ejected (skipped).").font(.title2.bold())
                }
                HStack { Text("Back to the game in"); Countdown(deadline: state.phaseDeadline, font: .body.monospaced()) }
            }
        }
    }

    private func vote(_ targetId: String?) {
        Task { await store.perform("vote", ["targetId": targetId as Any? ?? NSNull()]) }
    }
}
