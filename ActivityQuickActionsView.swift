import SwiftUI
import WidgetKit

struct ActivityQuickActionsView: View {
    let entry: ActivityQuickActionsEntry
    
    var body: some View {
        if let activity = entry.activity {
            if entry.configuration.activity != nil {
                // Configured widget
                configuredActivityView(activity: activity)
            } else {
                // Unconfigured widget - show setup message
                unconfiguredView
            }
        } else {
            // No activities available
            noActivitiesView
        }
    }
    
    @ViewBuilder
    private func configuredActivityView(activity: ActivityEntity) -> some View {
        VStack(spacing: 8) {
            // Header with activity name and color indicator
            HStack {
                Circle()
                    .fill(WidgetConfiguration.colorForActivity(activity.color))
                    .frame(width: 8, height: 8)
                
                Text(activity.name)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                // Activity type indicator
                Image(systemName: activity.type == "timer" ? "timer" : "number")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Main action area
            if activity.type == "timer" {
                timerActionView(activity: activity)
            } else {
                numericActionView(activity: activity)
            }
            
            Spacer()
            
            // Today's progress
            todaysProgressView(activity: activity)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    @ViewBuilder
    private func timerActionView(activity: ActivityEntity) -> some View {
        VStack(spacing: 8) {
            // Current timer display
            if entry.isTimerRunning {
                VStack(spacing: 4) {
                    Text(formatDuration(entry.currentTimerDuration))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundColor(WidgetConfiguration.colorForActivity(activity.color))
                    
                    Text("Running")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .foregroundColor(WidgetConfiguration.colorForActivity(activity.color))
                    
                    Text("Start Timer")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
            
            // Action buttons
            HStack(spacing: 8) {
                if entry.isTimerRunning {
                    // Stop button
                    Button(intent: StopTimerIntent(activity: activity)) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    
                    // Pause button
                    Button(intent: PauseTimerIntent(activity: activity)) {
                        Image(systemName: "pause.circle.fill")
                            .font(.title3)
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Start button
                    Button(intent: StartTimerIntent(activity: activity)) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                            Text("Start")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(WidgetConfiguration.colorForActivity(activity.color))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    @ViewBuilder
    private func numericActionView(activity: ActivityEntity) -> some View {
        VStack(spacing: 8) {
            // Today's total
            VStack(spacing: 4) {
                Text("\(Int(entry.todaysSessions.reduce(0) { $0 + ($1.numericValue ?? 0) }))")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(WidgetConfiguration.colorForActivity(activity.color))
                
                Text("Today")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Action buttons
            HStack(spacing: 8) {
                // +1 button
                Button(intent: IncrementActivityIntent(activity: activity, incrementValue: 1)) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("1")
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(WidgetConfiguration.colorForActivity(activity.color))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                // +5 button (for medium widget)
                if entry.configuration.activity != nil {
                    Button(intent: IncrementActivityIntent(activity: activity, incrementValue: 5)) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("5")
                        }
                        .font(.caption)
                        .foregroundColor(WidgetConfiguration.colorForActivity(activity.color))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(WidgetConfiguration.colorForActivity(activity.color).opacity(0.2))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    @ViewBuilder
    private func todaysProgressView(activity: ActivityEntity) -> some View {
        HStack {
            Text("Today: \(entry.todaysSessions.count) sessions")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if activity.type == "timer" {
                let totalDuration = entry.todaysSessions.reduce(0) { $0 + ($1.duration ?? 0) }
                Text(formatDuration(totalDuration))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var unconfiguredView: some View {
        VStack(spacing: 8) {
            Image(systemName: "gearshape.fill")
                .font(.title2)
                .foregroundColor(WidgetConfiguration.primaryColor)
            
            Text("Tap to Configure")
                .font(.caption)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text("Choose an activity to track")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground))
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    private var noActivitiesView: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundColor(WidgetConfiguration.primaryColor)
            
            Text("No Activities")
                .font(.caption)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text("Create activities in the app first")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground))
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "0:%02d", seconds)
        }
    }
}

// MARK: - Preview
struct ActivityQuickActionsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Timer activity - running
            ActivityQuickActionsView(entry: ActivityQuickActionsEntry(
                date: Date(),
                activity: ActivityEntity(id: "1", name: "Exercise", type: "timer", color: "red"),
                todaysSessions: [],
                isTimerRunning: true,
                currentTimerDuration: 1234,
                configuration: SelectActivityIntent()
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Timer Running")
            
            // Numeric activity
            ActivityQuickActionsView(entry: ActivityQuickActionsEntry(
                date: Date(),
                activity: ActivityEntity(id: "2", name: "Reading Pages", type: "numeric", color: "teal"),
                todaysSessions: [
                    WidgetSession(id: "1", activityId: "2", date: Date(), numericValue: 5, duration: nil, isCompleted: true),
                    WidgetSession(id: "2", activityId: "2", date: Date(), numericValue: 3, duration: nil, isCompleted: true)
                ],
                isTimerRunning: false,
                currentTimerDuration: 0,
                configuration: SelectActivityIntent()
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Numeric Activity")
            
            // Unconfigured
            ActivityQuickActionsView(entry: ActivityQuickActionsEntry(
                date: Date(),
                activity: nil,
                todaysSessions: [],
                isTimerRunning: false,
                currentTimerDuration: 0,
                configuration: SelectActivityIntent()
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Unconfigured")
        }
    }
}

