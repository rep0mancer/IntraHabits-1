import SwiftUI
import CloudKit

/// Displays the current sync state of the application and allows the user to
/// trigger a manual synchronisation.  This view has been updated to use the
/// new ``SyncEngine`` actor rather than the deprecated ``LegacyCloudKitService``.
struct SyncStatusView: View {
    @StateObject private var cloudKitService: SyncEngine = AppDependencies.shared.cloudService
    @State private var accountStatus: CKAccountStatus = .couldNotDetermine
    @State private var isCheckingAccount = false

    /// A computed property that maps the ``SyncEngine``'s sync status to a
    /// localised string for display.  Presentation logic is kept out of
    /// model types.
    private var syncStatusText: String {
        switch cloudKitService.syncStatus {
        case .idle:
            return NSLocalizedString("sync.status.idle", comment: "")
        case .syncing:
            return NSLocalizedString("sync.status.syncing", comment: "")
        case .completed:
            return NSLocalizedString("sync.status.completed", comment: "")
        case .failed:
            return NSLocalizedString("sync.status.failed", comment: "")
        }
    }

    var body: some View {
        VStack {
            // Simplified implementation focusing on sync status presentation.
            HStack {
                Text("sync.sync_status")
                Spacer()
                Text(syncStatusText)
            }
            .padding()

            // Manual Sync Button
            Button(action: {
                Task {
                    await cloudKitService.startSync()
                }
            }) {
                Text("sync.manual_sync")
            }
        }
        .onAppear {
            // Kick off an account status check when the view appears.  Since
            // ``checkAccountStatus()`` is asynchronous on the actor, wrap it in
            // a Task and await its result.
            checkAccountStatus()
        }
    }

    // MARK: - Account Status
    private func checkAccountStatus() {
        isCheckingAccount = true
        Task {
            let status = await cloudKitService.checkAccountStatus()
            await MainActor.run {
                self.accountStatus = status
                self.isCheckingAccount = false
            }
        }
    }
}