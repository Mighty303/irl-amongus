import Foundation
import Testing
@testable import IRLAmongUs

struct IRLAmongUsTests {
    @MainActor
    @Test func appStartsWithContentView() {
        _ = ContentView()
    }
}

@MainActor
struct VotingRoundTests {
    private func round(clock: TestClock, bots: Bool = false) -> VotingRound {
        VotingRound(simulatesBots: bots, clock: { clock.now })
    }

    @Test func selectionCancellationAndConfirmation() {
        let clock = TestClock()
        let model = round(clock: clock)
        model.select(.player("dale"))
        #expect(model.selectedTarget == .player("dale"))
        #expect(model.votes.isEmpty)
        model.cancelSelection()
        #expect(model.selectedTarget == nil)
        model.select(.player("lars"))
        model.confirmSelection()
        #expect(model.votes["ben"] == .player("lars"))
        #expect(model.selectedTarget == nil)
        model.select(.skip)
        model.confirmSelection()
        #expect(model.votes["ben"] == .player("lars"))
    }

    @Test func skipAndInvalidVotes() {
        let clock = TestClock()
        let model = round(clock: clock)
        model.select(.player("kai"))
        #expect(model.selectedTarget == nil)
        #expect(!model.castVote(by: "kai", for: .skip))
        #expect(!model.castVote(by: "missing", for: .skip))
        #expect(!model.castVote(by: "stan", for: .player("missing")))
        model.select(.skip)
        model.confirmSelection()
        #expect(model.votes["ben"] == .skip)
        #expect(!model.castVote(by: "ben", for: .player("dale")))
    }

    @Test func deadlineAndAbstention() {
        let clock = TestClock()
        let model = round(clock: clock)
        clock.now += 59
        model.refresh()
        #expect(model.remainingSeconds == 1)
        model.select(.player("dale"))
        clock.now += 1
        model.confirmSelection()
        #expect(model.remainingSeconds == 0)
        #expect(model.votes.isEmpty)
        #expect(model.outcome == .noVotes)
        #expect(model.selectedTarget == nil)
        #expect(!model.castVote(by: "stan", for: .skip))
    }

    @Test func botScheduleAndBackgroundJump() {
        let clock = TestClock()
        let model = round(clock: clock, bots: true)
        clock.now += 5
        model.refresh()
        #expect(model.votes.isEmpty)
        clock.now += 1
        model.refresh()
        #expect(model.votes.count == 1)
        model.refresh()
        #expect(model.votes.count == 1)
        model.select(.player("dale"))
        model.confirmSelection()
        clock.now += 100
        model.refresh()
        #expect(model.votes.count == 9)
        #expect(model.outcome == .ejected("dale"))
        #expect(model.remainingSeconds == 0)
        model.refresh()
        #expect(model.votes.count == 9)
    }

    @Test func allVotesStillWaitForDeadlineAndReplayResets() {
        let clock = TestClock()
        let model = round(clock: clock, bots: true)
        model.select(.skip)
        model.confirmSelection()
        clock.now += 49
        model.refresh()
        #expect(model.votes.count == 9)
        #expect(!model.isFinished)
        clock.now += 11
        model.refresh()
        #expect(model.outcome == .tie)
        model.restart()
        #expect(model.votes.isEmpty)
        #expect(model.remainingSeconds == 60)
        #expect(model.outcome == nil)
        #expect(model.selectedTarget == nil)
        #expect(model.deadline == clock.now.addingTimeInterval(60))
        clock.now += 6
        model.refresh()
        #expect(model.votes.count == 1)
    }

    @Test func resolutionCases() {
        #expect(VotingRound.resolve(votes: []) == .noVotes)
        #expect(VotingRound.resolve(votes: [.skip, .skip, .player("dale")]) == .skipped)
        #expect(VotingRound.resolve(votes: [.skip, .player("dale")]) == .tie)
        #expect(VotingRound.resolve(votes: [.player("dale"), .player("lars")]) == .tie)
        #expect(VotingRound.resolve(votes: [.player("dale"), .player("dale"), .skip]) == .ejected("dale"))
    }
}

@MainActor
private final class TestClock {
    var now = Date(timeIntervalSince1970: 1_000)
}
