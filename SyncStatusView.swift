import SwiftUI
import CloudKit

/// Displays the current sync state of the application and allows the user to
/// trigger a manual synchronisation.  This view has been updated to use the
/// new ``SyncEngine`` actor rather than the deprecated ``LegacyCloudKitService``.
struct SyncStatusView: View {
    /// The UI observes a ``SyncController`` rather than the actor directly.
    /// ``@StateObject`` ensures the controller's lifetime is tied to the
    /// view and that updates are delivered on the main thread.
    @StateObject private var syncController: SyncController = AppDependencies.shared.syncController
    @State private var accountStatus: CKAccountStatus = .couldNotDetermine
    @State private var isCheckingAccount = false

    /// A computed property that maps the ``SyncEngine.SyncStatus`` to a
    /// localised string for display.  Presentation logic is kept out of
    /// domain and service types.
    private var syncStatusText: String {
        switch syncController.syncStatus {
        case .idle:
            return NSLocalizedString("sync.status.idle", comment: "")
        case .running:
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
                    await syncController.startSync()
                }
            }) {
                Text("sync.manual_sync")
            }
        }
        .onAppear {
            // Kick off an account status check when the view appears.
            checkAccountStatus()
        }
    }

    // MARK: - Account Status
    private func checkAccountStatus() {
        isCheckingAccount = true
        Task {
            let status = await syncController.checkAccountStatus()
            await MainActor.run {
                self.accountStatus = status
                self.isCheckingAccount = false
            }
        }
    }
}