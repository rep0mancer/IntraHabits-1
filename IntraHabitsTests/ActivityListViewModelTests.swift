import XCTest
@testable import IntraHabits

final class ActivityListViewModelTests: XCTestCase {
    class MockCloudKitService: CloudKitService {
        override init(container: CKContainer = CKContainer(identifier: "iCloud.com.intrahabits.test")) {
            super.init(container: container)
        }
    }

    func testActivityListViewModelFetch() async throws {
        let vm = ActivityListViewModel()
        await MainActor.run {}
        XCTAssertTrue(vm.activities.isEmpty)
    }
}
