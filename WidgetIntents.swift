import AppIntents
import WidgetKit
import SwiftUI

// MARK: - Activity Selection Intent
struct SelectActivityIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Activity"
    static var description = IntentDescription("Choose which activity to display in the widget")
    
    @Parameter(title: "Activity")
    var activity: ActivityEntity?
    
    init() {}
    
    init(activity: ActivityEntity) {
        self.activity = activity
    }
}

// MARK: - Timer Activity Selection Intent
struct SelectTimerActivityIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Timer Activity"
    static var description = IntentDescription("Choose which timer activity to control")
    
    @Parameter(title: "Timer Activity")
    var activity: ActivityEntity?
    
    init() {}
    
    init(activity: ActivityEntity) {
        self.activity = activity
    }
}

// MARK: - Increment Activity Intent
struct IncrementActivityIntent: AppIntent {
    static var title: LocalizedStringResource = "Increment Activity"
    static var description = IntentDescription("Add one to a numeric activity")
    
    @Parameter(title: "Activity")
    var activity: ActivityEntity
    
    @Parameter(title: "Increment Value", default: 1)
    var incrementValue: Int
    
    init() {
        self.activity = ActivityEntity(id: "", name: "", type: "", color: "")
        self.incrementValue = 1
    }
    
    init(activity: ActivityEntity, incrementValue: Int = 1) {
        self.activity = activity
        self.incrementValue = incrementValue
    }
    
    func perform() async throws -> some IntentResult {
        // Get the shared data service
        let dataService = WidgetDataService.shared
        
        do {
            // Create a new session for the activity
            try await dataService.createSession(
                activityId: activity.id,
                numericValue: Double(incrementValue),
                duration: nil
            )
            
            // Reload all widget timelines
            WidgetCenter.shared.reloadAllTimelines()
            
            return .result(dialog: "Added \(incrementValue) to \(activity.name)")
        } catch {
            throw error
        }
    }
}

// MARK: - Start Timer Intent
struct StartTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Timer"
    static var description = IntentDescription("Start a timer for an activity")
    
    @Parameter(title: "Activity")
    var activity: ActivityEntity
    
    init() {
        self.activity = ActivityEntity(id: "", name: "", type: "", color: "")
    }
    
    init(activity: ActivityEntity) {
        self.activity = activity
    }
    
    func perform() async throws -> some IntentResult {
        let timerService = WidgetTimerService.shared
        
        do {
            try await timerService.startTimer(for: activity.id)
            
            // Reload widget timelines
            WidgetCenter.shared.reloadTimelines(ofKind: "ActivityTimerWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "ActivityQuickActionsWidget")
            
            return .result(dialog: "Started timer for \(activity.name)")
        } catch {
            throw error
        }
    }
}

// MARK: - Stop Timer Intent
struct StopTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Timer"
    static var description = IntentDescription("Stop a running timer and save the session")
    
    @Parameter(title: "Activity")
    var activity: ActivityEntity
    
    init() {
        self.activity = ActivityEntity(id: "", name: "", type: "", color: "")
    }
    
    init(activity: ActivityEntity) {
        self.activity = activity
    }
    
    func perform() async throws -> some IntentResult {
        let timerService = WidgetTimerService.shared
        
        do {
            let duration = try await timerService.stopTimer(for: activity.id)
            
            // Create session with the recorded duration
            let dataService = WidgetDataService.shared
            try await dataService.createSession(
                activityId: activity.id,
                numericValue: nil,
                duration: duration
            )
            
            // Reload widget timelines
            WidgetCenter.shared.reloadTimelines(ofKind: "ActivityTimerWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "ActivityQuickActionsWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "TodaysProgressWidget")
            
            let formattedDuration = String(format: "%.0f", duration / 60)
            return .result(dialog: "Stopped timer for \(activity.name). Recorded \(formattedDuration) minutes.")
        } catch {
            throw error
        }
    }
}

// MARK: - Pause Timer Intent
struct PauseTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Timer"
    static var description = IntentDescription("Pause a running timer")
    
    @Parameter(title: "Activity")
    var activity: ActivityEntity
    
    init() {
        self.activity = ActivityEntity(id: "", name: "", type: "", color: "")
    }
    
    init(activity: ActivityEntity) {
        self.activity = activity
    }
    
    func perform() async throws -> some IntentResult {
        let timerService = WidgetTimerService.shared
        
        do {
            try await timerService.pauseTimer(for: activity.id)
            
            // Reload widget timelines
            WidgetCenter.shared.reloadTimelines(ofKind: "ActivityTimerWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "ActivityQuickActionsWidget")
            
            return .result(dialog: "Paused timer for \(activity.name)")
        } catch {
            throw error
        }
    }
}

// MARK: - Resume Timer Intent
struct ResumeTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Timer"
    static var description = IntentDescription("Resume a paused timer")
    
    @Parameter(title: "Activity")
    var activity: ActivityEntity
    
    init() {
        self.activity = ActivityEntity(id: "", name: "", type: "", color: "")
    }
    
    init(activity: ActivityEntity) {
        self.activity = activity
    }
    
    func perform() async throws -> some IntentResult {
        let timerService = WidgetTimerService.shared
        
        do {
            try await timerService.resumeTimer(for: activity.id)
            
            // Reload widget timelines
            WidgetCenter.shared.reloadTimelines(ofKind: "ActivityTimerWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "ActivityQuickActionsWidget")
            
            return .result(dialog: "Resumed timer for \(activity.name)")
        } catch {
            throw error
        }
    }
}

// MARK: - Open Activity Intent
struct OpenActivityIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Activity"
    static var description = IntentDescription("Open the activity in the main app")
    
    @Parameter(title: "Activity")
    var activity: ActivityEntity
    
    init() {
        self.activity = ActivityEntity(id: "", name: "", type: "", color: "")
    }
    
    init(activity: ActivityEntity) {
        self.activity = activity
    }
    
    func perform() async throws -> some IntentResult {
        // Open the main app with deep link to the specific activity
        let url = URL(string: "intrahabits://activity/\(activity.id)")!
        await OpenURLIntent(url).perform()
        
        return .result()
    }
}

