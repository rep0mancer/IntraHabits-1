import SwiftUI
import CloudKit

/// Displays the current sync state of the application and allows the user to
/// trigger a manual synchronisation.  This view has been updated to use the
/// new ``SyncEngine`` actor rather than the deprecated ``LegacyCloudKitService``.
struct SyncStatusView: View {
    /// The sync controller is injected via the environment.  This allows
    /// multiple views to share the same controller instance without
    /// constructing new ones.  Use ``@EnvironmentObject`` rather than
    /// ``@StateObject`` to participate in dependency injection.
    @EnvironmentObject private var sync: SyncController
    @State private var accountStatus: CKAccountStatus = .couldNotDetermine
    @State private var isCheckingAccount = false

    /// A computed property that maps the ``SyncEngine.Status`` to a
    /// localised string for display.  Presentation logic is kept out of
    /// domain and service types.
    private var syncStatusText: String {
        switch sync.status {
        case .idle:
            return NSLocalizedString("sync.status.idle", comment: "")
        case .running(_):
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
                // Trigger a sync without detaching.  The controller
                // schedules its own Task internally.
                sync.manuallyTrigger()
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
            let status = await sync.checkAccountStatus()
            await MainActor.run {
                self.accountStatus = status
                self.isCheckingAccount = false
            }
        }
    }
}