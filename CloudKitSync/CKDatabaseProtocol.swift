import Foundation
import CloudKit

/// Protocol abstracting the CloudKit database for testability. Conform `CKDatabase` via extension
/// and provide a `FakeDatabase` in tests to record calls and return canned results.
public protocol CKDatabaseProtocol {
    @discardableResult
    func save(_ record: CKRecord) async throws -> CKRecord
    func records(matching query: CKQuery, inZoneWithID zoneID: CKRecordZone.ID) async throws -> ([CKRecord.ID: Result<CKRecord, Error>], CKQueryOperation.Cursor?)
    func modifyRecordZones(recordZonesToSave: [CKRecordZone], recordZoneIDsToDelete: [CKRecordZone.ID]) async throws -> (saved: [CKRecordZone], deleted: [CKRecordZone.ID])
}

extension CKDatabase: CKDatabaseProtocol {
    public func modifyRecordZones(recordZonesToSave: [CKRecordZone], recordZoneIDsToDelete: [CKRecordZone.ID]) async throws -> (saved: [CKRecordZone], deleted: [CKRecordZone.ID]) {
        try await withCheckedThrowingContinuation { continuation in
            let op = CKModifyRecordZonesOperation(recordZonesToSave: recordZonesToSave, recordZoneIDsToDelete: recordZoneIDsToDelete)
            op.modifyRecordZonesCompletionBlock = { saved, deleted, error in
                if let error = error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: (saved ?? [], deleted ?? [])) }
            }
            self.add(op)
        }
    }
}