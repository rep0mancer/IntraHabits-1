import XCTest
import Combine
import CoreData
@testable import IntraHabits

final class CoreDataServiceThreadSafetyTests: XCTestCase {
    var persistenceController: PersistenceController!
    var service: CoreDataService!
    var cancellables = Set<AnyCancellable>()

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        service = CoreDataService(container: persistenceController.container)
    }

    override func tearDownWithError() throws {
        cancellables.removeAll()
        service = nil
        persistenceController = nil
    }

    func testCreateActivityOnBackgroundQueue() {
        let expectation = XCTestExpectation(description: "Create activity on background queue")

        DispatchQueue.global(qos: .background).async {
            self.service.createActivity(name: "BG", type: .numeric, color: "#000000")
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed with \(error)")
                    }
                    expectation.fulfill()
                }, receiveValue: { _ in })
                .store(in: &self.cancellables)
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
