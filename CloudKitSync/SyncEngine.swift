import Foundation
import CloudKit
import CoreData

/// An actor-based sync engine that uploads local changes and pulls remote changes from CloudKit.
///
/// The `SyncEngine` encapsulates all CloudKit and Core Data interactions, ensuring
/// serialisation of state and preventing race conditions. It exposes a
/// single `sync()` method which concurrently pushes and pulls changes. A
/// corresponding `SyncController` should wrap this actor on the main thread for UI.
public actor SyncEngine {
    private let db: CKDatabase
    private let context: NSManagedObjectContext

    public init(db: CKDatabase, context: NSManagedObjectContext) {
        self.db = db
        self.context = context
    }

    /// Performs a sync by concurrently pushing local changes and pulling remote ones.
    public func sync() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await self.pushLocalChanges() }
            group.addTask { try await self.pullRemoteChanges() }
        }
        try context.save()
    }

    // MARK: - Push Local Changes
    private func pushLocalChanges() async throws {
        // TODO: Implement uploading Activities and Sessions within this actor.
    }

    // MARK: - Pull Remote Changes
    private func pullRemoteChanges() async throws {
        // TODO: Implement delta or full download within this actor.
    }
}