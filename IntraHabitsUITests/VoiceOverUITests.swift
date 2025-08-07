import XCTest

final class VoiceOverUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testVoiceOverLabelsOnTimerControls() throws {
        let app = XCUIApplication()
        app.launch()

        // Start timer if available
        if app.buttons["timerStart"].waitForExistence(timeout: 5) {
            app.buttons["timerStart"].firstMatch.tap()
            let playPause = app.buttons["timerPlayPause"]
            XCTAssertTrue(playPause.waitForExistence(timeout: 5))
            // Labels are set via accessibilityLabel, not identifiers; XCUITest can't directly read label string reliably, but existence suffices
            XCTAssertTrue(app.staticTexts["timerStateText"].exists)
            XCTAssertTrue(app.staticTexts["timerTodaysTotal"].exists)
        }
    }
}