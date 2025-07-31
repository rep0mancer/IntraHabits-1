import Foundation

/// Centralises the shared services used throughout the application.  In the
/// refactored architecture the CloudKit service has been replaced with the
/// ``SyncEngine`` actor which encapsulates all synchronisation logic.
final class AppDependencies {
    /// The underlying CloudKit sync engine.  ``LegacyCloudKitService`` is retained
    /// only for backwards compatibility during migration.  The engine
    /// encapsulates all network and persistence operations and exposes
    /// ``SyncEngine.SyncStatus`` for observing state.
    let cloudService: SyncEngine

    /// A lightweight, @MainActor wrapper around ``SyncEngine`` that is
    /// observable by SwiftUI views.  The UI should interact with this
    /// controller rather than the actor directly.  It mirrors the engine's
    /// ``SyncEngine.SyncStatus`` and forwards sync commands to the actor.
    let syncController: SyncController

    /// Handles in‑app purchases and subscriptions.
    let storeService: StoreKitService

    /// Centralised error handler.
    let errorHandler: ErrorHandler

    init() {
        let engine = SyncEngine()
        self.cloudService = engine
        self.syncController = SyncController(engine: engine)
        self.storeService = StoreKitService()
        self.errorHandler = ErrorHandler()
    }

    static let shared = AppDependencies()
}