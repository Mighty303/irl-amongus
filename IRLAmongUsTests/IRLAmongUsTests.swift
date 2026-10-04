import AVFoundation
import Foundation
import Testing
import UIKit
@testable import IRLAmongUs

struct BodyReportTests {
    @Test func reportIsNotReplayedByDuplicateEventsOrReconnectsAndResetsForNextRound() {
        var reports = BodyReportState()
        let first = reports.accept(bodyID: "cyan")
        let duplicate = reports.accept(bodyID: "cyan")
        let secondBody = reports.accept(bodyID: "pink")
        #expect(first && !duplicate && secondBody)
        reports.reset()
        let nextRound = reports.accept(bodyID: "cyan")
        #expect(nextRound)
    }

    @Test func originalReportSpritesLoadAndEverySuitGetsItsOwnCorpseColour() throws {
        for name in ["BodyReportStreak", "BodyReportLettering", "BodyReportSkull"] {
            #expect(UIImage(named: name)?.cgImage != nil)
        }
        var variants = Set<Data>()
        for color in PlayerColor.allCases {
            let image = BodyReportArtwork.corpse(color: color)
            let bitmap = try #require(image.cgImage)
            #expect(bitmap.width == 180 && bitmap.height == 115)
            variants.insert(try #require(image.pngData()))
        }
        #expect(variants.count == PlayerColor.allCases.count)
    }

    @MainActor
    @Test func reportWindowCoversScannersWithoutTakingFocusAndDismissesCleanly() throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let originalKey = scene.windows.first(where: \.isKeyWindow)
        let game = UIWindow(windowScene: scene)
        let controller = UIViewController()
        game.rootViewController = controller
        game.makeKeyAndVisible()
        let scanner = UIViewController()
        controller.present(scanner, animated: false)
        let presenter = BodyReportPresenter.Coordinator()
        defer { presenter.close(); game.isHidden = true; originalKey?.makeKey() }
        let report = BodyReportPresentation(bodyID: "cyan", color: .cyan)
        presenter.presentation = report
        presenter.update(anchor: controller.view)
        let overlay = try #require(presenter.overlayWindow)
        #expect(overlay.windowLevel > .alert)
        #expect(!overlay.isKeyWindow && game.isKeyWindow)
        #expect(controller.presentedViewController === scanner)
        presenter.update(anchor: controller.view)
        #expect(presenter.overlayWindow === overlay)
        presenter.presentation = nil
        presenter.update(anchor: controller.view)
        #expect(presenter.overlayWindow == nil)
        #expect(controller.presentedViewController === scanner)
    }
}

struct NeckKillTests {
    @Test func hdPlaybackPreservesAspectRatioAndUsesCurrentSuitColours() throws {
        let purple = try NeckKillFrames.load(attacker: .purple, victim: .cyan)
        let renderer = NeckKillHDRenderer()
        let first = renderer.image(at: 4, in: purple)
        let bitmap = try #require(first.cgImage)
        #expect(bitmap.width == 2028 && bitmap.height == 1200)
        #expect(renderer.image(at: 4, in: purple) === first)

        let yellow = try NeckKillFrames.load(attacker: .yellow, victim: .cyan)
        let updated = NeckKillHDRenderer().image(at: 4, in: yellow)
        #expect(updated.pngData() != first.pngData(), "new presentation colours must reach the HD frame")
        #expect(abs(purple.duration - yellow.duration) < 0.0001)
    }

    @MainActor
    @Test func killWindowCoversPresentedScannerAndKeepsTheUnderlyingScreen() throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let originalKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let gameWindow = UIWindow(windowScene: scene)
        let game = UIViewController()
        gameWindow.rootViewController = game
        gameWindow.makeKeyAndVisible()
        let scanner = UIViewController()
        scanner.modalPresentationStyle = .fullScreen
        game.present(scanner, animated: false)
        let presenter = KillAnimationPresenter.Coordinator()
        defer {
            presenter.close()
            gameWindow.isHidden = true
            originalKeyWindow?.makeKey()
        }

        var kill = KillPresentation(victimID: "victim", attackerColor: .purple, victimColor: .cyan)
        presenter.presentation = kill
        presenter.update(anchor: UIView())
        #expect(presenter.overlayWindow == nil, "wait for a scene instead of losing an early event")
        presenter.update(anchor: game.view)
        let overlay = try #require(presenter.overlayWindow)
        #expect(!overlay.isHidden)
        #expect(overlay.windowLevel > gameWindow.windowLevel)
        #expect(overlay.windowLevel > .alert)
        #expect(!overlay.isKeyWindow)
        #expect(gameWindow.isKeyWindow)
        #expect(game.presentedViewController === scanner)

        let controller = overlay.rootViewController
        kill.attackerColor = .yellow
        presenter.presentation = kill
        presenter.update(anchor: game.view)
        #expect(presenter.overlayWindow === overlay)
        #expect(overlay.rootViewController === controller, "late colour information keeps the playback controller")

        presenter.presentation = nil
        presenter.update(anchor: game.view)
        #expect(presenter.overlayWindow == nil)
        #expect(game.presentedViewController === scanner)
    }

    @Test func keepsSourceTimingAndRecolorsOnlyMaskedSuitPixels() throws {
        let frames = try NeckKillFrames.load(attacker: .purple, victim: .cyan)
        #expect(frames.images.count == 47)
        #expect(abs(frames.duration - 1.6) < 0.0001)
        #expect(frames.frameIndex(at: 0) == 0)
        #expect(frames.frameIndex(at: 0.069) == 0)
        #expect(frames.frameIndex(at: 0.071) == 1)
        #expect(frames.frameIndex(at: 1.6) == 46)
        func bytes(_ image: CGImage) throws -> [UInt8] {
            let context = try #require(CGContext(data: nil, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return Array(UnsafeBufferPointer(start: try #require(context.data).assumingMemoryBound(to: UInt8.self),
                                            count: image.width * image.height * 4))
        }
        var attackerPixels = 0, victimPixels = 0
        for index in frames.images.indices {
            let original = try #require(UIImage(named: String(format: "NeckKillFrame%02d", index))?.cgImage)
            let mask = try #require(UIImage(named: String(format: "NeckKillMask%02d", index))?.cgImage)
            #expect(original.width == 338 && original.height == 200)
            let before = try bytes(original), labels = try bytes(mask)
            let after = try bytes(try #require(frames.images[index].cgImage))
            var preservesUnmaskedPixels = true
            var suitsMatchPalette = true
            for i in stride(from: 0, to: before.count, by: 4) {
                if labels[i] == 0 && labels[i + 1] == 0 {
                    if before[i..<(i + 4)] != after[i..<(i + 4)] { preservesUnmaskedPixels = false }
                } else {
                    let isAttacker = labels[i] > 0
                    if isAttacker { attackerPixels += 1 } else { victimPixels += 1 }
                    let rgb = isAttacker ? PlayerColor.purple.suitRGB : PlayerColor.cyan.suitRGB
                    let shade = Double(before[i + (isAttacker ? 0 : 1)]) / (isAttacker ? 207 : 124)
                    for (channel, value) in [rgb.0, rgb.1, rgb.2].enumerated() {
                        if after[i + channel] != UInt8(min(255, (Double(value) * shade).rounded())) {
                            suitsMatchPalette = false
                        }
                    }
                }
            }
            #expect(preservesUnmaskedPixels, "background, visor and outline in frame \(index)")
            #expect(suitsMatchPalette, "attacker and victim suit in frame \(index)")
        }
        #expect(attackerPixels > 1000 && victimPixels > 1000)
        // An unidentified attacker retains the source artwork on older servers.
        let fallback = try NeckKillFrames.load(attacker: nil, victim: .yellow)
        let source = try bytes(try #require(UIImage(named: "NeckKillFrame04")?.cgImage))
        let labels = try bytes(try #require(UIImage(named: "NeckKillMask04")?.cgImage))
        let result = try bytes(try #require(fallback.images[4].cgImage))
        #expect(stride(from: 0, to: source.count, by: 4).allSatisfy {
            labels[$0] == 0 || source[$0..<($0 + 4)] == result[$0..<($0 + 4)]
        })
    }

    @Test func duplicateKillsStayDismissedUntilNextLife() {
        var state = KillPresentationState()
        let first = state.accept(victimID: "cyan")
        let duplicate = state.accept(victimID: "cyan")
        let another = state.accept(victimID: "pink")
        #expect(first && !duplicate && another)
        state.reset()
        let nextLife = state.accept(victimID: "cyan")
        #expect(nextLife)
    }
}

struct GameOverTests {
    @Test func winScreenShowsTheWinningTeamIncludingDeadPlayersWithTheirRosterColours() {
        func player(_ id: String, color: PlayerColor?, role: Role, alive: Bool = true) -> PlayerView {
            PlayerView(id: id, name: id, color: color, faceId: nil, isHost: false, isBot: nil,
                       connected: true, alive: alive, ejected: false, role: role, hasVoted: false)
        }
        let players = [player("impostor", color: .purple, role: .impostor),
                       player("dead-crew", color: .cyan, role: .crewmate, alive: false),
                       player("me", color: nil, role: .crewmate),
                       player("partner", color: .pink, role: .impostor)]
        let crew = GameOverArtwork.winners(from: players, localID: "me", role: .crewmate)
        #expect(crew.map(\.id) == ["me", "dead-crew"])
        #expect(crew.map(\.color) == [.green, .cyan])
        let impostors = GameOverArtwork.winners(from: players, localID: "me", role: .impostor)
        #expect(impostors.map(\.id) == ["impostor", "partner"])
        #expect(impostors.map(\.color) == [.purple, .pink])
    }

}

struct IRLAmongUsTests {
    @Test func roleRevealLineupUsesRosterColorsAndHidesCrewFromImpostors() {
        func player(_ id: String, color: PlayerColor?, role: Role?) -> PlayerView {
            PlayerView(id: id, name: id, color: color, faceId: nil, isHost: false, isBot: nil,
                       connected: true, alive: true, ejected: false, role: role, hasVoted: false)
        }
        let roster = [player("crew", color: .cyan, role: .crewmate),
                      player("partner", color: .purple, role: .impostor),
                      player("me", color: nil, role: nil),
                      player("hidden", color: .yellow, role: nil)]
        let crew = RoleRevealPlayer.lineup(from: roster, localID: "me", role: .crewmate)
        #expect(crew.map(\.id) == ["me", "crew", "partner", "hidden"])
        #expect(crew.map(\.color) == [.green, .cyan, .purple, .yellow])
        let impostors = RoleRevealPlayer.lineup(from: roster, localID: "me", role: .impostor)
        #expect(impostors.map(\.id) == ["me", "partner"])
        #expect(impostors.map(\.color) == [.green, .purple])
        #expect(RoleRevealPlayer.lineup(from: [], localID: "me", role: .crewmate).isEmpty)
    }

    @Test func killAudioIsBundledAndDecodable() throws {
        for sound in KillSound.allCases {
            let url = try #require(Bundle.main.url(forResource: sound.rawValue, withExtension: "mp3"))
            let player = try AVAudioPlayer(contentsOf: url)
            #expect(player.duration > 0)
            #expect(player.prepareToPlay())
        }
    }

    @MainActor
    @Test func roleRevealSoundIsBundledAndDecodable() throws {
        let asset = try #require(NSDataAsset(name: "RoleRevealSound"))
        let player = try AVAudioPlayer(data: asset.data)
        #expect(player.duration > 4 && player.duration < 5)
        #expect(player.prepareToPlay())
    }

    @Test func playerSpawningAudioIsBundledAndDecodable() throws {
        let url = try #require(Bundle.main.url(forResource: "player-spawning", withExtension: "mp3"))
        let player = try AVAudioPlayer(contentsOf: url)
        #expect(player.duration > 0)
    }

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

    @Test func joinLinkAutomaticallyJoinsAndPreservesActiveServer() async {
        let store = makeStore()
        await store.handle(url: URL(string: QRPayload.join(code: "abcd", server: "http://success.invalid").string)!)
        #expect(store.pendingJoinCode == "ABCD")
        #expect(store.session?.code == "ABCD")
        await store.handle(url: URL(string: QRPayload.join(code: "EFGH", server: "http://other.invalid").string)!)
        #expect(store.serverURLString == "http://success.invalid")
        #expect(store.errorMessage == "Leave your current game before joining another lobby.")
        store.leave()
    }

    @Test func scannedInviteJoinsAutomatically() async {
        let store = makeStore(host: "http-error")
        await store.handleLobbyQRCode(QRPayload.join(code: " abcd ", server: "http://success.invalid").string)
        #expect(store.serverURLString == "http://success.invalid")
        #expect(store.session?.code == "ABCD")
        #expect(store.errorMessage == nil)
        store.leave()
    }

    @Test func scannedInviteKeepsLobbyUntilNameIsEntered() async {
        let store = makeStore()
        store.playerName = "  "
        await store.handleLobbyQRCode(QRPayload.join(code: "abcd", server: "http://success.invalid").string)
        #expect(store.pendingJoinCode == "ABCD")
        #expect(store.session == nil)
        #expect(store.errorMessage == nil)
        store.playerName = "Ben"
        await store.joinGame(code: store.pendingJoinCode!)
        #expect(store.session?.code == "ABCD")
        store.leave()
    }

    @Test func scannedInviteReportsWrongCodesAndInvalidServers() async {
        let store = makeStore()
        for payload in ["not a QR invite", QRPayload.station(id: "wiring").string, QRPayload.player(qrToken: "ben").string] {
            await store.handleLobbyQRCode(payload)
            #expect(store.errorMessage?.contains("Scan a lobby invite QR code") == true)
            #expect(store.session == nil)
        }
        await store.handleLobbyQRCode(QRPayload.join(code: "../../games", server: nil).string)
        #expect(store.errorMessage == "Enter a four-character room code.")
        await store.handleLobbyQRCode(QRPayload.join(code: "ABCD", server: "ftp://invalid").string)
        #expect(store.errorMessage == "This lobby QR contains an invalid server address.")
        #expect(store.serverURLString == "http://success.invalid")
        #expect(store.pendingJoinCode == nil)
    }

    @Test func scannedInviteReportsServerFailures() async {
        let store = makeStore()
        await store.handleLobbyQRCode(QRPayload.join(code: "ABCD", server: "http://room-error.invalid").string)
        #expect(store.errorMessage == "Room is full")
        #expect(store.session == nil)
        #expect(!store.isEnteringLobby)
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

struct TaskTypeDecodingTests {
    @Test func unknownTaskTypesFromANewerServerDontBreakDecoding() throws {
        let types = try JSONDecoder().decode([TaskType].self, from: Data(#"["wiring","hoverboard"]"#.utf8))
        #expect(types == [.wiring, .unknown])
        let task = try JSONDecoder().decode(GameTask.self, from: Data(
            #"{"id":"t1","type":"hoverboard","steps":["s1"],"step":0,"completed":false,"startedAt":null}"#.utf8))
        #expect(task.type == .unknown)
        #expect(!TaskType.allCases.contains(.unknown))
    }
}

struct MiniGameRandomnessTests {
    @MainActor
    @Test func wiringIsShuffledDifferentlyAndNeverStartsSolved() {
        let deals = (0..<500).map { _ in WiringGame.shuffledColors() }
        #expect(!deals.contains([0, 1, 2, 3]))
        #expect(deals.allSatisfy { $0.sorted() == [0, 1, 2, 3] })
        #expect(Set(deals).count == 23, "every non-solved order shows up")
    }
}


struct DeathSoundTests {
    @Test func eventAndSnapshotPlayOnlyOneVictimCue() {
        var eventFirst = DeathSoundState()
        let result1 = eventFirst.killed(victimID: "victim", localID: "victim")
        #expect(result1)
        let result2 = eventFirst.update(wasAlive: true, isAlive: false, isBody: true)
        #expect(!result2)
        let result3 = eventFirst.killed(victimID: "victim", localID: "victim")
        #expect(!result3)
        var snapshotFirst = DeathSoundState()
        let result4 = snapshotFirst.update(wasAlive: true, isAlive: false, isBody: true)
        #expect(result4)
        let result5 = snapshotFirst.killed(victimID: "victim", localID: "victim")
        #expect(!result5)
    }

    @Test func otherPlayersEjectionsAndRestoredBodiesStaySilent() {
        var sound = DeathSoundState()
        let result6 = sound.killed(victimID: "other", localID: "me")
        #expect(!result6)
        let result7 = sound.killed(victimID: nil, localID: nil)
        #expect(!result7)
        let result8 = sound.update(wasAlive: true, isAlive: false, isBody: false)
        #expect(!result8)
        let result9 = sound.update(wasAlive: nil, isAlive: false, isBody: true)
        #expect(!result9)
    }

    @Test func nextLifeCanPlayAgain() {
        var sound = DeathSoundState()
        let result10 = sound.update(wasAlive: true, isAlive: false, isBody: true)
        #expect(result10)
        let result11 = sound.update(wasAlive: false, isAlive: true, isBody: false)
        #expect(!result11)
        let result12 = sound.update(wasAlive: true, isAlive: false, isBody: true)
        #expect(result12)
    }
}
