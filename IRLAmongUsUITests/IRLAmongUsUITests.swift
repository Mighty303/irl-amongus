import XCTest

final class IRLAmongUsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLocalLobbyRequiresNameAndValidServer() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-disableAudio", "-playerName", "", "-serverURL", "ftp://invalid", "-session", ""]
        app.launch()
        app.buttons["Local"].tap()
        let name = app.textFields["local.playerName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertFalse(app.buttons["Classic"].isEnabled)
        XCTAssertTrue(app.textFields["local.roomCode"].exists)
        XCTAssertFalse(app.buttons["Join game"].isEnabled)
        XCTAssertFalse(app.staticTexts["IRLUS"].exists)
        captureVoting(app, name: "LOCAL server setup")
    }

    @MainActor
    func testLocalServerLobbyStartsAuthoritativeGame() throws {
        guard let server = ProcessInfo.processInfo.environment["LOCAL_LOBBY_TEST_SERVER"] else {
            throw XCTSkip("Run scripts/test-local-lobby-server.py and set TEST_RUNNER_LOCAL_LOBBY_TEST_SERVER")
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-disableAudio", "-playerName", "Ben", "-serverURL", server, "-session", ""]
        app.launch()
        app.buttons["Local"].tap()
        XCTAssertTrue(app.buttons["Classic"].waitForExistence(timeout: 5))
        app.swipeUp()
        app.buttons["Classic"].tap()
        let room = app.descendants(matching: .any)["lobby.waitingRoom"].firstMatch
        XCTAssertTrue(room.waitForExistence(timeout: 10))
        let screen = app.windows.firstMatch.frame
        XCTAssertTrue(screen.contains(room.frame))
        XCTAssertTrue(app.staticTexts["ABCD"].exists)
        let hostSprite = app.descendants(matching: .any)["lobby.playerSprite.0"]
        XCTAssertTrue(hostSprite.waitForExistence(timeout: 5))
        XCTAssertEqual(hostSprite.label, "Ben red player icon, host")
        XCTAssertFalse(app.buttons["START"].isEnabled)
        app.buttons["Add bot"].tap()
        let count = app.staticTexts["lobby.playerCount"]
        let hasTwoPlayers = NSPredicate { _, _ in count.label == "2" }
        expectation(for: hasTwoPlayers, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        let botSprite = app.descendants(matching: .any)["lobby.playerSprite.1"]
        XCTAssertTrue(botSprite.waitForExistence(timeout: 5))
        XCTAssertEqual(botSprite.label, "Test Bot blue player icon")
        XCTAssertTrue(app.buttons["START"].isEnabled)
        captureVoting(app, name: "LOCAL live server lobby")
        app.buttons["START"].tap()
        XCTAssertFalse(app.buttons["Reveal my role"].exists)
        XCTAssertTrue(app.staticTexts["There is 1 Impostor among us"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Got it"].exists)
        XCTAssertGreaterThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height)
        captureVoting(app, name: "Automatic multiplayer role reveal")
        XCTAssertFalse(app.buttons["Leave Game"].exists)
        XCTAssertFalse(app.buttons["roles.close"].exists)
        XCTAssertTrue(app.staticTexts["PHYSICAL MAP"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Close physical map"].exists)
        let portrait = NSPredicate { _, _ in app.windows.firstMatch.frame.height > app.windows.firstMatch.frame.width }
        expectation(for: portrait, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        app.buttons["Leave Game"].tap()
        XCTAssertTrue(app.buttons["Classic"].waitForExistence(timeout: 5))
        let landscape = NSPredicate { _, _ in app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height }
        expectation(for: landscape, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        app.swipeUp()
        app.buttons["Back"].tap()
        XCTAssertTrue(app.buttons["Local"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchesToMainMenu() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-disableAudio", "-session", ""])
        app.launch()

        XCTAssertTrue(app.buttons["Local"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Online"].exists)
        XCTAssertGreaterThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height)
        captureVoting(app, name: "Main menu landscape")

        app.buttons["Local"].tap()

        XCTAssertTrue(app.staticTexts["HOST"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Create"].exists)
        XCTAssertTrue(app.buttons["Classic"].exists)
        XCTAssertFalse(app.buttons["Hide n Seek"].exists)
        XCTAssertTrue(app.buttons["Back"].exists)
        XCTAssertTrue(app.textFields["local.playerName"].exists)
        XCTAssertFalse(app.textFields["local.serverURL"].exists, "The hosted server is fixed; no address field")
        app.swipeUp()
        XCTAssertTrue(app.buttons["Join game"].exists)
        XCTAssertFalse(app.staticTexts["PHYSICAL MAP"].exists)

        app.buttons["Back"].tap()

        XCTAssertTrue(app.buttons["Local"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOpensPhysicalMapAndStationDetails() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-disableAudio", "-session", ""])
        app.launchArguments.append("-showDeveloperMenu")
        app.launch()

        XCTAssertTrue(app.navigationBars["Developer Mode"].waitForExistence(timeout: 5))
        app.buttons["developer.openPhysicalMap"].tap()

        XCTAssertTrue(app.staticTexts["PHYSICAL MAP"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["SFU Student Union Building · Level 2"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["map.ownCheckpoint"].exists)

        let floorPlan = app.descendants(matching: .any)["map.floorPlan"]
        let player = app.descendants(matching: .any)["map.ownCheckpoint"]
        XCTAssertEqual(player.frame.midX, floorPlan.frame.midX, accuracy: 20)
        XCTAssertEqual(player.frame.midY, floorPlan.frame.midY, accuracy: 20)

        // Zoom out to reach a station outside the player-focused opening view.
        floorPlan.pinch(withScale: 0.45, velocity: -1)
        let electricalPin = app.buttons["Electrical station, SUB 2125 · Community Kitchen, assigned"]
        XCTAssertTrue(electricalPin.exists)
        electricalPin.tap()

        XCTAssertTrue(app.navigationBars["Electrical"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["SUB 2125 · Community Kitchen"].exists)
        XCTAssertTrue(app.staticTexts["/game/ABCD/station/electrical"].exists)

        app.buttons["Simulate server verification"].tap()
        XCTAssertTrue(app.buttons["map.resetViewport"].waitForExistence(timeout: 5))
        app.buttons["map.resetViewport"].tap()
        XCTAssertTrue(player.label.contains("Electrical"))
        XCTAssertEqual(player.frame.midX, floorPlan.frame.midX, accuracy: 20)
        XCTAssertEqual(player.frame.midY, floorPlan.frame.midY, accuracy: 20)
    }

    @MainActor
    func testDeveloperMenuLaunchesPhysicalMapPOC() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["-disableAudio", "-session", ""])
        app.launchArguments.append("-showDeveloperMenu")
        app.launch()

        XCTAssertTrue(app.navigationBars["Developer Mode"].waitForExistence(timeout: 5))

        let mapButton = app.buttons["developer.openPhysicalMap"]
        XCTAssertTrue(mapButton.exists)
        mapButton.tap()

        XCTAssertTrue(app.staticTexts["PHYSICAL MAP"].waitForExistence(timeout: 5))
        let portrait = NSPredicate { _, _ in
            app.windows.firstMatch.frame.height > app.windows.firstMatch.frame.width
        }
        expectation(for: portrait, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        XCUIDevice.shared.orientation = .portrait
        captureVoting(app, name: "Map portrait")
        app.buttons["Close physical map"].tap()
        XCTAssertTrue(app.buttons["Local"].waitForExistence(timeout: 5))
        let landscape = NSPredicate { _, _ in
            app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height
        }
        expectation(for: landscape, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        XCUIDevice.shared.orientation = .landscapeLeft

    }
}


extension IRLAmongUsUITests {
    @MainActor
    private func openVoting(duration: Int = 60) -> XCUIApplication {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-disableAudio", "-session", "", "-showDeveloperMenu", "-votingTestDuration", String(duration)]
        app.launch()
        XCTAssertTrue(app.buttons["developer.openVoting"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["developer.openPhysicalMap"].exists)
        app.buttons["developer.openVoting"].tap()
        XCTAssertTrue(app.staticTexts["Who Is The Impostor?"].waitForExistence(timeout: 5))
        let isLandscape = NSPredicate { _, _ in
            app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height
        }
        expectation(for: isLandscape, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        return app
    }

    @MainActor
    private func captureVoting(_ app: XCUIApplication, name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testVotingSelectionCancelAndLock() {
        let app = openVoting()
        captureVoting(app, name: "Voting landscape")
        XCTAssertFalse(app.buttons["voting.player.kai"].isEnabled)
        app.buttons["voting.player.dale"].tap()
        XCTAssertTrue(app.buttons["voting.confirm"].exists)
        captureVoting(app, name: "Voting selection")
        app.buttons["voting.cancel"].tap()
        XCTAssertFalse(app.buttons["voting.confirm"].exists)
        app.buttons["voting.player.lars"].tap()
        app.buttons["voting.confirm"].tap()
        XCTAssertFalse(app.buttons["voting.skip"].isEnabled)
        XCTAssertFalse(app.buttons["voting.player.dale"].isEnabled)
        XCTAssertTrue(app.staticTexts["Vote submitted · Waiting for the timer"].exists)
        app.buttons["voting.exit"].tap()
        XCTAssertTrue(app.buttons["Local"].waitForExistence(timeout: 5))
        XCTAssertGreaterThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height)
    }

    @MainActor
    func testVotingCountdownResultsAndReplay() {
        let app = openVoting(duration: 12)
        app.buttons["voting.player.dale"].tap()
        app.buttons["voting.confirm"].tap()
        let countdown = app.staticTexts["voting.countdown"]
        let initialLabel = countdown.label
        let changed = NSPredicate { _, _ in countdown.exists && countdown.label != initialLabel }
        expectation(for: changed, evaluatedWith: nil)
        waitForExpectations(timeout: 3)
        XCTAssertTrue(app.staticTexts["Dale was ejected."].waitForExistence(timeout: 15))
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Voting results"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["voting.replay"].tap()
        XCTAssertTrue(app.staticTexts["Who Is The Impostor?"].exists)
        XCTAssertTrue(app.buttons["voting.skip"].isEnabled)
        XCTAssertFalse(app.buttons["voting.confirm"].exists)
        app.buttons["voting.skip"].tap()
        app.buttons["voting.confirm"].tap()
        XCTAssertTrue(app.staticTexts["No one was ejected."].waitForExistence(timeout: 15))
        app.buttons["voting.resultExit"].tap()
        XCTAssertTrue(app.buttons["Local"].waitForExistence(timeout: 5))
        XCTAssertGreaterThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height)
    }

    @MainActor
    func testVotingTimeoutWithoutLocalVote() {
        let app = openVoting(duration: 8)
        XCTAssertTrue(app.staticTexts["No one was ejected."].waitForExistence(timeout: 12))
        XCTAssertFalse(app.buttons["voting.skip"].exists)
        XCTAssertFalse(app.buttons["voting.player.dale"].isEnabled)
    }
}


extension IRLAmongUsUITests {
    @MainActor
    func testRoleRevealAutomaticallyOpensMapForBothRoles() {
        for role in ["crewmate", "impostor"] {
            XCUIDevice.shared.orientation = .landscapeLeft
            let app = XCUIApplication()
            app.launchArguments += ["-disableAudio", "-showDeveloperMenu", "-session", ""]
            app.launch()
            let open = app.buttons["developer.openRoles"]
            XCTAssertTrue(open.waitForExistence(timeout: 5))
            if !open.isHittable { app.swipeUp() }
            open.tap()
            XCTAssertTrue(app.buttons["roles.\(role)"].waitForExistence(timeout: 5))
            app.buttons["roles.\(role)"].tap()
            XCTAssertTrue(app.otherElements["roles.intro"].waitForExistence(timeout: 2))
            XCTAssertFalse(app.buttons["roles.close"].exists)
            let title = app.descendants(matching: .any)["roles.title"].firstMatch
            XCTAssertTrue(title.waitForExistence(timeout: 8))
            XCTAssertFalse(app.buttons["roles.replay"].exists)
            XCTAssertFalse(app.buttons["Leave Game"].exists)
            XCTAssertFalse(app.staticTexts["PHYSICAL MAP"].exists)
            captureVoting(app, name: role == "crewmate" ? "Crewmate role reveal" : "Impostor role reveal")
            XCTAssertTrue(app.staticTexts["PHYSICAL MAP"].waitForExistence(timeout: 5))
            let portrait = NSPredicate { _, _ in
                app.windows.firstMatch.frame.height > app.windows.firstMatch.frame.width
            }
            expectation(for: portrait, evaluatedWith: nil)
            waitForExpectations(timeout: 5)
            let kill = app.buttons["map.kill"]
            XCTAssertEqual(kill.exists, role == "impostor")
            XCTAssertTrue(app.navigationBars["Map"].exists)
            if role == "impostor" {
                XCTAssertTrue(kill.isEnabled)
                kill.tap()
                XCTAssertFalse(kill.isEnabled)
                XCTAssertTrue((kill.value as? String)?.hasPrefix("Cooldown") == true)
            }
            app.buttons["Close physical map"].tap()
            XCTAssertTrue(app.buttons["Local"].waitForExistence(timeout: 5))
            app.terminate()
        }
    }
}


extension IRLAmongUsUITests {
    @MainActor
    func testImpostorMapKillUsesServerAction() async throws {
        guard let server = ProcessInfo.processInfo.environment["LOCAL_LOBBY_TEST_SERVER"] else {
            throw XCTSkip("Requires the local fixture with LOCAL_LOBBY_TEST_ROLE=impostor")
        }
        let app = XCUIApplication()
        app.launchArguments = ["-disableAudio", "-playerName", "Ben", "-serverURL", server, "-session", ""]
        app.launch()
        app.buttons["Local"].tap()
        XCTAssertTrue(app.buttons["Classic"].waitForExistence(timeout: 5))
        app.swipeUp()
        app.buttons["Classic"].tap()
        XCTAssertTrue(app.buttons["Add bot"].waitForExistence(timeout: 10))
        app.buttons["Add bot"].tap()
        let ready = NSPredicate { _, _ in app.buttons["START"].isEnabled }
        let readyExpectation = expectation(for: ready, evaluatedWith: nil)
        await fulfillment(of: [readyExpectation], timeout: 5)
        app.buttons["START"].tap()
        XCTAssertTrue(app.staticTexts["PHYSICAL MAP"].waitForExistence(timeout: 10))
        let kill = app.buttons["map.kill"]
        XCTAssertTrue(kill.waitForExistence(timeout: 5))
        let enabled = NSPredicate { _, _ in kill.isEnabled }
        let enabledExpectation = expectation(for: enabled, evaluatedWith: nil)
        await fulfillment(of: [enabledExpectation], timeout: 5)
        kill.tap()
        let cooling = NSPredicate { _, _ in !kill.isEnabled }
        let coolingExpectation = expectation(for: cooling, evaluatedWith: nil)
        await fulfillment(of: [coolingExpectation], timeout: 5)
        let (data, _) = try await URLSession.shared.data(from: URL(string: server + "/events")!)
        let events = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        let kills = events.filter { $0["action"] as? String == "kill" }
        XCTAssertEqual(kills.count, 1)
        XCTAssertEqual((kills.first?["payload"] as? [String: Any])?["targetId"] as? String, "bot")
    }
        let cooldownUpdates = events.filter { $0["action"] as? String == "update_settings" }
        XCTAssertEqual(cooldownUpdates.count, 1)
        XCTAssertEqual((cooldownUpdates.first?["payload"] as? [String: Any])?["killCooldownSec"] as? Int, 10)
        XCTAssertTrue((kill.value as? String)?.hasPrefix("Cooldown") == true)
        let cooldownSeconds = Int((kill.value as? String ?? "").split(separator: " ").dropFirst().first ?? "")
        XCTAssertTrue((1...10).contains(cooldownSeconds ?? 0))
}
