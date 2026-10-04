import SwiftUI

private let votingColors: [Color] = [
    Color(red: 0.89, green: 0.35, blue: 0.72), Color(red: 0.81, green: 0.12, blue: 0.18),
    Color(red: 0.46, green: 0.25, blue: 0.75), Color(red: 0.15, green: 0.27, blue: 0.82),
    Color(red: 0.36, green: 0.88, blue: 0.19), Color(red: 0.06, green: 0.49, blue: 0.27),
    Color(red: 0.49, green: 0.34, blue: 0.22), Color(red: 0.97, green: 0.51, blue: 0.12),
    Color(red: 0.95, green: 0.88, blue: 0.22), Color(red: 0.43, green: 0.48, blue: 0.50)
]

struct VotingPOCView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var round = VotingRound(duration: Self.demoDuration)
    var liveState: GameState? = nil
    var secondsRemaining: () -> Int = { 0 }
    var submitVote: (VoteTarget) async -> Bool = { _ in false }
    var checkIn: () -> Void = {}
    var advance: () -> Void = {}
    /// Everyone's at the meeting point: start the discussion timer now instead of waiting for every check-in.
    var startDiscussion: () -> Void = {}
    @State private var liveSelection: VoteTarget?
    @State private var submitting = false
    @State private var acceptedVote = false
    @State private var liveSeconds = 0

    private var players: [VotingPlayer] {
        guard let state = liveState else { return round.players }
        return state.players.enumerated().map { index, player in
            VotingPlayer(id: player.id, name: player.name, colorIndex: index % votingColors.count,
                         isAlive: player.alive, isReporter: state.meeting?.kind == "body" && state.meeting?.calledBy == player.id)
        }
    }
    private var hasVoted: Bool { liveState?.me.hasVoted ?? round.hasVoted }
    private var isFinished: Bool { liveState.map { $0.phase == .RESULT } ?? round.isFinished }
    private var selectedTarget: VoteTarget? { liveState == nil ? round.selectedTarget : liveSelection }
    private var canVote: Bool {
        if let state = liveState { return state.phase == .VOTING && state.me.alive && !hasVoted && !acceptedVote && !submitting && liveSeconds > 0 }
        return !round.isFinished && !round.hasVoted
    }
    private var voteCount: Int { liveState?.players.filter(\.hasVoted).count ?? round.votes.count }
    private var livingCount: Int { players.filter { $0.isAlive || $0.id == liveState?.result?.ejectedId }.count }
    private var remaining: Int { liveState == nil ? round.remainingSeconds : liveSeconds }
    private var title: String {
        guard let state = liveState else { return isFinished ? "Voting Results" : "Who Is The Impostor?" }
        if isFinished { return "Voting Results" }
        if state.phase == .VOTING { return "Who Is The Impostor?" }
        return state.meeting?.kind == "body" ? "Body Reported" : "Emergency Meeting"
    }
    private var status: String {
        guard let state = liveState else { return hasVoted ? "Vote submitted · Waiting for the timer" : "You are Ben · \(voteCount)/\(livingCount) have voted" }
        if !state.me.alive { return "You are dead · Watch, but don't talk or vote" }
        if submitting { return "Submitting vote…" }
        if hasVoted || acceptedVote { return "Vote submitted · Waiting for others" }
        if state.phase == .MEETING {
            if state.meeting?.stage == "gathering" {
                let station = (state.stations.first { $0.kind == .meeting } ?? state.stations.first { $0.kind == .emergency })?.name ?? "the meeting area"
                return "Return to \(station) · \(state.meeting?.arrived.count ?? 0)/\(livingCount) arrived"
            }
            return "Discuss in person · Voting opens when the timer ends"
        }
        return "You are \(state.me.name) · \(voteCount)/\(livingCount) have voted"
    }
    private func liveColor(for id: String) -> PlayerColor? {
        guard let state = liveState, let index = state.players.firstIndex(where: { $0.id == id }) else { return nil }
        return state.players[index].color ?? PlayerColor.allCases[index % PlayerColor.allCases.count]
    }

    private func refresh() {
        guard let state = liveState else { round.refresh(); return }
        let seconds = secondsRemaining()
        // The vote timer ticks through the last ten seconds of voting.
        if state.phase == .VOTING, seconds != liveSeconds, (1...10).contains(seconds) { GameSoundEffect.voteTimer.play() }
        liveSeconds = seconds
    }
    private func select(_ target: VoteTarget) {
        if liveState == nil { round.select(target) } else if canVote { liveSelection = target }
    }
    private func tally(_ target: VoteTarget) -> Int {
        guard let state = liveState else { return round.tally[target, default: 0] }
        let id: String? = if case .player(let id) = target { id } else { nil }
        return state.result?.tallies.first { $0.targetId == id }?.count ?? 0
    }
    private func voted(_ id: String) -> Bool {
        liveState?.player(id)?.hasVoted ?? (round.votes[id] != nil)
    }
    private let ticker = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    private static var demoDuration: TimeInterval {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-votingTestDuration"),
           arguments.indices.contains(index + 1), let value = Double(arguments[index + 1]),
           value.isFinite, value >= 1, value <= 60 { return value }
#endif
        return 60
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [Color(white: 0.08), Color(red: 0.08, green: 0.16, blue: 0.17)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                tablet(compact: geometry.size.height < 420)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: 1_100)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.light)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear { OrientationDelegate.requestLandscape(); refresh() }
        .onChange(of: liveState) { _, state in
            refresh()
            if state?.phase != .VOTING || state?.me.hasVoted == true { liveSelection = nil }
            if state?.phase == .MEETING { acceptedVote = false }
        }
        .onReceive(ticker) { _ in refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
    }

    private func tablet(compact: Bool) -> some View {
        VStack(spacing: compact ? 6 : 10) {
            HStack(spacing: 12) {
                Spacer(minLength: 44)
                Text(title)
                    .font(.system(size: compact ? 25 : 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 1, x: 1, y: 2)
                    .shadow(color: .black, radius: 1, x: -1, y: -1)
                    .lineLimit(1).minimumScaleFactor(0.65)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Image("VotingChat").resizable().scaledToFit().frame(width: 25, height: 28)
                    .accessibilityHidden(true)
                if liveState == nil {
                    Button { dismiss() } label: {
                        Image("CloseMenuIcon").resizable().scaledToFit().frame(width: 28, height: 28)
                            .frame(width: 44, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Exit voting demo")
                    .accessibilityIdentifier("voting.exit")
                }
            }

            if let state = liveState, let meeting = state.meeting {
                Text([state.player(meeting.bodyId).map { "\($0.name) was found dead" },
                      state.player(meeting.calledBy).map { "Called by \($0.name)" }]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption.bold()).lineLimit(1)
            }

            if liveState != nil && players.count > 10 {
                ScrollView { playerGrid(compact: compact, scrolling: true) }
            } else {
                playerGrid(compact: compact, scrolling: false)
            }

            if isFinished {
                resultFooter
            } else {
                HStack(spacing: 8) {
                    Button { select(.skip) } label: {
                        Image("SkipVoteButton").resizable().scaledToFit()
                            .frame(width: 90, height: 30).frame(height: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canVote)
                    .opacity(canVote ? 1 : 0.5)
                    .accessibilityLabel("Skip Vote")
                    .accessibilityIdentifier("voting.skip")
                    if let state = liveState, state.phase == .MEETING {
                        if state.meeting?.stage == "gathering", state.me.alive,
                           state.meeting?.arrived.contains(state.me.id) != true {
                            Button("Check in") { checkIn() }.buttonStyle(.borderedProminent)
                        }
                        if state.meeting?.stage == "gathering", state.me.alive {
                            Button("Everyone's here · Start") { startDiscussion() }
                                .buttonStyle(.borderedProminent)
                                .tint(Color(red: 0.2, green: 0.62, blue: 0.36))
                                .accessibilityIdentifier("meeting.startDiscussion")
                        }
                    }
                    if liveState?.isHost == true { Button("Skip ahead") { advance() } }
                    if selectedTarget == .skip { confirmationControls }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(liveState?.phase == .MEETING ? "Meeting" : "Voting") Ends In: \(remaining)s")
                            .font(.system(size: compact ? 15 : 18, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(remaining <= 10 ? Color(red: 0.7, green: 0.1, blue: 0.13) : .black.opacity(0.8))
                            .accessibilityIdentifier("voting.countdown")
                        Text(status)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.black.opacity(0.6))
                            .accessibilityIdentifier("voting.status")
                    }
                }
            }
        }
        .foregroundStyle(Color(red: 0.15, green: 0.20, blue: 0.23))
        .padding(compact ? 8 : 12)
        .background { Image("VotingGlass").resizable() }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.init(top: 8, leading: 12, bottom: 8, trailing: 28))
        .background {
            Image("VotingTablet")
                .resizable(capInsets: .init(top: 16, leading: 16, bottom: 16, trailing: 28))
        }
        .overlay(alignment: .trailing) {
            Image("VotingTabletHome").resizable().scaledToFit()
                .frame(width: 18, height: 18).padding(.trailing, 5)
                .accessibilityHidden(true)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.65), radius: 12, y: 6)
    }

    private func playerGrid(compact: Bool, scrolling: Bool) -> some View {
        VStack(spacing: compact ? 5 : 8) {
            ForEach(0..<max(1, (players.count + 1) / 2), id: \.self) { row in
                HStack(spacing: 16) {
                    if row * 2 < players.count { playerCard(players[row * 2], compact: compact) }
                    if row * 2 + 1 < players.count { playerCard(players[row * 2 + 1], compact: compact) }
                    else { Color.clear.frame(maxWidth: .infinity) }
                }
                .frame(minHeight: scrolling ? 52 : nil, maxHeight: .infinity)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func playerCard(_ player: VotingPlayer, compact: Bool) -> some View {
        let target = VoteTarget.player(player.id)
        let selected = selectedTarget == target
        return HStack(spacing: 2) {
            Button { select(target) } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Image(liveColor(for: player.id)?.lobbyAssetName ?? "VotingCrew\(player.colorIndex)").resizable().scaledToFit()
                            .frame(width: compact ? 28 : 34, height: compact ? 30 : 36)
                        if !player.isAlive {
                            Image("VotingDeadCross").resizable().scaledToFit().frame(width: 34, height: 34)
                        }
                    }
                    Text(player.name)
                        .font(.system(size: compact ? 17 : 21, weight: .bold, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.65)
                    Spacer(minLength: 0)
                    if player.isReporter {
                        Image("VotingReporter").resizable().scaledToFit().frame(width: 28, height: 26)
                    }
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(VotingCardButtonStyle())
            .disabled(!player.isAlive || !canVote)
            .accessibilityLabel("\(player.name)\(player.isReporter ? ", reporter" : "")\(player.isAlive ? "" : ", dead")")
            .accessibilityIdentifier("voting.player.\(player.id)")

            if selected {
                confirmationControls.padding(.trailing, 4)
            } else if isFinished {
                HStack(spacing: 2) {
                    let voters = players.filter { player in
                        if let state = liveState { return !state.settings.anonymousVotes && (state.result?.tallies.first { $0.targetId == playerID(target) }?.voterIds?.contains(player.id) == true) }
                        return round.votes[player.id] == target
                    }
                    ForEach(voters) { voter in
                        Circle().fill(liveColor(for: voter.id)?.swatch ?? votingColors[voter.colorIndex]).frame(width: 8, height: 8)
                            .overlay(Circle().stroke(.black.opacity(0.6), lineWidth: 0.7))
                    }
                    Text("\(tally(target))")
                        .font(.system(size: 12, weight: .bold)).padding(.leading, 2)
                }
                .padding(.trailing, 10)
                .accessibilityLabel("\(tally(target)) votes for \(player.name)")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Image("VotingPlayerCard")
                .resizable(capInsets: .init(top: 4, leading: 4, bottom: 4, trailing: 4))
                .colorMultiply(player.isAlive ? .white : Color(white: 0.56))
        }
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(selected ? Color.green.opacity(0.8) : .clear, lineWidth: 2))
        .overlay(alignment: .topLeading) {
            if voted(player.id) {
                Image("VotingStamp").resizable().scaledToFit()
                    .frame(width: 25, height: 25).offset(x: -5, y: -5)
                    .allowsHitTesting(false)
                    .accessibilityLabel("\(player.name) has voted")
            }
        }
    }

    private var confirmationControls: some View {
        HStack(spacing: 0) {
            Button {
                if liveState == nil { round.confirmSelection() }
                else if canVote, let target = liveSelection {
                    submitting = true
                    Task {
                        let accepted = await submitVote(target)
                        submitting = false
                        if accepted { liveSelection = nil; acceptedVote = true }
                    }
                }
            } label: {
                Image("VotingConfirm").resizable().scaledToFit()
                    .frame(width: 29, height: 29).frame(width: 44, height: 44)
            }
            .disabled(!canVote)
            .accessibilityLabel("Confirm vote").accessibilityIdentifier("voting.confirm")
            Button { if liveState == nil { round.cancelSelection() } else { liveSelection = nil } } label: {
                Image("VotingCancel").resizable().scaledToFit()
                    .frame(width: 29, height: 29).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Cancel vote").accessibilityIdentifier("voting.cancel")
        }
        .buttonStyle(.plain)
    }

    private var resultFooter: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(outcomeTitle).font(.system(size: 17, weight: .bold, design: .rounded))
                    .accessibilityIdentifier("voting.result")
                Text("\(outcomeReason) · Skip: \(tally(.skip)) · Abstained: \(max(0, livingCount - voteCount))")
                    .font(.system(size: 10, weight: .medium))
            }
            Spacer(minLength: 0)
            if liveState == nil {
                Button { round.restart() } label: {
                    Image("PlayAgainActionIcon").resizable().scaledToFit().frame(width: 44, height: 44)
                }
                .accessibilityLabel("Play Again")
                .accessibilityIdentifier("voting.replay")
                Button { dismiss() } label: {
                    Image("CloseMenuIcon").resizable().scaledToFit().frame(width: 32, height: 32)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Exit")
                .accessibilityIdentifier("voting.resultExit")
            } else { Text("Back to game in \(remaining)s").font(.caption.monospacedDigit()) }
        }
        .frame(height: 44)
        .font(.system(size: 14, weight: .bold, design: .rounded))
        .buttonStyle(.plain)
        .controlSize(.regular)
    }

    private func playerID(_ target: VoteTarget) -> String? {
        if case .player(let id) = target { return id }
        return nil
    }

    private var outcomeTitle: String {
        if let state = liveState {
            return state.player(state.result?.ejectedId).map { "\($0.name) was ejected." } ?? "No one was ejected."
        }
        if case .ejected(let id) = round.outcome {
            return "\(round.players.first { $0.id == id }?.name ?? id) was ejected."
        }
        return "No one was ejected."
    }

    private var outcomeReason: String {
        if let state = liveState {
            if let result = state.result, let impostor = result.ejectedWasImpostor,
               let player = state.player(result.ejectedId) {
                return "\(player.name) was \(impostor ? "the Impostor" : "NOT the Impostor")"
            }
            if state.result?.ejectedId != nil { return "Most votes" }
            return state.result?.tie == true ? "Tie" : "Vote skipped"
        }
        switch round.outcome {
        case .ejected: return "Most votes"
        case .skipped: return "Vote skipped"
        case .tie: return "Tie"
        case .noVotes: return "No votes cast"
        case nil: return ""
        }
    }
}

private struct VotingCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.8 : 1)
    }
}

#Preview { VotingPOCView() }
