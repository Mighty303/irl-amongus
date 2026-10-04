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
        XCTAssertTrue(app.staticTexts["local.username"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["local.createGame"].isEnabled)
        XCTAssertTrue(app.textFields["local.roomCode"].exists)
        XCTAssertFalse(app.buttons["local.joinGame"].isEnabled)
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
        XCTAssertTrue(app.buttons["local.createGame"].waitForExistence(timeout: 5))
        app.buttons["local.createGame"].tap()
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
        XCTAssertTrue(app.buttons["local.createGame"].waitForExistence(timeout: 5))
        let landscape = NSPredicate { _, _ in app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height }
        expectation(for: landscape, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        app.buttons["Back"].tap()
        XCTAssertTrue(app.buttons["Local"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testRoomFirstLobbyFitsAndKeepsActionsAvailable() throws {
        guard let server = ProcessInfo.processInfo.environment["LOCAL_LOBBY_TEST_SERVER"] else {
            throw XCTSkip("Requires scripts/test-local-lobby-server.py")
        }
        let required = Int(ProcessInfo.processInfo.environment["LOCAL_LOBBY_TEST_SIGNS"] ?? "0") ?? 0
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-disableAudio", "-playerName", "Ben", "-serverURL", server, "-session", ""]
        app.launch()
        app.buttons["Local"].tap()
        XCTAssertTrue(app.buttons["local.createGame"].waitForExistence(timeout: 5))
        app.buttons["local.createGame"].tap()
        let room = app.descendants(matching: .any)["lobby.waitingRoom"].firstMatch
        XCTAssertTrue(room.waitForExistence(timeout: 10))
        let screen = app.windows.firstMatch.frame
        captureVoting(app, name: "Room-first initial layout")
        XCTAssertTrue(screen.contains(room.frame), "screen \(screen), room \(room.frame)")
        for name in ["Leave Game", "Copy room code", "Share lobby QR", "Customize your crewmate", "SETTINGS", "START"] {
            let button = app.buttons[name]
            XCTAssertTrue(button.exists, name)
            XCTAssertTrue(screen.contains(button.frame), "\(name) must fit on the phone")
            XCTAssertGreaterThanOrEqual(button.frame.height, 44, name)
        }
        XCTAssertFalse(app.buttons["START"].isEnabled)
        if required > 0 {
            app.scrollViews["lobby.mySigns"].swipeUp()
        }
        app.buttons["Add bot"].tap()
        if required > 0 {
            app.scrollViews["lobby.mySigns"].swipeDown()
        }
        let count = app.staticTexts["lobby.playerCount"]
        expectation(for: NSPredicate { _, _ in count.label == "2" }, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        if required > 0 {
            XCTAssertFalse(app.buttons["START"].isEnabled, "Missing signs must still block the host")
            XCTAssertTrue(app.buttons["START"].value as? String == "Waiting for signs (1 player)")
            app.buttons["Add signs"].firstMatch.tap()
            XCTAssertTrue(app.buttons["Close my signs"].waitForExistence(timeout: 5))
            app.buttons["Close my signs"].tap()
            expectation(for: NSPredicate { _, _ in !app.buttons["Close my signs"].exists }, evaluatedWith: nil)
            waitForExpectations(timeout: 5)
        } else {
            XCTAssertTrue(app.buttons["START"].isEnabled)
        }
        app.buttons["Customize your crewmate"].tap()
        XCTAssertTrue(app.buttons["customize.close"].waitForExistence(timeout: 5))
        app.buttons["customize.close"].tap()
        expectation(for: NSPredicate { _, _ in !app.buttons["customize.close"].exists }, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        app.buttons["Share lobby QR"].tap()
        XCTAssertTrue(app.staticTexts["Scan to join this game"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        captureVoting(app, name: "Room-first lobby")
        app.buttons["Leave Game"].tap()
        XCTAssertTrue(app.buttons["local.createGame"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLobbySettingsConsoleUpdatesLiveAndNavigates() async throws {
        guard let server = ProcessInfo.processInfo.environment["LOCAL_LOBBY_TEST_SERVER"] else {
            throw XCTSkip("Requires the local lobby fixture")
        }
        let guest = ProcessInfo.processInfo.environment["LOCAL_LOBBY_TEST_HOST_ID"] == "other"
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-disableAudio", "-playerName", "Ben", "-serverURL", server, "-session", ""]
        app.launch()
        app.buttons["Local"].tap()
        XCTAssertTrue(app.buttons["local.createGame"].waitForExistence(timeout: 5))
        app.buttons["local.createGame"].tap()
        XCTAssertTrue(app.buttons["SETTINGS"].waitForExistence(timeout: 10))
        app.buttons["SETTINGS"].tap()
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 5))
        let screen = app.windows.firstMatch.frame
        for key in ["impostors", "minPlayers", "signsPerPlayer", "tasksPerPlayer"] {
            for suffix in ["increase", "decrease"] {
                let button = app.buttons["settings.\(key).\(suffix)"]
                XCTAssertTrue(button.exists)
                XCTAssertTrue(screen.contains(button.frame), "\(key) \(suffix) should fit")
                XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            }
        }
        for category in ["game", "tasks", "timers", "signs", "players", "advanced"] {
            let button = app.buttons["settings.category.\(category)"]
            XCTAssertTrue(screen.contains(button.frame), "\(category) category should fit")
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        }
        captureVoting(app, name: "Dark lobby settings · Game")
        if guest {
            XCTAssertFalse(app.buttons["settings.signsPerPlayer.increase"].isEnabled)
            XCTAssertFalse(app.switches["settings.anonymousVotes"].isEnabled)
            XCTAssertFalse(app.buttons["settings.forcedImpostorIds"].isEnabled)
        } else {
            app.buttons["settings.signsPerPlayer.increase"].tap()
            let signs = app.staticTexts["settings.signsPerPlayer.value"]
            let signExpectation = expectation(for: NSPredicate { _, _ in signs.label == "4" }, evaluatedWith: nil)
            await fulfillment(of: [signExpectation], timeout: 5)
            app.switches["settings.anonymousVotes"].tap()
        }
        app.buttons["settings.category.tasks"].tap()
        let scan = app.switches["settings.task.scan"]
        XCTAssertTrue(scan.waitForExistence(timeout: 5))
        if guest {
            XCTAssertFalse(scan.isEnabled)
        } else {
            scan.tap()
            let scanExpectation = expectation(for: NSPredicate { _, _ in scan.value as? String == "1" }, evaluatedWith: nil)
            await fulfillment(of: [scanExpectation], timeout: 5)
        }
        app.buttons["settings.category.timers"].tap()
        XCTAssertTrue(app.staticTexts["settings.roleRevealSec.value"].waitForExistence(timeout: 5))
        app.buttons["settings.category.signs"].tap()
        XCTAssertTrue(app.staticTexts["SAVED GAME"].waitForExistence(timeout: 5))
        if !guest {
            app.buttons["Manage saved games"].tap()
            XCTAssertTrue(app.navigationBars["Games"].waitForExistence(timeout: 5))
            app.navigationBars["Games"].buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 5))
        }
        app.buttons["settings.category.players"].tap()
        if guest {
            XCTAssertFalse(app.buttons["settings.addBot"].exists)
        } else {
            app.buttons["settings.addBot"].tap()
            XCTAssertTrue(app.buttons["Kick Test Bot"].waitForExistence(timeout: 5))
        }
        let advanced = app.buttons["settings.category.advanced"]
        if !advanced.isHittable { app.scrollViews["settings.categories"].swipeUp() }
        advanced.tap()
        XCTAssertTrue(app.staticTexts["settings.killDistanceM.value"].waitForExistence(timeout: 5))
        if guest {
            XCTAssertFalse(app.buttons["settings.killDistanceM.increase"].isEnabled)
        } else {
            app.buttons["settings.killDistanceM.increase"].tap()
            let distance = app.staticTexts["settings.killDistanceM.value"]
            let distanceExpectation = expectation(for: NSPredicate { _, _ in distance.label == "~2.5 m" }, evaluatedWith: nil)
            await fulfillment(of: [distanceExpectation], timeout: 5)
            let (data, _) = try await URLSession.shared.data(from: URL(string: server + "/events")!)
            let events = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
            let updates = events.filter { $0["action"] as? String == "update_settings" }.compactMap { $0["payload"] as? [String: Any] }
            XCTAssertTrue(updates.contains { $0["signsPerPlayer"] as? Int == 4 })
            XCTAssertTrue(updates.contains { $0["anonymousVotes"] as? Bool == true })
            XCTAssertTrue(updates.contains { ($0["taskTypes"] as? [String])?.contains("scan") == true })
            XCTAssertTrue(updates.contains { $0["killDistanceM"] as? Double == 2.5 })
        }
        app.buttons["settings.done"].tap()
        XCTAssertTrue(app.buttons["SETTINGS"].waitForExistence(timeout: 5))
        app.buttons["SETTINGS"].tap()
        XCTAssertTrue(app.staticTexts["settings.signsPerPlayer.value"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["settings.signsPerPlayer.value"].label, guest ? "3" : "4")
        app.buttons["settings.done"].tap()
        app.buttons["Leave Game"].tap()
        XCTAssertTrue(app.buttons["local.createGame"].waitForExistence(timeout: 5))
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

        XCTAssertTrue(app.staticTexts["LOCAL"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["local.createGame"].exists)
        XCTAssertFalse(app.buttons["Hide n Seek"].exists)
        XCTAssertTrue(app.buttons["Back"].exists)
        XCTAssertTrue(app.staticTexts["local.username"].exists)
        XCTAssertTrue(app.buttons["local.editName"].exists)
        XCTAssertFalse(app.textFields["local.serverURL"].exists, "The hosted server is fixed; no address field")
        XCTAssertTrue(app.buttons["local.joinGame"].exists)
        XCTAssertFalse(app.staticTexts["PHYSICAL MAP"].exists)

        app.buttons["Back"].tap()

        XCTAssertTrue(app.buttons["Local"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLocalPickerFitsAndEditsUsername() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-disableAudio", "-playerName", "Martin", "-session", ""]
        app.launch()
        app.buttons["Local"].tap()
        let username = app.staticTexts["local.username"]
        XCTAssertTrue(username.waitForExistence(timeout: 5))
        XCTAssertEqual(username.label, "Martin")
        let screen = app.windows.firstMatch.frame
        for id in ["local.editName", "local.createGame", "local.joinGame"] {
            let button = app.buttons[id]
            XCTAssertTrue(button.isHittable, "\(id) must be visible without scrolling")
            XCTAssertTrue(screen.contains(button.frame), "\(id) must fit inside the screen")
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        }
        captureVoting(app, name: "LOCAL compact create")
        app.buttons["local.editName"].tap()
        let field = app.textFields["local.playerName"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("\u{8}\u{8}\u{8}\u{8}\u{8}\u{8}Alex")
        app.buttons["local.saveName"].tap()
        XCTAssertTrue(username.waitForExistence(timeout: 5))
        XCTAssertEqual(username.label, "Alex")
        for element in [app.textFields["local.roomCode"], app.buttons["local.joinGame"], app.buttons["Scan lobby QR"]] {
            XCTAssertTrue(screen.contains(element.frame))
            XCTAssertGreaterThanOrEqual(element.frame.height, 44)
        }
        XCTAssertTrue(app.textFields["local.roomCode"].isHittable)
        XCTAssertTrue(app.buttons["Scan lobby QR"].isHittable)
        XCTAssertFalse(app.buttons["local.joinGame"].isEnabled)
        captureVoting(app, name: "LOCAL compact join")
        XCTAssertTrue(app.buttons["local.createGame"].isHittable)
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
        for (role, playerCount) in [("crewmate", 10), ("crewmate", 2), ("impostor", 2)] {
            XCUIDevice.shared.orientation = .landscapeLeft
            let app = XCUIApplication()
            app.launchArguments += ["-disableAudio", "-showDeveloperMenu", "-session", ""]
            app.launchArguments += ["-roleRevealPlayerCount", String(playerCount)]
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
            let lineup = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "roles.player."))
            XCTAssertEqual(lineup.count, playerCount)
            XCTAssertEqual(app.otherElements["roles.player.preview-0"].label, "You, red")
            if role == "crewmate" && playerCount == 2 {
                let local = app.otherElements["roles.player.preview-0"].frame
                let other = app.otherElements["roles.player.preview-1"].frame
                XCTAssertGreaterThan(local.width, 0)
                XCTAssertGreaterThan(other.width, 0)
                XCTAssertFalse(local.intersects(other), "Both crewmates must remain fully visible in a two-player lobby")
            }
            XCTAssertFalse(app.buttons["roles.replay"].exists)
            XCTAssertFalse(app.buttons["Leave Game"].exists)
            XCTAssertFalse(app.staticTexts["PHYSICAL MAP"].exists)
            captureVoting(app, name: "\(role) role reveal, \(playerCount) players")
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
        XCTAssertTrue(app.buttons["local.createGame"].waitForExistence(timeout: 5))
        app.buttons["local.createGame"].tap()
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
        let cooldownUpdates = events.filter { $0["action"] as? String == "update_settings" }
        XCTAssertEqual(cooldownUpdates.count, 1)
        XCTAssertEqual((cooldownUpdates.first?["payload"] as? [String: Any])?["killCooldownSec"] as? Int, 10)
        XCTAssertTrue((kill.value as? String)?.hasPrefix("Cooldown") == true)
        let cooldownSeconds = Int((kill.value as? String ?? "").split(separator: " ").dropFirst().first ?? "")
        XCTAssertTrue((1...10).contains(cooldownSeconds ?? 0))
        XCTAssertEqual(kills.count, 1)
        XCTAssertEqual((kills.first?["payload"] as? [String: Any])?["targetId"] as? String, "bot")
    }
}
