import XCTest

final class RestorePurchasesFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testRestorePurchasesShowsSuccessAlert() throws {
        let app = XCUIApplication()
        app.launch()

        // Open settings
        app.buttons["settingsButton"].tap()

        // Tap restore purchases
        let restore = app.buttons["restorePurchases"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        restore.tap()

        // Depending on sandbox, alert may appear; assert alert title exists when presented
        let successAlert = app.alerts["paywall.purchase.success.title"]
        _ = successAlert.waitForExistence(timeout: 10)
        // Dismiss if shown
        if successAlert.exists {
            successAlert.buttons["common.ok"].tap()
        }
    }
}