import XCTest

final class ThreadTrackUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        // Verify the main window appears
        XCTAssertTrue(app.windows.firstMatch.isVisible)
    }
}
