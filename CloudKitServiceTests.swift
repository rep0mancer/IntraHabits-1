import XCTest
import CoreData
import CloudKit
@testable import IntraHabits

final class CloudKitServiceTests: XCTestCase {
    var service: CloudKitService?
    var persistence: PersistenceController?
    var context: NSManagedObjectContext?

    override func setUpWithError() throws {
        service = CloudKitService()
        let persist = PersistenceController(inMemory: true)
        persistence = persist
        context = persist.container.viewContext
    }

    override func tearDownWithError() throws {
        service?.disableAutomaticSync()
        service = nil
        context = nil
        persistence = nil
    }

    func testCloudKitErrorDescriptions() {
        XCTAssertEqual(CloudKitError.accountNotAvailable.errorDescription, NSLocalizedString("cloudkit.error.account_not_available", comment: ""))
        XCTAssertEqual(CloudKitError.networkUnavailable.errorDescription, NSLocalizedString("cloudkit.error.network_unavailable", comment: ""))
        XCTAssertEqual(CloudKitError.quotaExceeded.errorDescription, NSLocalizedString("cloudkit.error.quota_exceeded", comment: ""))
    }

    func testSyncStatusDisplayText() {
        XCTAssertEqual(SyncStatus.idle.displayText, NSLocalizedString("sync.status.idle", comment: ""))
        XCTAssertEqual(SyncStatus.syncing.displayText, NSLocalizedString("sync.status.syncing", comment: ""))
        XCTAssertEqual(SyncStatus.completed.displayText, NSLocalizedString("sync.status.completed", comment: ""))
        XCTAssertEqual(SyncStatus.failed.displayText, NSLocalizedString("sync.status.failed", comment: ""))
    }

    func testMarkObjectsForUploadOnNotification() {
        guard let context = context else { return }
        let activity = Activity(context: context)
        activity.id = UUID()
        activity.name = "Test"
        activity.type = ActivityType.numeric.rawValue
        activity.color = "#CD3A2E"
        activity.createdAt = Date()
        activity.isActive = true
        activity.needsCloudKitUpload = false
        activity.lastModifiedAt = nil

        let notification = Notification(name: .NSManagedObjectContextDidSave, object: context, userInfo: [NSUpdatedObjectsKey: Set([activity])])
        NotificationCenter.default.post(notification)

        let expectation = XCTestExpectation(description: "Notification handled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(activity.needsCloudKitUpload)
        XCTAssertNotNil(activity.lastModifiedAt)
    }

    func testCheckAccountStatusUpdatesFlag() async throws {
        let testService = CloudKitService(container: CKContainer(identifier: "iCloud.com.intrahabits.test"))
        await testService.checkAccountStatus()
        XCTAssertFalse(testService.isSignedIn)
    }
}

