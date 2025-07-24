import SwiftUI
import CoreData

struct StatisticsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = StatisticsViewModel()
    @State private var selectedTimeRange: TimeRange = .week
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Time Range Selector
                    timeRangeSelector
                    
                    // Overview Cards
                    overviewSection
                    
                    // Activity Breakdown
                    activityBreakdownSection
                    
                    // Progress Charts
                    progressChartsSection
                    
                    // Streaks Section
                    streaksSection
                }
                .padding(DesignSystem.Spacing.md)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("statistics.title")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            viewModel.setContext(viewContext)
            viewModel.loadStatistics(for: selectedTimeRange)
        }
        .onChange(of: selectedTimeRange) { newRange in
            viewModel.loadStatistics(for: newRange)
        }
    }
    
    // MARK: - Time Range Selector
    private var timeRangeSelector: some View {
        CustomSegmentedControl(
            options: TimeRange.allCases,
            optionLabels: [
                .week: NSLocalizedString("statistics.time_range.week", comment: ""),
                .month: NSLocalizedString("statistics.time_range.month", comment: ""),
                .year: NSLocalizedString("statistics.time_range.year", comment: ""),
                .all: NSLocalizedString("statistics.time_range.all", comment: "")
            ],
            selection: $selectedTimeRange
        )
    }
    
    // MARK: - Overview Section
    private var overviewSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: DesignSystem.Spacing.md) {
            OverviewCard(
                title: "statistics.total_sessions",
                value: "\(viewModel.totalSessions)",
                icon: "calendar.badge.clock",
                color: DesignSystem.Colors.primary
            )
            
            OverviewCard(
                title: "statistics.total_time",
                value: viewModel.totalTimeFormatted,
                icon: "clock",
                color: DesignSystem.Colors.teal
            )
            
            OverviewCard(
                title: "statistics.active_days",
                value: "\(viewModel.activeDays)",
                icon: "flame",
                color: DesignSystem.Colors.amber
            )
            
            OverviewCard(
                title: "statistics.avg_per_day",
                value: viewModel.averagePerDayFormatted,
                icon: "chart.line.uptrend.xyaxis",
                color: DesignSystem.Colors.indigo
            )
        }
    }
    
    // MARK: - Activity Breakdown Section
    private var activityBreakdownSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("statistics.activity_breakdown")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(.primary)
            
            if viewModel.activityBreakdown.isEmpty {
                EmptyStateView(
                    icon: "chart.pie",
                    title: "statistics.no_data.title",
                    subtitle: "statistics.no_data.subtitle"
                )
                .frame(height: 150)
            } else {
                LazyVStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(viewModel.activityBreakdown, id: \.activity.id) { breakdown in
                        ActivityBreakdownRow(breakdown: breakdown)
                    }
                }
                .cardStyle()
            }
        }
    }
    
    // MARK: - Progress Charts Section
    private var progressChartsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("statistics.progress_over_time")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(.primary)
            
            if viewModel.dailyProgress.isEmpty {
                EmptyStateView(
                    icon: "chart.xyaxis.line",
                    title: "statistics.no_progress.title",
                    subtitle: "statistics.no_progress.subtitle"
                )
                .frame(height: 200)
            } else {
                ProgressChartView(data: viewModel.dailyProgress, timeRange: selectedTimeRange)
                    .frame(height: 200)
                    .cardStyle()
            }
        }
    }
    
    // MARK: - Streaks Section
    private var streaksSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("statistics.streaks")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(.primary)
            
            if viewModel.streakData.isEmpty {
                EmptyStateView(
                    icon: "flame",
                    title: "statistics.no_streaks.title",
                    subtitle: "statistics.no_streaks.subtitle"
                )
                .frame(height: 120)
            } else {
                LazyVStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(viewModel.streakData, id: \.activity.id) { streak in
                        StreakRowView(streak: streak)
                    }
                }
                .cardStyle()
            }
        }
    }
}

// MARK: - Overview Card
struct OverviewCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(NSLocalizedString(title, comment: ""))
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle()
    }
}

// MARK: - Activity Breakdown Row
struct ActivityBreakdownRow: View {
    let breakdown: ActivityBreakdown
    
    var body: some View {
        HStack {
            // Activity Color Indicator
            Circle()
                .fill(breakdown.activity.displayColor)
                .frame(width: 12, height: 12)
            
            // Activity Name
            Text(breakdown.activity.displayName)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Progress Bar
            ProgressBar(
                progress: breakdown.percentage,
                color: breakdown.activity.displayColor,
                height: 6
            )
            .frame(width: 60)
            
            // Value and Percentage
            VStack(alignment: .trailing, spacing: 2) {
                Text(breakdown.formattedValue)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.primary)
                
                Text("\(Int(breakdown.percentage * 100))%")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

// MARK: - Streak Row View
struct StreakRowView: View {
    let streak: StreakData
    
    var body: some View {
        HStack {
            // Activity Color Indicator
            Circle()
                .fill(streak.activity.displayColor)
                .frame(width: 12, height: 12)
            
            // Activity Name
            Text(streak.activity.displayName)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Current Streak
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("\(streak.currentStreak)")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Text("statistics.streak.current")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Best Streak
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.amber)
                    
                    Text("\(streak.longestStreak)")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Text("statistics.streak.best")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

// MARK: - Progress Chart View
struct ProgressChartView: View {
    let data: [DailyProgress]
    let timeRange: TimeRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Chart Title
            Text("statistics.daily_activity")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(.secondary)
            
            // Simple Bar Chart
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(data, id: \.date) { progress in
                    VStack(spacing: 2) {
                        // Bar
                        Rectangle()
                            .fill(DesignSystem.Colors.primary)
                            .frame(width: barWidth, height: barHeight(for: progress))
                            .cornerRadius(2)
                        
                        // Date Label (only show some dates to avoid crowding)
                        if shouldShowDateLabel(for: progress) {
                            Text(formatDateLabel(progress.date))
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                                .rotationEffect(.degrees(-45))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(DesignSystem.Spacing.md)
    }
    
    private var barWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let availableWidth = screenWidth - (DesignSystem.Spacing.md * 4) // Account for padding
        let barCount = CGFloat(data.count)
        let spacing = CGFloat(data.count - 1) * 2 // 2pt spacing between bars
        return max(2, (availableWidth - spacing) / barCount)
    }
    
    private func barHeight(for progress: DailyProgress) -> CGFloat {
        let maxHeight: CGFloat = 120
        let maxValue = data.map(\.totalSessions).max() ?? 1
        let normalizedHeight = CGFloat(progress.totalSessions) / CGFloat(maxValue)
        return max(2, normalizedHeight * maxHeight)
    }
    
    private func shouldShowDateLabel(for progress: DailyProgress) -> Bool {
        let calendar = Calendar.current
        switch timeRange {
        case .week:
            return true // Show all days for week view
        case .month:
            return calendar.component(.day, from: progress.date) % 5 == 1 // Show every 5th day
        case .year:
            return calendar.component(.day, from: progress.date) == 1 // Show first day of month
        case .all:
            return calendar.component(.day, from: progress.date) == 1 && calendar.component(.month, from: progress.date) % 3 == 1 // Show every 3rd month
        }
    }
    
    private func formatDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch timeRange {
        case .week:
            formatter.dateFormat = "E" // Mon, Tue, etc.
        case .month:
            formatter.dateFormat = "d" // 1, 2, 3, etc.
        case .year, .all:
            formatter.dateFormat = "MMM" // Jan, Feb, etc.
        }
        return formatter.string(from: date)
    }
}

// MARK: - Progress Bar
struct ProgressBar: View {
    let progress: Double
    let color: Color
    let height: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(DesignSystem.Colors.systemGray5)
                    .frame(height: height)
                    .cornerRadius(height / 2)
                
                Rectangle()
                    .fill(color)
                    .frame(width: geometry.size.width * CGFloat(progress), height: height)
                    .cornerRadius(height / 2)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Time Range Enum
enum TimeRange: CaseIterable {
    case week, month, year, all
    
    var displayName: String {
        switch self {
        case .week: return NSLocalizedString("statistics.time_range.week", comment: "")
        case .month: return NSLocalizedString("statistics.time_range.month", comment: "")
        case .year: return NSLocalizedString("statistics.time_range.year", comment: "")
        case .all: return NSLocalizedString("statistics.time_range.all", comment: "")
        }
    }
}

// MARK: - Data Models
struct ActivityBreakdown {
    let activity: Activity
    let totalValue: Double
    let percentage: Double
    
    var formattedValue: String {
        if activity.isTimerType {
            let minutes = Int(totalValue / 60)
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            
            if hours > 0 {
                return "\(hours)h \(remainingMinutes)m"
            } else {
                return "\(remainingMinutes)m"
            }
        } else {
            return "\(Int(totalValue))"
        }
    }
}

struct DailyProgress {
    let date: Date
    let totalSessions: Int
    let totalValue: Double
}

struct StreakData {
    let activity: Activity
    let currentStreak: Int
    let longestStreak: Int
}

// MARK: - Statistics View Model
class StatisticsViewModel: ObservableObject {
    @Published var totalSessions = 0
    @Published var totalTimeFormatted = "0m"
    @Published var activeDays = 0
    @Published var averagePerDayFormatted = "0"
    @Published var activityBreakdown: [ActivityBreakdown] = []
    @Published var dailyProgress: [DailyProgress] = []
    @Published var streakData: [StreakData] = []
    
    private var viewContext: NSManagedObjectContext?
    
    func setContext(_ context: NSManagedObjectContext) {
        self.viewContext = context
    }
    
    func loadStatistics(for timeRange: TimeRange) {
        guard let context = viewContext else { return }
        
        let dateRange = getDateRange(for: timeRange)
        
        // Load sessions for the time range
        let sessionRequest: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
        sessionRequest.predicate = NSPredicate(format: "sessionDate >= %@ AND sessionDate <= %@", 
                                             dateRange.start as NSDate, dateRange.end as NSDate)
        sessionRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ActivitySession.sessionDate, ascending: true)]
        
        do {
            let sessions = try context.fetch(sessionRequest)
            
            // Calculate overview statistics
            calculateOverviewStats(sessions: sessions, timeRange: timeRange)
            
            // Calculate activity breakdown
            calculateActivityBreakdown(sessions: sessions)
            
            // Calculate daily progress
            calculateDailyProgress(sessions: sessions, dateRange: dateRange)
            
            // Calculate streak data
            calculateStreakData()
            
        } catch {
            AppLogger.error("Error loading statistics: \(error)")
        }
    }
    
    private func getDateRange(for timeRange: TimeRange) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeRange {
        case .week:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return (startOfWeek, now)
        case .month:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return (startOfMonth, now)
        case .year:
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            return (startOfYear, now)
        case .all:
            return (Date.distantPast, now)
        }
    }
    
    private func calculateOverviewStats(sessions: [ActivitySession], timeRange: TimeRange) {
        totalSessions = sessions.count
        
        let totalTime = sessions.reduce(0) { $0 + ($1.duration ?? 0) }
        totalTimeFormatted = formatDuration(totalTime)
        
        let uniqueDays = Set(sessions.compactMap { session in
            guard let date = session.sessionDate else { return nil }
            return Calendar.current.startOfDay(for: date)
        })
        activeDays = uniqueDays.count
        
        let dayCount = max(1, activeDays)
        let averageSessionsPerDay = Double(totalSessions) / Double(dayCount)
        averagePerDayFormatted = String(format: "%.1f", averageSessionsPerDay)
    }
    
    private func calculateActivityBreakdown(sessions: [ActivitySession]) {
        let groupedSessions = Dictionary(grouping: sessions) { $0.activity }
        var breakdowns: [ActivityBreakdown] = []
        
        let totalValue = sessions.reduce(0.0) { total, session in
            if session.activity?.isTimerType == true {
                return total + (session.duration ?? 0)
            } else {
                return total + (session.numericValue ?? 0)
            }
        }
        
        for (activity, activitySessions) in groupedSessions {
            guard let activity = activity else { continue }
            
            let activityTotal = activitySessions.reduce(0.0) { total, session in
                if activity.isTimerType {
                    return total + (session.duration ?? 0)
                } else {
                    return total + (session.numericValue ?? 0)
                }
            }
            
            let percentage = totalValue > 0 ? activityTotal / totalValue : 0
            
            breakdowns.append(ActivityBreakdown(
                activity: activity,
                totalValue: activityTotal,
                percentage: percentage
            ))
        }
        
        activityBreakdown = breakdowns.sorted { $0.totalValue > $1.totalValue }
    }
    
    private func calculateDailyProgress(sessions: [ActivitySession], dateRange: (start: Date, end: Date)) {
        let calendar = Calendar.current
        var progressData: [DailyProgress] = []
        
        var currentDate = dateRange.start
        while currentDate <= dateRange.end {
            let dayStart = calendar.startOfDay(for: currentDate)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            let daySessions = sessions.filter { session in
                guard let sessionDate = session.sessionDate else { return false }
                return sessionDate >= dayStart && sessionDate < dayEnd
            }
            
            let totalValue = daySessions.reduce(0.0) { total, session in
                if session.activity?.isTimerType == true {
                    return total + (session.duration ?? 0)
                } else {
                    return total + (session.numericValue ?? 0)
                }
            }
            
            progressData.append(DailyProgress(
                date: dayStart,
                totalSessions: daySessions.count,
                totalValue: totalValue
            ))
            
            currentDate = dayEnd
        }
        
        dailyProgress = progressData
    }
    
    private func calculateStreakData() {
        guard let context = viewContext else { return }
        
        let activityRequest: NSFetchRequest<Activity> = Activity.fetchRequest()
        activityRequest.predicate = NSPredicate(format: "isActive == %@", NSNumber(value: true))
        
        do {
            let activities = try context.fetch(activityRequest)
            
            streakData = activities.map { activity in
                StreakData(
                    activity: activity,
                    currentStreak: activity.currentStreak(),
                    longestStreak: activity.longestStreak()
                )
            }.sorted { $0.currentStreak > $1.currentStreak }
            
        } catch {
            AppLogger.error("Error calculating streak data: \(error)")
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
struct StatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        StatisticsView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .preferredColorScheme(.dark)
    }
}

