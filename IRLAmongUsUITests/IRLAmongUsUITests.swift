import XCTest

final class IRLAmongUsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchesToCreateGame() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["Create Game"].waitForExistence(timeout: 5))
    }
}

