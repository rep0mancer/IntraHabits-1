import Foundation
import CloudKit

/// A thin @MainActor wrapper around ``SyncEngine`` that exposes the
/// actor's state to SwiftUI views via `@Published` properties.  Views
/// observe an instance of this controller and invoke its async methods to
/// initiate sync operations and query account status.  The controller
/// mirrors the engine's ``SyncEngine.SyncStatus`` and forwards sync
/// commands to the actor.
@MainActor
public final class SyncController: ObservableObject {
    /// The underlying CloudKit sync engine.  This actor performs all
    /// network and persistence operations.
    private let engine: SyncEngine

    /// Published view of the current sync status.  Updates are pushed to
    /// observers on the main thread whenever a sync completes.
    @Published public var syncStatus: SyncEngine.SyncStatus

    /// Creates a new controller that wraps the provided ``SyncEngine``.
    /// - Parameter engine: The actor responsible for performing sync
    ///   operations.  Defaults to the shared engine in ``AppDependencies``.
    public init(engine: SyncEngine = AppDependencies.shared.cloudService) {
        self.engine = engine
        self.syncStatus = engine.syncStatus
    }

    /// Triggers a full sync cycle.  The controller first updates
    /// ``syncStatus`` to `.running` to reflect that work has begun, then
    /// invokes ``SyncEngine.startSync()``.  After completion it copies
    /// the final status from the actor.  This method may be called from
    /// synchronous contexts by wrapping it in a `Task`.
    public func startSync() async {
        // Immediately update the published status so the UI reflects that
        // work is underway.
        syncStatus = .running
        await engine.startSync()
        // After the actor finishes, read its status and mirror it.
        let finalStatus = await engine.syncStatus
        syncStatus = finalStatus
    }

    /// Fetches the user's iCloud account status by delegating to the
    /// underlying ``SyncEngine``.  The return value is forwarded directly.
    /// - Returns: The ``CKAccountStatus`` describing the user's account.
    public func checkAccountStatus() async -> CKAccountStatus {
        return await engine.checkAccountStatus()
    }
}