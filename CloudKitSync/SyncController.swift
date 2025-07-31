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
    /// observers on the main thread whenever the underlying actor publishes
    /// a new value.
    @Published private(set) public var status: SyncEngine.Status = .idle

    /// Creates a new controller that wraps the provided ``SyncEngine``.
    /// - Parameter engine: The actor responsible for performing sync
    ///   operations.  Defaults to the shared engine in ``AppDependencies``.
    public init(engine: SyncEngine = AppDependencies.shared.cloudService) {
        self.engine = engine
        self.status = engine.status
        // Observe the actor's @Published status and mirror it on the main
        // actor.  This task inherits the caller's structured context and
        // avoids the use of Task.detached.
        Task { [weak self] in
            for await value in engine.$status.values {
                await self?.updateStatus(value)
            }
        }
    }

    /// Initiates a sync by calling the actor's ``SyncEngine.sync()`` method.
    /// This method should be invoked from UI contexts via `Task {}`.
    public func manuallyTrigger() {
        Task { await engine.sync() }
    }

    /// Fetches the user's iCloud account status by delegating to the
    /// underlying ``SyncEngine``.  The return value is forwarded directly.
    /// - Returns: The ``CKAccountStatus`` describing the user's account.
    public func checkAccountStatus() async -> CKAccountStatus {
        return await engine.checkAccountStatus()
    }

    /// Mirrors a new ``SyncEngine.Status`` onto this controller.  Called from
    /// the background observation task when the actor publishes a change.
    private func updateStatus(_ status: SyncEngine.Status) async {
        self.status = status
    }
}