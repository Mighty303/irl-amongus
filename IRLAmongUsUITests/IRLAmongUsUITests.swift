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

        app.buttons["Local"].tap()

        XCTAssertTrue(app.staticTexts["HOST"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Create"].exists)
        XCTAssertTrue(app.buttons["Classic"].exists)
        XCTAssertTrue(app.buttons["Hide n Seek"].exists)
        XCTAssertTrue(app.buttons["Back"].exists)

        app.buttons["Back"].tap()

        XCTAssertTrue(app.buttons["Local"].waitForExistence(timeout: 5))
    }
}
