import XCTest
import CoreData
@testable import IntraHabits

final class CoreDataServiceThreadSafetyTests: XCTestCase {
    var persistenceController: PersistenceController!
    var service: CoreDataService!

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        service = CoreDataService(container: persistenceController.container)
    }

    override func tearDownWithError() throws {
        service = nil
        persistenceController = nil
    }

    func testCreateActivityOnBackgroundQueue() async throws {
        let expectation = XCTestExpectation(description: "Create activity on background queue")

        DispatchQueue.global(qos: .background).async {
            Task {
                do {
                    _ = try await self.service.createActivity(name: "BG", type: .numeric, color: "#000000")
                } catch {
                    XCTFail("Failed with \(error)")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
