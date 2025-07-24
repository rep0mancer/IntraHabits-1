import SwiftUI
import WidgetKit

struct ActivityStatsView: View {
    let entry: ActivityStatsEntry
    
    var body: some View {
        if entry.topActivities.isEmpty {
            emptyStateView
        } else {
            statsView
        }
    }
    
    private var statsView: some View {
        VStack(spacing: 12) {
            // Header
            headerView
            
            // Top activities
            topActivitiesView
            
            // Overall stats
            overallStatsView
        }
        .padding(12)
        .background(Color(.systemBackground))
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Activity Statistics")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Your progress overview")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Streak indicator
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                Text("\(entry.currentStreak)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
            }
        }
    }
    
    private var topActivitiesView: some View {
        VStack(spacing: 8) {
            ForEach(Array(entry.topActivities.prefix(3).enumerated()), id: \.element.id) { index, activity in
                activityStatsRow(activity: activity, rank: index + 1)
            }
        }
    }
    
    @ViewBuilder
    private func activityStatsRow(activity: WidgetActivityStats, rank: Int) -> some View {
        HStack(spacing: 8) {
            // Rank indicator
            Text("\(rank)")
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 12)
            
            // Color indicator
            Circle()
                .fill(WidgetConfiguration.colorForActivity(activity.color))
                .frame(width: 6, height: 6)
            
            // Activity name
            Text(activity.name)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            // Stats
            VStack(alignment: .trailing, spacing: 1) {
                if activity.type == "timer" {
                    Text(formatDuration(activity.totalDuration))
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("\(activity.totalSessions) sessions")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                } else {
                    Text("\(Int(activity.totalNumericValue))")
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("\(activity.totalSessions) sessions")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            // Streak indicator
            if activity.currentStreak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    
                    Text("\(activity.currentStreak)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    private var overallStatsView: some View {
        VStack(spacing: 8) {
            // Divider
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
            
            // Stats grid
            HStack(spacing: 16) {
                // Active days
                statItem(
                    title: "Active Days",
                    value: "\(entry.totalActiveDays)",
                    icon: "calendar.badge.checkmark",
                    color: WidgetConfiguration.tealColor
                )
                
                Spacer()
                
                // Best streak
                statItem(
                    title: "Best Streak",
                    value: "\(entry.longestStreak)",
                    icon: "trophy.fill",
                    color: WidgetConfiguration.amberColor
                )
                
                Spacer()
                
                // Current streak
                statItem(
                    title: "Current",
                    value: "\(entry.currentStreak)",
                    icon: "flame.fill",
                    color: .orange
                )
            }
        }
    }
    
    @ViewBuilder
    private func statItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(color)
                
                Text(value)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.doc.horizontal.fill")
                .font(.title2)
                .foregroundColor(WidgetConfiguration.primaryColor)
            
            Text("No Statistics Yet")
                .font(.caption)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text("Start tracking activities to see your progress")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground))
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm", minutes)
        } else {
            return "< 1m"
        }
    }
}

// MARK: - Preview
struct ActivityStatsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // With statistics
            ActivityStatsView(entry: ActivityStatsEntry(
                date: Date(),
                topActivities: [
                    WidgetActivityStats(
                        id: "1",
                        name: "Exercise",
                        color: "red",
                        type: "timer",
                        totalSessions: 45,
                        totalDuration: 81000, // 22.5 hours
                        totalNumericValue: 0,
                        currentStreak: 7,
                        bestStreak: 12,
                        averagePerDay: 1.5
                    ),
                    WidgetActivityStats(
                        id: "2",
                        name: "Reading",
                        color: "teal",
                        type: "numeric",
                        totalSessions: 32,
                        totalDuration: 0,
                        totalNumericValue: 480,
                        currentStreak: 3,
                        bestStreak: 8,
                        averagePerDay: 1.1
                    ),
                    WidgetActivityStats(
                        id: "3",
                        name: "Meditation",
                        color: "indigo",
                        type: "timer",
                        totalSessions: 28,
                        totalDuration: 16800, // 4.7 hours
                        totalNumericValue: 0,
                        currentStreak: 5,
                        bestStreak: 10,
                        averagePerDay: 0.9
                    )
                ],
                totalActiveDays: 28,
                longestStreak: 12,
                currentStreak: 7
            ))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
            .previewDisplayName("Large - With Stats")
            
            // Empty state
            ActivityStatsView(entry: ActivityStatsEntry(
                date: Date(),
                topActivities: [],
                totalActiveDays: 0,
                longestStreak: 0,
                currentStreak: 0
            ))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
            .previewDisplayName("Large - Empty State")
        }
    }
}

