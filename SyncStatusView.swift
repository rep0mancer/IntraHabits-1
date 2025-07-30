import SwiftUI
import CloudKit

struct SyncStatusView: View {
    @StateObject private var cloudKitService = AppDependencies.shared.cloudService
    @State private var accountStatus: CKAccountStatus = .couldNotDetermine
    @State private var isCheckingAccount = false
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Header
            headerSection
            
            // Account Status
            accountStatusSection
            
            // Sync Status
            syncStatusSection
            
            // Last Sync
            if let lastSyncDate = cloudKitService.lastSyncDate {
                lastSyncSection(lastSyncDate)
            }
            
            // Manual Sync Button
            manualSyncButton
            
            // Error Display
            if let error = cloudKitService.syncError {
                errorSection(error)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle()
        .onAppear {
            checkAccountStatus()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Image(systemName: "icloud")
                .font(.title2)
                .foregroundColor(DesignSystem.Colors.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("sync.title")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(.primary)
                
                Text("sync.subtitle")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Account Status Section
    private var accountStatusSection: some View {
        HStack {
            Text("sync.account_status")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            if isCheckingAccount {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Circle()
                        .fill(accountStatusColor)
                        .frame(width: 8, height: 8)
                    
                    Text(accountStatusText)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Sync Status Section
    private var syncStatusSection: some View {
        HStack {
            Text("sync.sync_status")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: DesignSystem.Spacing.xs) {
                if cloudKitService.syncStatus == .syncing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Circle()
                        .fill(syncStatusColor)
                        .frame(width: 8, height: 8)
                }
                
                Text(cloudKitService.syncStatus.displayText)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Last Sync Section
    private func lastSyncSection(_ date: Date) -> some View {
        HStack {
            Text("sync.last_sync")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(formatLastSyncDate(date))
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Manual Sync Button
    private var manualSyncButton: some View {
        Button(action: {
            cloudKitService.startSync()
        }) {
            HStack {
                if cloudKitService.syncStatus == .syncing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline)
                }
                
                Text("sync.manual_sync")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(cloudKitService.syncStatus == .syncing || accountStatus != .available)
    }
    
    // MARK: - Error Section
    private func errorSection(_ error: Error) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                
                Text("sync.error")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(error.localizedDescription)
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding(DesignSystem.Spacing.sm)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.small)
    }
    
    // MARK: - Computed Properties
    private var accountStatusColor: Color {
        switch accountStatus {
        case .available:
            return .green
        case .noAccount, .restricted:
            return .red
        case .couldNotDetermine, .temporarilyUnavailable:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    private var accountStatusText: String {
        switch accountStatus {
        case .available:
            return NSLocalizedString("sync.account.available", comment: "")
        case .noAccount:
            return NSLocalizedString("sync.account.no_account", comment: "")
        case .restricted:
            return NSLocalizedString("sync.account.restricted", comment: "")
        case .couldNotDetermine:
            return NSLocalizedString("sync.account.unknown", comment: "")
        case .temporarilyUnavailable:
            return NSLocalizedString("sync.account.temporarily_unavailable", comment: "")
        @unknown default:
            return NSLocalizedString("sync.account.unknown", comment: "")
        }
    }
    
    private var syncStatusColor: Color {
        switch cloudKitService.syncStatus {
        case .idle:
            return .gray
        case .syncing:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    // MARK: - Helper Methods
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
    
    private func formatLastSyncDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Sync Settings View
struct SyncSettingsView: View {
    @AppStorage("automaticSyncEnabled") private var automaticSyncEnabled = true
    @AppStorage("syncOnlyOnWiFi") private var syncOnlyOnWiFi = false
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Sync Status
            SyncStatusView()
            
            // Sync Settings
            VStack(spacing: DesignSystem.Spacing.md) {
                // Automatic Sync Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("sync.settings.automatic")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(.primary)
                        
                        Text("sync.settings.automatic.description")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $automaticSyncEnabled)
                        .onChange(of: automaticSyncEnabled) { enabled in
                            if enabled {
                                AppDependencies.shared.cloudService.enableAutomaticSync()
                            } else {
                                AppDependencies.shared.cloudService.disableAutomaticSync()
                            }
                        }
                }
                
                Divider()
                
                // WiFi Only Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("sync.settings.wifi_only")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(.primary)
                        
                        Text("sync.settings.wifi_only.description")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $syncOnlyOnWiFi)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .cardStyle()
        }
    }
}

// MARK: - Preview
struct SyncStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            SyncStatusView()
            SyncSettingsView()
        }
        .padding()
        .background(DesignSystem.Colors.background)
        .preferredColorScheme(.dark)
    }
}

