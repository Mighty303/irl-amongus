import Combine
import Foundation

struct VotingPlayer: Identifiable, Equatable {
    let id: String
    let name: String
    let colorIndex: Int
    var isAlive = true
    var isReporter = false
}

enum VoteTarget: Hashable {
    case player(String)
    case skip
}

enum VotingOutcome: Equatable {
    case ejected(String)
    case skipped
    case tie
    case noVotes
}

/// A local simulation. UI refreshes never determine how much time has elapsed.
@MainActor
final class VotingRound: ObservableObject {
    static let mockPlayers: [VotingPlayer] = [
        .init(id: "ben", name: "Ben", colorIndex: 0, isReporter: true),
        .init(id: "notblobz", name: "NotBlobz", colorIndex: 1),
        .init(id: "stan", name: "Stan", colorIndex: 2),
        .init(id: "trikao", name: "Trikao", colorIndex: 3),
        .init(id: "nobeans", name: "NoBeans", colorIndex: 4),
        .init(id: "lars", name: "Lars", colorIndex: 5),
        .init(id: "rat", name: "Rat", colorIndex: 6),
        .init(id: "dale", name: "Dale", colorIndex: 7),
        .init(id: "wadlet", name: "Wadlet", colorIndex: 8),
        .init(id: "kai", name: "Kai", colorIndex: 9, isAlive: false)
    ]

    let players: [VotingPlayer]
    let localPlayerID: String
    let duration: TimeInterval
    private let clock: () -> Date
    private let simulatesBots: Bool
    private(set) var deadline: Date
    private var startedAt: Date

    @Published private(set) var selectedTarget: VoteTarget?
    @Published private(set) var votes: [String: VoteTarget] = [:]
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var outcome: VotingOutcome?

    var hasVoted: Bool { votes[localPlayerID] != nil }
    var isFinished: Bool { outcome != nil }
    var tally: [VoteTarget: Int] { votes.values.reduce(into: [:]) { $0[$1, default: 0] += 1 } }

    init(duration: TimeInterval = 60, players: [VotingPlayer] = VotingRound.mockPlayers,
         localPlayerID: String = "ben", simulatesBots: Bool = true,
         clock: @escaping () -> Date = Date.init) {
        self.duration = duration
        self.players = players
        self.localPlayerID = localPlayerID
        self.simulatesBots = simulatesBots
        self.clock = clock
        let now = clock()
        startedAt = now
        deadline = now.addingTimeInterval(duration)
        remainingSeconds = Int(ceil(duration))
    }

    func select(_ target: VoteTarget) {
        refresh()
        guard !isFinished, !hasVoted, valid(target) else { return }
        selectedTarget = target
    }

    func cancelSelection() { selectedTarget = nil }

    func confirmSelection() {
        refresh()
        guard let target = selectedTarget else { return }
        _ = castVote(by: localPlayerID, for: target)
    }

    @discardableResult
    func castVote(by voterID: String, for target: VoteTarget) -> Bool {
        refresh()
        guard !isFinished, votes[voterID] == nil,
              players.contains(where: { $0.id == voterID && $0.isAlive }), valid(target) else { return false }
        votes[voterID] = target
        if voterID == localPlayerID { selectedTarget = nil }
        return true
    }

    func refresh() {
        guard !isFinished else { return }
        let now = clock()
        if simulatesBots {
            // Three votes each for Dale and Lars, two skips. The local vote can break the tie.
            let targets: [VoteTarget] = [.player("dale"), .player("lars"), .skip,
                                         .player("dale"), .player("lars"), .skip,
                                         .player("dale"), .player("lars")]
            let bots = players.filter { $0.isAlive && $0.id != localPlayerID }
            for (index, bot) in bots.enumerated() {
                let castAt = startedAt.addingTimeInterval(duration * Double(index + 1) / Double(bots.count + 2))
                let target = targets[index % targets.count]
                if now >= castAt && votes[bot.id] == nil && valid(target) {
                    votes[bot.id] = target
                }
            }
        }
        remainingSeconds = max(0, Int(ceil(deadline.timeIntervalSince(now))))
        if now >= deadline {
            selectedTarget = nil
            outcome = Self.resolve(votes: Array(votes.values))
        }
    }

    func restart() {
        let now = clock()
        startedAt = now
        deadline = now.addingTimeInterval(duration)
        votes = [:]
        selectedTarget = nil
        outcome = nil
        remainingSeconds = Int(ceil(duration))
    }

    private func valid(_ target: VoteTarget) -> Bool {
        switch target {
        case .skip: return true
        case .player(let id): return players.contains { $0.id == id && $0.isAlive }
        }
    }

    static func resolve(votes: [VoteTarget]) -> VotingOutcome {
        let counts = votes.reduce(into: [VoteTarget: Int]()) { $0[$1, default: 0] += 1 }
        guard let maximum = counts.values.max() else { return .noVotes }
        let winners = counts.filter { $0.value == maximum }.map(\.key)
        guard winners.count == 1, let winner = winners.first else { return .tie }
        switch winner {
        case .skip: return .skipped
        case .player(let id): return .ejected(id)
        }
    }
}
