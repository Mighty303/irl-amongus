import XCTest

final class IRLAmongUsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchesToMainMenu() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-disableAudio")
        app.launch()

        XCTAssertTrue(app.buttons["Local"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Online"].exists)

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
        let app = XCUIApplication()
        app.launchArguments.append("-disableAudio")
        app.launchArguments.append("-showDeveloperMenu")
        app.launch()

        XCTAssertTrue(app.navigationBars["Developer Mode"].waitForExistence(timeout: 5))

        let mapButton = app.buttons["developer.openPhysicalMap"]
        XCTAssertTrue(mapButton.exists)
        mapButton.tap()

        XCTAssertTrue(app.staticTexts["PHYSICAL MAP"].waitForExistence(timeout: 5))
    }
}
