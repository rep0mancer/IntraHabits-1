import XCTest

final class TimerLifecycleUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }
    
    func testTimerStartPauseResumeStopLifecycle() throws {
        let app = XCUIApplication()
        app.launch()

        // If empty state, add a timer activity via FAB
        if app.otherElements["emptyState"].exists {
            app.buttons["addActivity"].tap()
            let nameField = app.textFields["activityName"]
            XCTAssertTrue(nameField.waitForExistence(timeout: 5))
            nameField.tap()
            nameField.typeText("UITest Timer")

            app.buttons.matching(identifier: "saveActivity").firstMatch.tap()
        }

        // Tap first activity card or specific one if exists
        let list = app.otherElements["activityList"]
        XCTAssertTrue(list.waitForExistence(timeout: 10))
        app.buttons["timerStart"].firstMatch.tap()

        // Timer screen
        let playPause = app.buttons["timerPlayPause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 5))

        // Start
        playPause.tap()
        XCTAssertTrue(app.staticTexts["timerStateText"].waitForExistence(timeout: 3))

        // Pause
        playPause.tap()

        // Resume
        playPause.tap()

        // Stop -> Save
        app.buttons["timerStop"].tap()
        app.buttons["timerSave"].tap()
    }
}