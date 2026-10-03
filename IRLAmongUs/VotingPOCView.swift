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
        .onAppear { OrientationDelegate.requestLandscape() }
        .onReceive(ticker) { _ in round.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { round.refresh() }
        }
    }

    private func tablet(compact: Bool) -> some View {
        VStack(spacing: compact ? 6 : 10) {
            HStack(spacing: 12) {
                Spacer(minLength: 44)
                Text(round.isFinished ? "Voting Results" : "Who Is The Impostor?")
                    .font(.system(size: compact ? 25 : 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 1, x: 1, y: 2)
                    .shadow(color: .black, radius: 1, x: -1, y: -1)
                    .lineLimit(1).minimumScaleFactor(0.65)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Image("VotingChat").resizable().scaledToFit().frame(width: 25, height: 28)
                    .accessibilityHidden(true)
                Button { dismiss() } label: {
                    Image("CloseMenuIcon").resizable().scaledToFit().frame(width: 28, height: 28)
                        .frame(width: 44, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Exit voting demo")
                .accessibilityIdentifier("voting.exit")
            }

            VStack(spacing: compact ? 5 : 8) {
                ForEach(0..<5, id: \.self) { row in
                    HStack(spacing: 16) {
                        playerCard(round.players[row * 2], compact: compact)
                        playerCard(round.players[row * 2 + 1], compact: compact)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)

            if round.isFinished {
                resultFooter
            } else {
                HStack(spacing: 8) {
                    Button { round.select(.skip) } label: {
                        Image("SkipVoteButton").resizable().scaledToFit()
                            .frame(width: 90, height: 30).frame(height: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(round.hasVoted)
                    .opacity(round.hasVoted ? 0.5 : 1)
                    .accessibilityLabel("Skip Vote")
                    .accessibilityIdentifier("voting.skip")
                    if round.selectedTarget == .skip { confirmationControls }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Voting Ends In: \(round.remainingSeconds)s")
                            .font(.system(size: compact ? 15 : 18, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(round.remainingSeconds <= 10 ? Color(red: 0.7, green: 0.1, blue: 0.13) : .black.opacity(0.8))
                            .accessibilityIdentifier("voting.countdown")
                        Text(round.hasVoted ? "Vote submitted · Waiting for the timer" : "You are Ben · \(round.votes.count)/9 have voted")
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

    private func playerCard(_ player: VotingPlayer, compact: Bool) -> some View {
        let target = VoteTarget.player(player.id)
        let selected = round.selectedTarget == target
        return HStack(spacing: 2) {
            Button { round.select(target) } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Image("VotingCrew\(player.colorIndex)").resizable().scaledToFit()
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
            .disabled(!player.isAlive || round.hasVoted || round.isFinished)
            .accessibilityLabel("\(player.name)\(player.isReporter ? ", reporter" : "")\(player.isAlive ? "" : ", dead")")
            .accessibilityIdentifier("voting.player.\(player.id)")

            if selected {
                confirmationControls.padding(.trailing, 4)
            } else if round.isFinished {
                HStack(spacing: 2) {
                    let voters = round.players.filter { round.votes[$0.id] == target }
                    ForEach(voters) { voter in
                        Circle().fill(votingColors[voter.colorIndex]).frame(width: 8, height: 8)
                            .overlay(Circle().stroke(.black.opacity(0.6), lineWidth: 0.7))
                    }
                    Text("\(round.tally[target, default: 0])")
                        .font(.system(size: 12, weight: .bold)).padding(.leading, 2)
                }
                .padding(.trailing, 10)
                .accessibilityLabel("\(round.tally[target, default: 0]) votes for \(player.name)")
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
            if round.votes[player.id] != nil {
                Image("VotingStamp").resizable().scaledToFit()
                    .frame(width: 25, height: 25).offset(x: -5, y: -5)
                    .allowsHitTesting(false)
                    .accessibilityLabel("\(player.name) has voted")
            }
        }
    }

    private var confirmationControls: some View {
        HStack(spacing: 0) {
            Button { round.confirmSelection() } label: {
                Image("VotingConfirm").resizable().scaledToFit()
                    .frame(width: 29, height: 29).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Confirm vote").accessibilityIdentifier("voting.confirm")
            Button { round.cancelSelection() } label: {
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
                Text("\(outcomeReason) · Skip: \(round.tally[.skip, default: 0]) · Abstained: \(9 - round.votes.count)")
                    .font(.system(size: 10, weight: .medium))
            }
            Spacer(minLength: 0)
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
        }
        .frame(height: 44)
        .font(.system(size: 14, weight: .bold, design: .rounded))
        .buttonStyle(.plain)
        .controlSize(.regular)
    }

    private var outcomeTitle: String {
        if case .ejected(let id) = round.outcome {
            return "\(round.players.first { $0.id == id }?.name ?? id) was ejected."
        }
        return "No one was ejected."
    }

    private var outcomeReason: String {
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
