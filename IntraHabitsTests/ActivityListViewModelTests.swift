import XCTest
@testable import IntraHabits

final class ActivityListViewModelTests: XCTestCase {

    func testActivityListViewModelInit() throws {
        let vm = ActivityListViewModel()
        XCTAssertNil(vm.errorMessage)
    }
}
