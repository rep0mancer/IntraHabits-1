import Foundation
import CloudKit
@testable import CloudKitSync

/// A fake database used for deterministic sync tests. It records calls and
/// returns canned results supplied at initialisation.
final class FakeDatabase: CKDatabaseProtocol {
    struct SavedCall {
        let record: CKRecord
    }
    struct QueryCall {
        let query: CKQuery
        let zoneID: CKRecordZone.ID
    }
    private(set) var savedCalls: [SavedCall] = []
    private(set) var queryCalls: [QueryCall] = []
    var saveResults: [CKRecord] = []
    var queryResults: [CKRecord.ID: Result<CKRecord, Error>] = [:]

    func save(_ record: CKRecord) async throws -> CKRecord {
        savedCalls.append(.init(record: record))
        if !saveResults.isEmpty {
            return saveResults.removeFirst()
        }
        return record
    }

    func records(matching query: CKQuery, inZoneWithID zoneID: CKRecordZone.ID) async throws -> ([CKRecord.ID : Result<CKRecord, Error>], CKQueryOperation.Cursor?) {
        queryCalls.append(.init(query: query, zoneID: zoneID))
        return (queryResults, nil)
    }

    func modifyRecordZones(recordZonesToSave: [CKRecordZone], recordZoneIDsToDelete: [CKRecordZone.ID]) async throws -> (saved: [CKRecordZone], deleted: [CKRecordZone.ID]) {
        // No-op for tests
        return (recordZonesToSave, [])
    }
}