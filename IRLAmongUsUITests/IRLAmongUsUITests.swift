import XCTest

final class IRLAmongUsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLandscapeLobbyFitsOnScreen() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments.append("-disableAudio")
        app.launch()
        XCTAssertTrue(app.buttons["Local"].waitForExistence(timeout: 5))
        app.buttons["Local"].tap()
        XCTAssertTrue(app.buttons["Classic"].waitForExistence(timeout: 5))
        app.buttons["Classic"].tap()

        let room = app.descendants(matching: .any)["lobby.waitingRoom"].firstMatch
        XCTAssertTrue(room.waitForExistence(timeout: 5))
        let screen = app.windows.firstMatch.frame
        XCTAssertGreaterThan(screen.width, screen.height)
        XCTAssertTrue(screen.contains(room.frame), "The waiting room must fit inside the screen")
        XCTAssertGreaterThan(room.frame.height, screen.height * 0.5)
        for title in ["CUSTOMIZE", "START", "Leave Game"] {
            let button = app.buttons[title]
            XCTAssertTrue(button.isHittable, "\(title) must be visible and tappable")
            XCTAssertTrue(screen.contains(button.frame))
        }
        captureVoting(app, name: "Game lobby landscape")
        app.buttons["Leave Game"].tap()
        XCTAssertTrue(app.staticTexts["HOST"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchesToMainMenu() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments.append("-disableAudio")
        app.launch()

        XCTAssertTrue(app.buttons["Local"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Online"].exists)
        XCTAssertGreaterThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height)
        captureVoting(app, name: "Main menu landscape")

        app.buttons["Local"].tap()

        XCTAssertTrue(app.staticTexts["HOST"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Create"].exists)
        XCTAssertTrue(app.buttons["Classic"].exists)
        XCTAssertTrue(app.buttons["Hide n Seek"].exists)
        XCTAssertTrue(app.buttons["Back"].exists)
        XCTAssertFalse(app.staticTexts["PHYSICAL MAP"].exists)

        app.buttons["Back"].tap()

        XCTAssertTrue(app.buttons["Local"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOpensPhysicalMapAndStationDetails() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments.append("-disableAudio")
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
        app.launchArguments.append("-disableAudio")
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
        app.launchArguments = ["-disableAudio", "-showDeveloperMenu", "-votingTestDuration", String(duration)]
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
