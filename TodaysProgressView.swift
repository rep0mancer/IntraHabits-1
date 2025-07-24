import SwiftUI
import WidgetKit

struct TodaysProgressView: View {
    let entry: TodaysProgressEntry
    
    var body: some View {
        if entry.activities.isEmpty {
            emptyStateView
        } else {
            progressView
        }
    }
    
    private var progressView: some View {
        VStack(spacing: 12) {
            // Header
            headerView
            
            // Activities list
            VStack(spacing: 8) {
                ForEach(entry.activities.prefix(4), id: \.id) { activity in
                    activityProgressRow(activity: activity)
                }
            }
            
            Spacer()
            
            // Summary
            summaryView
        }
        .padding(12)
        .background(Color(.systemBackground))
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's Progress")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(DateFormatter.widgetDate.string(from: entry.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Overall progress indicator
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 3)
                    .frame(width: 24, height: 24)
                
                Circle()
                    .trim(from: 0, to: overallProgress)
                    .stroke(WidgetConfiguration.primaryColor, lineWidth: 3)
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(overallProgress * 100))%")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
            }
        }
    }
    
    @ViewBuilder
    private func activityProgressRow(activity: WidgetActivityProgress) -> some View {
        HStack(spacing: 8) {
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
            
            // Progress value
            if activity.type == "timer" {
                Text(formatDuration(activity.todaysDuration))
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
            } else {
                Text("\(Int(activity.todaysNumericTotal))")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Progress bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 30, height: 4)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(WidgetConfiguration.colorForActivity(activity.color))
                    .frame(width: 30 * activity.progressPercentage, height: 4)
            }
        }
    }
    
    private var summaryView: some View {
        HStack {
            // Total sessions
            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.totalSessions)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundColor(WidgetConfiguration.primaryColor)
                
                Text("Sessions")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Total time (if any timer activities)
            if entry.totalDuration > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatDuration(entry.totalDuration))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundColor(WidgetConfiguration.tealColor)
                    
                    Text("Total Time")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.fill")
                .font(.title2)
                .foregroundColor(WidgetConfiguration.primaryColor)
            
            Text("No Progress Today")
                .font(.caption)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text("Start tracking your activities")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground))
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    private var overallProgress: Double {
        guard !entry.activities.isEmpty else { return 0 }
        
        let totalProgress = entry.activities.reduce(0) { $0 + $1.progressPercentage }
        return totalProgress / Double(entry.activities.count)
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

// MARK: - Date Formatter Extension
extension DateFormatter {
    static let widgetDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

// MARK: - Preview
struct TodaysProgressView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // With activities
            TodaysProgressView(entry: TodaysProgressEntry(
                date: Date(),
                activities: [
                    WidgetActivityProgress(
                        id: "1",
                        name: "Exercise",
                        color: "red",
                        type: "timer",
                        todaysSessions: 2,
                        todaysDuration: 1800,
                        todaysNumericTotal: 0,
                        targetValue: 1800,
                        progressPercentage: 1.0
                    ),
                    WidgetActivityProgress(
                        id: "2",
                        name: "Reading",
                        color: "teal",
                        type: "numeric",
                        todaysSessions: 3,
                        todaysDuration: 0,
                        todaysNumericTotal: 15,
                        targetValue: 20,
                        progressPercentage: 0.75
                    ),
                    WidgetActivityProgress(
                        id: "3",
                        name: "Meditation",
                        color: "indigo",
                        type: "timer",
                        todaysSessions: 1,
                        todaysDuration: 600,
                        todaysNumericTotal: 0,
                        targetValue: 1200,
                        progressPercentage: 0.5
                    ),
                    WidgetActivityProgress(
                        id: "4",
                        name: "Water",
                        color: "teal",
                        type: "numeric",
                        todaysSessions: 6,
                        todaysDuration: 0,
                        todaysNumericTotal: 6,
                        targetValue: 8,
                        progressPercentage: 0.75
                    )
                ],
                totalSessions: 12,
                totalDuration: 2400
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Medium - With Activities")
            
            // Large widget
            TodaysProgressView(entry: TodaysProgressEntry(
                date: Date(),
                activities: [
                    WidgetActivityProgress(
                        id: "1",
                        name: "Exercise",
                        color: "red",
                        type: "timer",
                        todaysSessions: 2,
                        todaysDuration: 1800,
                        todaysNumericTotal: 0,
                        targetValue: 1800,
                        progressPercentage: 1.0
                    ),
                    WidgetActivityProgress(
                        id: "2",
                        name: "Reading Pages",
                        color: "teal",
                        type: "numeric",
                        todaysSessions: 3,
                        todaysDuration: 0,
                        todaysNumericTotal: 15,
                        targetValue: 20,
                        progressPercentage: 0.75
                    )
                ],
                totalSessions: 5,
                totalDuration: 1800
            ))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
            .previewDisplayName("Large - With Activities")
            
            // Empty state
            TodaysProgressView(entry: TodaysProgressEntry(
                date: Date(),
                activities: [],
                totalSessions: 0,
                totalDuration: 0
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Empty State")
        }
    }
}

