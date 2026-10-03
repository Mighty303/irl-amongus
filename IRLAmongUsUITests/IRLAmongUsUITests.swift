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
}
