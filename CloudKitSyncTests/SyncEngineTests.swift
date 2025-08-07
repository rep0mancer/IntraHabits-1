import XCTest
import CloudKit
@testable import CloudKitSync

final class SyncEngineTests: XCTestCase {
    func testSyncEngineInitialises() {
        let engine = SyncEngine()
        XCTAssertNotNil(engine)
    }

    func testFakeDatabaseRecordsSaves() async throws {
        let fakeDB = FakeDatabase()
        let record = CKRecord(recordType: "Test")
        _ = try await fakeDB.save(record)
        XCTAssertEqual(fakeDB.savedCalls.count, 1)
    }
}