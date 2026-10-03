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

@MainActor
struct LocalServerLobbyTests {
    private func makeStore(host: String = "success") -> GameStore {
        let defaults = UserDefaults(suiteName: "LocalServerLobbyTests.\(UUID().uuidString)")!
        defaults.set("http://\(host).invalid", forKey: "serverURL")
        defaults.set("  Ben  ", forKey: "playerName")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LobbyHTTPStub.self]
        return GameStore(defaults: defaults, httpSession: URLSession(configuration: configuration), restoresSession: false)
    }

    @Test func keepsHostedDefaultAndMigratesStaleAddresses() {
        let defaults = UserDefaults(suiteName: "LocalServerLobbyTests.\(UUID().uuidString)")!
        #expect(GameStore(defaults: defaults, restoresSession: false).serverURLString == GameStore.defaultServerURL)
        for address in ["http://192.168.1.100:3000", "https://old-demo.trycloudflare.com"] {
            defaults.set(address, forKey: "serverURL")
            #expect(GameStore(defaults: defaults, restoresSession: false).serverURLString == GameStore.defaultServerURL)
        }
        defaults.set("http://192.168.1.20:3000", forKey: "serverURL")
        #expect(GameStore(defaults: defaults, restoresSession: false).serverURLString == "http://192.168.1.20:3000")
    }

    @Test func validatesServerAndRoomCode() {
        #expect(GameStore.validatedServerURL(" http://192.168.1.10:3000/ ")?.absoluteString == "http://192.168.1.10:3000")
        #expect(GameStore.validatedServerURL("example.com")?.scheme == "https")
        for url in ["", "ftp://example.com", "http://", "http://example.com?token=abc", "http://user:pass@example.com"] {
            #expect(GameStore.validatedServerURL(url) == nil)
        }
        #expect(GameStore.isValidRoomCode(" ab12\n"))
        for code in ["", "AB", "ABCDE", "A/BC", "éABC"] { #expect(!GameStore.isValidRoomCode(code)) }
    }

    @Test func createsAndLeavesRealSession() async {
        let store = makeStore()
        #expect(store.canEnterLobby)
        await store.createGame()
        #expect(store.session == Session(code: "ABCD", playerId: "ben", token: "test-token"))
        #expect(!store.canEnterLobby)
        #expect(!store.isEnteringLobby)
        store.leave()
        #expect(store.session == nil)
        #expect(store.state == nil)
        #expect(store.connection == .disconnected)
        #expect(!store.isSynced)
    }

    @Test func joinsNormalizedCode() async {
        let store = makeStore()
        await store.joinGame(code: " abcd\n")
        #expect(store.session?.code == "ABCD")
        #expect(store.errorMessage == nil)
        store.leave()
    }

    @Test func joinLinkPrefillsAndPreservesActiveServer() async {
        let store = makeStore()
        store.handle(url: URL(string: QRPayload.join(code: "abcd", server: "http://success.invalid").string)!)
        #expect(store.pendingJoinCode == "ABCD")
        await store.createGame()
        store.handle(url: URL(string: QRPayload.join(code: "EFGH", server: "http://other.invalid").string)!)
        #expect(store.serverURLString == "http://success.invalid")
        #expect(store.errorMessage == "Leave your current game before joining another lobby.")
        store.leave()
    }

    @Test func rejectsBlankNameAndInvalidCode() async {
        let store = makeStore()
        store.playerName = " \n "
        await store.createGame()
        #expect(store.session == nil)
        #expect(store.errorMessage == "Enter your display name.")
        store.playerName = "Ben"
        await store.joinGame(code: "../../games")
        #expect(store.session == nil)
        #expect(store.errorMessage == "Enter a four-character room code.")
    }

    @Test func surfacesHTTPAndServerRejections() async {
        let store = makeStore(host: "http-error")
        await store.createGame()
        #expect(store.session == nil)
        #expect(store.errorMessage == "Server returned HTTP 503.")
        #expect(!store.isEnteringLobby)
        #expect(await store.checkServer() == "Server returned HTTP 503.")
        store.serverURLString = "http://room-error.invalid"
        await store.joinGame(code: "ABCD")
        #expect(store.errorMessage == "Room is full")
        #expect(store.session == nil)
    }
}

private final class LobbyHTTPStub: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!
        var status = 200
        var body = ""
        if url.host == "http-error.invalid" {
            status = 503
            body = "Unavailable"
        } else if url.host == "room-error.invalid" {
            status = 409
            body = #"{"error":"Room is full"}"#
        } else if ["/games", "/games/ABCD/join"].contains(url.path) {
            // Validate the actual POST payload, including the trimmed name.
            var data = request.httpBody
            if data == nil, let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var bytes = [UInt8](repeating: 0, count: 1024)
                var collected = Data()
                while stream.hasBytesAvailable {
                    let count = stream.read(&bytes, maxLength: bytes.count)
                    if count <= 0 { break }
                    collected.append(contentsOf: bytes.prefix(count))
                }
                data = collected
            }
            let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: String]
            if request.httpMethod == "POST", json?["name"] == "Ben" {
                body = #"{"code":"ABCD","playerId":"ben","token":"test-token"}"#
            } else {
                status = 400
                body = #"{"error":"Unexpected request"}"#
            }
        } else {
            status = 404
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
