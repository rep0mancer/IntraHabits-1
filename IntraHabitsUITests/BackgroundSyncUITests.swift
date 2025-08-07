import XCTest

final class BackgroundSyncUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }
    
    func testManualSyncButtonExists() throws {
        let app = XCUIApplication()
        app.launch()

        // Open settings from home
        app.buttons["settingsButton"].tap()
        
        // Expect a manual sync trigger inside sync settings screen reachable from Settings
        // If a dedicated Sync screen exists, open it; otherwise assert button exists in Settings
        let trigger = app.buttons["triggerManualSync"]
        XCTAssertTrue(trigger.waitForExistence(timeout: 5))
    }
}