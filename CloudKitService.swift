import Foundation
import CloudKit
import CoreData
import Combine

/// This class previously powered all CloudKit synchronisation for the application.
/// It has been renamed to clearly indicate that it is no longer the primary
/// sync implementation. Use ``SyncEngine`` instead.
@available(*, deprecated, message: "Use SyncEngine actor instead.")
final class LegacyCloudKitService: ObservableObject {
    // The implementation details of the legacy service have been intentionally
    // omitted here. The original service remains available for reference in
    // the upstream repository but should no longer be used by new code.

    /// Represents the state of a sync operation.
    /// Presentation concerns (e.g., mapping to user‑facing strings) are handled
    /// in the ViewModel or View. The ``SyncStatusView`` now computes the
    /// appropriate text based on this state.
    enum SyncStatus {
        case idle
        case syncing
        case completed
        case failed
    }
}