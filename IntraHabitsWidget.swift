import WidgetKit
import SwiftUI

@main
struct IntraHabitsWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Activity Quick Actions Widget
        ActivityQuickActionsWidget()
        
        // Today's Progress Widget
        TodaysProgressWidget()
        
        // Activity Timer Widget
        ActivityTimerWidget()
        
        // Activity Stats Widget
        ActivityStatsWidget()
    }
}

// MARK: - Activity Quick Actions Widget
struct ActivityQuickActionsWidget: Widget {
    let kind: String = "ActivityQuickActionsWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectActivityIntent.self,
            provider: ActivityQuickActionsProvider()
        ) { entry in
            ActivityQuickActionsView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Actions")
        .description("Quickly track your activities with one tap")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Today's Progress Widget
struct TodaysProgressWidget: Widget {
    let kind: String = "TodaysProgressWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: TodaysProgressProvider()
        ) { entry in
            TodaysProgressView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Progress")
        .description("See your daily activity progress at a glance")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Activity Timer Widget
struct ActivityTimerWidget: Widget {
    let kind: String = "ActivityTimerWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectTimerActivityIntent.self,
            provider: ActivityTimerProvider()
        ) { entry in
            ActivityTimerView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Activity Timer")
        .description("Start and stop timers for your activities")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Activity Stats Widget
struct ActivityStatsWidget: Widget {
    let kind: String = "ActivityStatsWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: ActivityStatsProvider()
        ) { entry in
            ActivityStatsView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Activity Statistics")
        .description("View your activity streaks and totals")
        .supportedFamilies([.systemLarge])
    }
}

