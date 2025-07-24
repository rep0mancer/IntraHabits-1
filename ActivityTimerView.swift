import SwiftUI
import WidgetKit

struct ActivityTimerView: View {
    let entry: ActivityTimerEntry
    
    var body: some View {
        if let activity = entry.activity {
            if entry.configuration.activity != nil {
                configuredTimerView(activity: activity)
            } else {
                unconfiguredView
            }
        } else {
            noTimerActivitiesView
        }
    }
    
    @ViewBuilder
    private func configuredTimerView(activity: ActivityEntity) -> some View {
        VStack(spacing: 12) {
            // Header
            headerView(activity: activity)
            
            // Timer display
            timerDisplayView(activity: activity)
            
            // Control buttons
            controlButtonsView(activity: activity)
            
            Spacer()
            
            // Today's summary
            todaysSummaryView
        }
        .padding(12)
        .background(Color(.systemBackground))
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    @ViewBuilder
    private func headerView(activity: ActivityEntity) -> some View {
        HStack {
            // Activity indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(WidgetConfiguration.colorForActivity(activity.color))
                    .frame(width: 8, height: 8)
                
                Text(activity.name)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                
                Text(statusText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func timerDisplayView(activity: ActivityEntity) -> some View {
        VStack(spacing: 8) {
            // Current session time
            VStack(spacing: 4) {
                Text(formatDuration(entry.currentDuration))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(entry.isRunning ? WidgetConfiguration.colorForActivity(activity.color) : .primary)
                    .contentTransition(.numericText())
                
                Text("Current Session")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Progress ring (for medium widget)
            if entry.configuration.activity != nil {
                progressRingView(activity: activity)
            }
        }
    }
    
    @ViewBuilder
    private func progressRingView(activity: ActivityEntity) -> some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                .frame(width: 60, height: 60)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: progressPercentage)
                .stroke(
                    WidgetConfiguration.colorForActivity(activity.color),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progressPercentage)
            
            // Center icon
            Image(systemName: entry.isRunning ? "pause.fill" : "play.fill")
                .font(.title3)
                .foregroundColor(WidgetConfiguration.colorForActivity(activity.color))
        }
    }
    
    @ViewBuilder
    private func controlButtonsView(activity: ActivityEntity) -> some View {
        HStack(spacing: 12) {
            if entry.isRunning {
                // Stop button
                Button(intent: StopTimerIntent(activity: activity)) {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.red)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                // Pause/Resume button
                if entry.isPaused {
                    Button(intent: ResumeTimerIntent(activity: activity)) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                            Text("Resume")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(WidgetConfiguration.colorForActivity(activity.color))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(intent: PauseTimerIntent(activity: activity)) {
                        HStack(spacing: 4) {
                            Image(systemName: "pause.fill")
                            Text("Pause")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.orange)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Start button
                Button(intent: StartTimerIntent(activity: activity)) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("Start Timer")
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(WidgetConfiguration.colorForActivity(activity.color))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var todaysSummaryView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatDuration(entry.todaysTotal))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Today's Total")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Open app button
            Button(intent: OpenActivityIntent(activity: entry.activity!)) {
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var unconfiguredView: some View {
        VStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.title2)
                .foregroundColor(WidgetConfiguration.primaryColor)
            
            Text("Select Timer Activity")
                .font(.caption)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text("Choose which timer to control")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground))
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    private var noTimerActivitiesView: some View {
        VStack(spacing: 8) {
            Image(systemName: "timer.square")
                .font(.title2)
                .foregroundColor(WidgetConfiguration.primaryColor)
            
            Text("No Timer Activities")
                .font(.caption)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text("Create timer activities in the app")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground))
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    // MARK: - Computed Properties
    private var statusColor: Color {
        if entry.isRunning {
            return entry.isPaused ? .orange : .green
        } else {
            return .secondary
        }
    }
    
    private var statusText: String {
        if entry.isRunning {
            return entry.isPaused ? "Paused" : "Running"
        } else {
            return "Stopped"
        }
    }
    
    private var progressPercentage: Double {
        // Progress based on a 30-minute target session
        let targetDuration: TimeInterval = 30 * 60 // 30 minutes
        return min(entry.currentDuration / targetDuration, 1.0)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Preview
struct ActivityTimerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Running timer
            ActivityTimerView(entry: ActivityTimerEntry(
                date: Date(),
                activity: ActivityEntity(id: "1", name: "Exercise", type: "timer", color: "red"),
                isRunning: true,
                isPaused: false,
                currentDuration: 1234,
                todaysTotal: 3600,
                configuration: SelectTimerActivityIntent()
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small - Running")
            
            // Paused timer
            ActivityTimerView(entry: ActivityTimerEntry(
                date: Date(),
                activity: ActivityEntity(id: "1", name: "Meditation", type: "timer", color: "indigo"),
                isRunning: true,
                isPaused: true,
                currentDuration: 567,
                todaysTotal: 1200,
                configuration: SelectTimerActivityIntent()
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Medium - Paused")
            
            // Stopped timer
            ActivityTimerView(entry: ActivityTimerEntry(
                date: Date(),
                activity: ActivityEntity(id: "1", name: "Reading", type: "timer", color: "teal"),
                isRunning: false,
                isPaused: false,
                currentDuration: 0,
                todaysTotal: 2400,
                configuration: SelectTimerActivityIntent()
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Medium - Stopped")
            
            // Unconfigured
            ActivityTimerView(entry: ActivityTimerEntry(
                date: Date(),
                activity: nil,
                isRunning: false,
                isPaused: false,
                currentDuration: 0,
                todaysTotal: 0,
                configuration: SelectTimerActivityIntent()
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Unconfigured")
        }
    }
}

