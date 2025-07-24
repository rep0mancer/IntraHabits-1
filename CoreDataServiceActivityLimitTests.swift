import XCTest
import CoreData
@testable import IntraHabits

final class CoreDataServiceActivityLimitTests: XCTestCase {
    var persistenceController: PersistenceController!
    var service: CoreDataService!

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        service = CoreDataService(container: persistenceController.container)
        StoreKitService.shared.purchasedProductIDs.removeAll()
    }

    override func tearDownWithError() throws {
        StoreKitService.shared.purchasedProductIDs.removeAll()
        service = nil
        persistenceController = nil
    }

    func testActivityLimitEnforcedWithoutPurchase() async throws {
        for i in 0..<5 {
            _ = try await service.createActivity(name: "A\\(i)", type: .numeric, color: "#CD3A2E")
        }

        do {
            _ = try await service.createActivity(name: "Extra", type: .numeric, color: "#CD3A2E")
            XCTFail("Expected limit error")
        } catch DataServiceError.activityLimitReached {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testActivityLimitIgnoredWithPurchase() async throws {
        StoreKitService.shared.purchasedProductIDs.insert("com.intrahabits.unlimited_activities")

        for i in 0..<6 {
            _ = try await service.createActivity(name: "A\\(i)", type: .numeric, color: "#CD3A2E")
        }
    }
}
