import XCTest

final class BackgroundSyncUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }
    
    func testBackgroundSyncScheduling() throws {
        throw XCTSkip("UI test pending: requires BGTaskScheduler hooks and identifiers. Wire target in Xcode.")
        // Skeleton for future wiring:
        // let app = XCUIApplication()
        // app.launch()
        // app.tabBars.buttons["Settings"].tap()
        // app.cells["openSyncSettings"].tap()
        // app.buttons["triggerManualSync"].tap()
        // XCTAssertTrue(app.staticTexts["lastSyncDate"].exists)
    }
}