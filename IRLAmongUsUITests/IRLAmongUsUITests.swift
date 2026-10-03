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

        let electricalPin = app.buttons["Electrical station, SUB 2125 · Community Kitchen, assigned"]
        XCTAssertTrue(electricalPin.exists)
        electricalPin.tap()

        XCTAssertTrue(app.navigationBars["Electrical"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["SUB 2125 · Community Kitchen"].exists)
        XCTAssertTrue(app.staticTexts["/game/ABCD/station/electrical"].exists)
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
