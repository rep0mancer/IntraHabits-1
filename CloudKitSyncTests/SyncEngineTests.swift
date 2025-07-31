import XCTest
import CloudKit
import CoreData
@testable import CloudKitSync

final class SyncEngineTests: XCTestCase {
    func testSyncEngineInitialisesWithDependencies() async throws {
        let fakeDB = FakeDatabase()
        let context = PersistenceController(inMemory: true).container.viewContext
        let engine = SyncEngine(db: fakeDB as! CKDatabase, context: context)
        XCTAssertNotNil(engine)
    }

    func testFakeDatabaseRecordsSaves() async throws {
        let fakeDB = FakeDatabase()
        let record = CKRecord(recordType: "Test")
        _ = try await fakeDB.save(record)
        XCTAssertEqual(fakeDB.savedCalls.count, 1)
    }
}