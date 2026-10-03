import XCTest

final class IRLAmongUsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchesToMainMenu() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["Local"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Online"].exists)
    }

    @MainActor
    func testOpensPhysicalMapAndStationDetails() throws {
        let app = XCUIApplication()
        app.launch()

        let localButton = app.buttons["Local"]
        XCTAssertTrue(localButton.waitForExistence(timeout: 5))
        localButton.tap()

        XCTAssertTrue(app.staticTexts["PHYSICAL MAP"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Demo Building · Level 2"].exists)
        XCTAssertTrue(app.staticTexts["YOU"].exists)

        let electricalPin = app.buttons["Electrical station, Hallway, assigned"]
        XCTAssertTrue(electricalPin.exists)
        electricalPin.tap()

        XCTAssertTrue(app.navigationBars["Electrical"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["/game/ABCD/station/electrical"].exists)
    }
}
