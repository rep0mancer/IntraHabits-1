import XCTest
@testable import IntraHabits

final class ActivityListViewModelTests: XCTestCase {

    func testActivityListViewModelInit() throws {
        let context = PersistenceController(inMemory: true).container.viewContext
        let vm = ActivityListViewModel(context: context)
        XCTAssertNil(vm.errorMessage)
    }
}
