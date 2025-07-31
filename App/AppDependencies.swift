import Foundation

/// Centralises the shared services used throughout the application.  In the
/// refactored architecture the CloudKit service has been replaced with the
/// ``SyncEngine`` actor which encapsulates all synchronisation logic.
final class AppDependencies {
    /// The new CloudKit sync engine.  ``LegacyCloudKitService`` is retained
    /// only for backwards compatibility during migration.
    let cloudService: SyncEngine
    /// Handles in‑app purchases and subscriptions.
    let storeService: StoreKitService
    /// Centralised error handler.
    let errorHandler: ErrorHandler

    init() {
        cloudService = SyncEngine()
        storeService = StoreKitService()
        errorHandler = ErrorHandler()
    }

    static let shared = AppDependencies()
}