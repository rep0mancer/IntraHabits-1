import XCTest

final class AccessibilityLabelsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testMainListAccessibilityIdentifiersPresent() throws {
        let app = XCUIApplication()
        app.launch()

        // Either empty state or list exists
        XCTAssertTrue(app.otherElements["emptyState"].exists || app.otherElements["activityList"].exists)

        // Settings button exists
        XCTAssertTrue(app.buttons["settingsButton"].exists)
        XCTAssertTrue(app.buttons["calendarButton"].exists)
        XCTAssertTrue(app.buttons["addActivity"].exists)
    }

    func testTimerViewVoiceOverElements() throws {
        let app = XCUIApplication()
        app.launch()

        // Start a timer from first available card if present
        if app.buttons["timerStart"].waitForExistence(timeout: 5) {
            app.buttons["timerStart"].firstMatch.tap()

            // Verify timer labels present
            XCTAssertTrue(app.staticTexts["timerTitle"].exists)
            XCTAssertTrue(app.staticTexts["timerStateText"].exists)
            XCTAssertTrue(app.staticTexts["timerTodaysTotal"].exists)

            // Controls
            XCTAssertTrue(app.buttons["timerPlayPause"].exists)
            XCTAssertTrue(app.buttons["timerStop"].exists)
        }
    }
}