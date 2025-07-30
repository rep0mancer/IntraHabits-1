import SwiftUI
import CoreData

struct ActivityDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var activity: Activity
    @StateObject private var viewModel = ActivityDetailViewModel()
    @State private var showingEditActivity = false
    @State private var showingDeleteConfirmation = false
    @State private var showingSessionsList = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Header Section
                    headerSection
                    
                    // Statistics Section
                    statisticsSection
                    
                    // Recent Sessions Section
                    recentSessionsSection
                    
                    // Actions Section
                    actionsSection
                }
                .padding(DesignSystem.Spacing.md)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle(activity.displayName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.edit") {
                        showingEditActivity = true
                    }
                }
            }
        }
        .onAppear {
            viewModel.setActivity(activity, context: viewContext)
        }
        .sheet(isPresented: $showingEditActivity) {
            EditActivityView(activity: activity)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingSessionsList) {
            ActivitySessionsListView(activity: activity)
                .environment(\.managedObjectContext, viewContext)
        }
        .alert("activity.delete.confirmation.title", isPresented: $showingDeleteConfirmation) {
            Button("common.cancel", role: .cancel) { }
            Button("common.delete", role: .destructive) {
                HapticManager.notification(.warning)
                deleteActivity()
            }
        } message: {
            Text("activity.delete.confirmation.message")
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Activity Icon and Color
            Circle()
                .fill(activity.displayColor)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: activity.isTimerType ? "timer" : "number")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.white)
                )
            
            // Activity Info
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(activity.displayName)
                    .font(DesignSystem.Typography.title1)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(activity.activityType.displayName)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Today's Progress
            if activity.isTimerType {
                timerProgressView
            } else {
                numericProgressView
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .cardStyle()
    }
    
    // MARK: - Timer Progress View
    private var timerProgressView: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("activity.detail.today_total")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(.secondary)
            
            Text(viewModel.todaysFormattedValue)
                .font(DesignSystem.Typography.numberLarge)
                .foregroundColor(activity.displayColor)
            
            Button(action: { coordinator.presentTimer(for: activity) }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("activity.detail.start_timer")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }
    
    // MARK: - Numeric Progress View
    private var numericProgressView: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("activity.detail.today_total")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(.secondary)
            
            Text(viewModel.todaysFormattedValue)
                .font(DesignSystem.Typography.numberLarge)
                .foregroundColor(activity.displayColor)
            
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button(action: { viewModel.incrementActivity(by: 1) }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("+1")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button(action: { viewModel.incrementActivity(by: 5) }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("+5")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
    
    // MARK: - Statistics Section
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("activity.detail.statistics")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.md) {
                StatCard(
                    title: "activity.detail.current_streak",
                    value: "\(viewModel.currentStreak)",
                    subtitle: viewModel.currentStreak == 1 ? "day" : "days",
                    icon: "flame",
                    color: .orange
                )
                
                StatCard(
                    title: "activity.detail.longest_streak",
                    value: "\(viewModel.longestStreak)",
                    subtitle: viewModel.longestStreak == 1 ? "day" : "days",
                    icon: "trophy",
                    color: DesignSystem.Colors.amber
                )
                
                StatCard(
                    title: "activity.detail.this_week",
                    value: viewModel.weeklyFormattedValue,
                    icon: "calendar.badge.clock",
                    color: DesignSystem.Colors.teal
                )
                
                StatCard(
                    title: "activity.detail.this_month",
                    value: viewModel.monthlyFormattedValue,
                    icon: "calendar",
                    color: DesignSystem.Colors.indigo
                )
            }
        }
    }
    
    // MARK: - Recent Sessions Section
    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("activity.detail.recent_sessions")
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("activity.detail.view_all") {
                    showingSessionsList = true
                }
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.primary)
            }
            
            if viewModel.recentSessions.isEmpty {
                EmptyStateView(
                    icon: "clock",
                    title: "activity.detail.no_sessions.title",
                    subtitle: "activity.detail.no_sessions.subtitle"
                )
                .frame(height: 150)
            } else {
                LazyVStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(viewModel.recentSessions.prefix(5), id: \.id) { session in
                        SessionRowView(session: session)
                    }
                }
                .cardStyle()
            }
        }
    }
    
    // MARK: - Actions Section
    private var actionsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Button(action: { showingEditActivity = true }) {
                HStack {
                    Image(systemName: "pencil")
                    Text("activity.detail.edit")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(ListButtonStyle())
            
            Button(action: { showingDeleteConfirmation = true }) {
                HStack {
                    Image(systemName: "trash")
                    Text("activity.detail.delete")
                    Spacer()
                }
                .foregroundColor(.red)
            }
            .buttonStyle(ListButtonStyle())
        }
    }
    
    // MARK: - Actions
    private func deleteActivity() {
        activity.isActive = false
        activity.updatedAt = Date()
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            AppLogger.error("Error deleting activity: \(error)")
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Session Row View
struct SessionRowView: View {
    let session: ActivitySession
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.displayDate ?? "Unknown Date")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.primary)
                
                Text(session.displayValue)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if session.isToday {
                BadgeView(
                    text: "Today",
                    backgroundColor: DesignSystem.Colors.primary.opacity(0.2),
                    foregroundColor: DesignSystem.Colors.primary
                )
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

// MARK: - Activity Detail View Model
class ActivityDetailViewModel: ObservableObject {
    @Published var todaysFormattedValue: String = "0"
    @Published var weeklyFormattedValue: String = "0"
    @Published var monthlyFormattedValue: String = "0"
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var recentSessions: [ActivitySession] = []
    @Published var errorMessage: String?
    
    private var activity: Activity?
    private var viewContext: NSManagedObjectContext?
    private var cancellables = Set<AnyCancellable>()
    
    func setActivity(_ activity: Activity, context: NSManagedObjectContext) {
        self.activity = activity
        self.viewContext = context
        updateDisplayValues()
        loadRecentSessions()
        
        // Listen for changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateDisplayValues()
                    self?.loadRecentSessions()
                }
            }
            .store(in: &cancellables)
    }
    
    func incrementActivity(by value: Int = 1) {
        guard let activity = activity,
              let context = viewContext,
              activity.isNumericType else { return }
        
        let session = ActivitySession(context: context)
        session.id = UUID()
        session.activity = activity
        session.sessionDate = Date()
        session.numericValue = Double(value)
        session.createdAt = Date()
        session.isCompleted = true
        
        do {
            try context.save()
            updateDisplayValues()
            loadRecentSessions()
            
            // Haptic feedback
            HapticManager.impact(.medium)

        } catch {
            AppLogger.error("Error saving session: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    private func updateDisplayValues() {
        guard let activity = activity else { return }
        
        todaysFormattedValue = activity.todaysFormattedTotal()
        currentStreak = activity.currentStreak()
        longestStreak = activity.longestStreak()
        
        let weeklyTotal = activity.weeklyTotal()
        let monthlyTotal = activity.monthlyTotal()
        
        if activity.isTimerType {
            weeklyFormattedValue = formatDuration(weeklyTotal)
            monthlyFormattedValue = formatDuration(monthlyTotal)
        } else {
            weeklyFormattedValue = "\(Int(weeklyTotal))"
            monthlyFormattedValue = "\(Int(monthlyTotal))"
        }
    }
    
    private func loadRecentSessions() {
        guard let activity = activity,
              let context = viewContext else { return }
        
        let request = ActivitySession.sessionsForActivityFetchRequest(activity)
        request.fetchLimit = 10
        
        do {
            recentSessions = try context.fetch(request)
        } catch {
            AppLogger.error("Error loading recent sessions: \(error)")
            errorMessage = error.localizedDescription
            recentSessions = []
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(remainingMinutes)m"
        }
    }
}

// MARK: - Preview
struct ActivityDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        let activity = Activity(context: context)
        activity.id = UUID()
        activity.name = "Exercise"
        activity.type = ActivityType.timer.rawValue
        activity.color = "#CD3A2E"
        activity.createdAt = Date()
        activity.isActive = true
        
        return ActivityDetailView(activity: activity)
            .environment(\.managedObjectContext, context)
            .environmentObject(NavigationCoordinator())
            .preferredColorScheme(.dark)
    }
}

