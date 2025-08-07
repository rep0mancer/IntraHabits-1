import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingResetConfirmation = false
    @State private var showingResetFinalConfirmation = false
    @State private var showingSyncSettings = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Settings Content
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            generalSection
                            dataSection
                            aboutSection
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.top, DesignSystem.Spacing.lg)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            viewModel.setContext(viewContext)
        }
        .alert("settings.reset.confirmation.title", isPresented: $showingResetConfirmation) {
            Button("settings.reset.confirmation.cancel", role: .cancel) { }
            Button("settings.reset.confirmation.continue", role: .destructive) {
                HapticManager.notification(.warning)
                showingResetFinalConfirmation = true
            }
        } message: {
            Text("settings.reset.confirmation.message")
        }
        .alert("settings.reset.final.title", isPresented: $showingResetFinalConfirmation) {
            Button("settings.reset.final.cancel", role: .cancel) { }
            Button("settings.reset.final.confirm", role: .destructive) {
                HapticManager.notification(.warning)
                viewModel.resetAllData()
            }
        } message: {
            Text("settings.reset.final.message")
        }
        .sheet(isPresented: $showingSyncSettings) {
            SyncSettingsView()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("settings.title")
                .font(DesignSystem.Typography.title2)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Invisible button for balance
            Button(action: {}) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.clear)
            }
            .disabled(true)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.top, DesignSystem.Spacing.sm)
    }
    
    // MARK: - General Section
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("settings.general.title")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "globe",
                    title: "settings.language.title",
                    subtitle: "settings.language.subtitle",
                    action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                )
                
                Divider()
                    .padding(.leading, 44)
                
                SettingsRow(
                    icon: "bell",
                    title: "settings.notifications.title",
                    subtitle: "settings.notifications.subtitle",
                    action: {
                        if #available(iOS 16.0, *) {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } else {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                )
            }
            .cardStyle()
        }
    }
    
    // MARK: - Data Section
    private var dataSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("settings.data.title")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "square.and.arrow.up",
                    title: "settings.export.title",
                    subtitle: "settings.export.subtitle",
                    action: { viewModel.exportData() }
                )
                
                Divider()
                    .padding(.leading, 44)
                
                SettingsRow(
                    icon: "icloud",
                    title: "settings.sync.title",
                    subtitle: "settings.sync.subtitle",
                    action: { showingSyncSettings = true }
                )
                
                Divider()
                    .padding(.leading, 44)
                
                SettingsRow(
                    icon: "trash",
                    title: "settings.reset.title",
                    subtitle: "settings.reset.subtitle",
                    isDestructive: true,
                    action: { showingResetConfirmation = true }
                )
            }
            .cardStyle()
        }
    }
    
    // MARK: - About Section
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("settings.about.title")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "info.circle",
                    title: "settings.version.title",
                    subtitle: "settings.version.subtitle",
                    showChevron: false,
                    action: { }
                )
                
                Divider()
                    .padding(.leading, 44)
                
                SettingsRow(
                    icon: "doc.text",
                    title: "settings.privacy.title",
                    subtitle: "settings.privacy.subtitle",
                    action: {
                        if let url = URL(string: "https://yourcompany.com/privacy") {
                            UIApplication.shared.open(url)
                        }
                    }
                )
            }
            .cardStyle()
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let isDestructive: Bool
    let showChevron: Bool
    let action: () -> Void
    
    init(
        icon: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        isDestructive: Bool = false,
        showChevron: Bool = true,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isDestructive = isDestructive
        self.showChevron = showChevron
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isDestructive ? .red : DesignSystem.Colors.primary)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(isDestructive ? .red : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Settings View Model
@MainActor
class SettingsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Published var appVersion: String = ""
    @Published var buildNumber: String = ""
    @Published var iCloudStatus: String = ""
    
    init() {
        loadAppInfo()
    }
    
    func loadAppInfo() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        appVersion = version
        buildNumber = build
    }
    
    func checkiCloudStatus(using controller: SyncController = AppDependencies.shared.syncController) async {
        isLoading = true
        let status = await controller.checkAccountStatus()
        switch status {
        case .available: iCloudStatus = "Available"
        case .noAccount: iCloudStatus = "No Account"
        case .restricted: iCloudStatus = "Restricted"
        case .couldNotDetermine: iCloudStatus = "Unknown"
        @unknown default: iCloudStatus = "Unknown"
        }
        isLoading = false
    }
    
    private var viewContext: NSManagedObjectContext?
    
    func setContext(_ context: NSManagedObjectContext) {
        self.viewContext = context
    }
    
    func exportData() {
        guard let context = viewContext else { return }
        
        isLoading = true
        
        // Fetch all activities and sessions
        let activityRequest: NSFetchRequest<Activity> = Activity.fetchRequest()
        let sessionRequest: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
        
        do {
            let activities = try context.fetch(activityRequest)
            let sessions = try context.fetch(sessionRequest)
            
            let exportData = ExportData(
                activities: activities.map { ActivityExport(from: $0) },
                sessions: sessions.map { SessionExport(from: $0) },
                exportDate: Date()
            )
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(exportData)
            
            // Share the JSON data
            let activityViewController = UIActivityViewController(
                activityItems: [jsonData],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(activityViewController, animated: true)
            }
            
            isLoading = false
            // successMessage = "Data exported successfully" // This line was removed from the new_code, so it's removed here.
            
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func resetAllData() {
        guard let context = viewContext else { return }
        
        isLoading = true
        
        // Delete all activities and sessions
        let activityRequest: NSFetchRequest<NSFetchRequestResult> = Activity.fetchRequest()
        let sessionRequest: NSFetchRequest<NSFetchRequestResult> = ActivitySession.fetchRequest()
        
        let activityDeleteRequest = NSBatchDeleteRequest(fetchRequest: activityRequest)
        let sessionDeleteRequest = NSBatchDeleteRequest(fetchRequest: sessionRequest)
        
        do {
            try context.execute(sessionDeleteRequest)
            try context.execute(activityDeleteRequest)
            try context.save()
            
            isLoading = false
            // successMessage = "All data has been reset" // This line was removed from the new_code, so it's removed here.
            
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Export Data Models
struct ExportData: Codable {
    let activities: [ActivityExport]
    let sessions: [SessionExport]
    let exportDate: Date
}

struct ActivityExport: Codable {
    let id: UUID
    let name: String
    let type: String
    let color: String
    let createdAt: Date
    let isActive: Bool
    let sortOrder: Int32
    
    init(from activity: Activity) {
        self.id = activity.id ?? UUID()
        self.name = activity.name ?? ""
        self.type = activity.type ?? "numeric"
        self.color = activity.color ?? "#CD3A2E"
        self.createdAt = activity.createdAt ?? Date()
        self.isActive = activity.isActive
        self.sortOrder = activity.sortOrder
    }
}

struct SessionExport: Codable {
    let id: UUID
    let activityId: UUID
    let sessionDate: Date
    let duration: Double
    let numericValue: Double
    let isCompleted: Bool
    let createdAt: Date
    
    init(from session: ActivitySession) {
        self.id = session.id ?? UUID()
        self.activityId = session.activity?.id ?? UUID()
        self.sessionDate = session.sessionDate ?? Date()
        self.duration = session.duration
        self.numericValue = session.numericValue
        self.isCompleted = session.isCompleted
        self.createdAt = session.createdAt ?? Date()
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .preferredColorScheme(.dark)
    }
}

