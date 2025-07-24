import WidgetKit
import SwiftUI

// MARK: - Activity Quick Actions Provider
struct ActivityQuickActionsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ActivityQuickActionsEntry {
        ActivityQuickActionsEntry(
            date: Date(),
            activity: ActivityEntity(id: "1", name: "Exercise", type: "timer", color: "red"),
            todaysSessions: [],
            isTimerRunning: false,
            currentTimerDuration: 0,
            configuration: SelectActivityIntent()
        )
    }
    
    func snapshot(for configuration: SelectActivityIntent, in context: Context) async -> ActivityQuickActionsEntry {
        let activity = configuration.activity ?? ActivityEntity(id: "1", name: "Exercise", type: "timer", color: "red")
        
        return ActivityQuickActionsEntry(
            date: Date(),
            activity: activity,
            todaysSessions: [],
            isTimerRunning: false,
            currentTimerDuration: 0,
            configuration: configuration
        )
    }
    
    func timeline(for configuration: SelectActivityIntent, in context: Context) async -> Timeline<ActivityQuickActionsEntry> {
        let dataService = WidgetDataService.shared
        let timerService = WidgetTimerService.shared
        
        do {
            let activity = configuration.activity ?? (try await dataService.getAllActivities().first)
            
            guard let selectedActivity = activity else {
                let emptyEntry = ActivityQuickActionsEntry(
                    date: Date(),
                    activity: nil,
                    todaysSessions: [],
                    isTimerRunning: false,
                    currentTimerDuration: 0,
                    configuration: configuration
                )
                return Timeline(entries: [emptyEntry], policy: .after(Date().addingTimeInterval(3600)))
            }
            
            let todaysSessions = try await dataService.getTodaysSessions(for: selectedActivity.id)
            let isTimerRunning = timerService.isTimerRunning(for: selectedActivity.id)
            let currentDuration = timerService.getCurrentDuration(for: selectedActivity.id)
            
            let entry = ActivityQuickActionsEntry(
                date: Date(),
                activity: selectedActivity,
                todaysSessions: todaysSessions,
                isTimerRunning: isTimerRunning,
                currentTimerDuration: currentDuration,
                configuration: configuration
            )
            
            // Update more frequently if timer is running
            let nextUpdate = isTimerRunning ? Date().addingTimeInterval(30) : Date().addingTimeInterval(300)
            return Timeline(entries: [entry], policy: .after(nextUpdate))
            
        } catch {
            let errorEntry = ActivityQuickActionsEntry(
                date: Date(),
                activity: nil,
                todaysSessions: [],
                isTimerRunning: false,
                currentTimerDuration: 0,
                configuration: configuration
            )
            return Timeline(entries: [errorEntry], policy: .after(Date().addingTimeInterval(3600)))
        }
    }
}

// MARK: - Today's Progress Provider
struct TodaysProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodaysProgressEntry {
        TodaysProgressEntry(
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
                )
            ],
            totalSessions: 5,
            totalDuration: 1800
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TodaysProgressEntry) -> ()) {
        completion(placeholder(in: context))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodaysProgressEntry>) -> ()) {
        Task {
            let dataService = WidgetDataService.shared
            
            do {
                let activities = try await dataService.getTodaysProgress()
                let totalSessions = activities.reduce(0) { $0 + $1.todaysSessions }
                let totalDuration = activities.reduce(0) { $0 + $1.todaysDuration }
                
                let entry = TodaysProgressEntry(
                    date: Date(),
                    activities: Array(activities.prefix(WidgetConfiguration.maxActivitiesInWidget)),
                    totalSessions: totalSessions,
                    totalDuration: totalDuration
                )
                
                let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
                
            } catch {
                let errorEntry = TodaysProgressEntry(
                    date: Date(),
                    activities: [],
                    totalSessions: 0,
                    totalDuration: 0
                )
                let timeline = Timeline(entries: [errorEntry], policy: .after(Date().addingTimeInterval(3600)))
                completion(timeline)
            }
        }
    }
}

// MARK: - Activity Timer Provider
struct ActivityTimerProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ActivityTimerEntry {
        ActivityTimerEntry(
            date: Date(),
            activity: ActivityEntity(id: "1", name: "Exercise", type: "timer", color: "red"),
            isRunning: true,
            isPaused: false,
            currentDuration: 1234,
            todaysTotal: 3600,
            configuration: SelectTimerActivityIntent()
        )
    }
    
    func snapshot(for configuration: SelectTimerActivityIntent, in context: Context) async -> ActivityTimerEntry {
        let activity = configuration.activity ?? ActivityEntity(id: "1", name: "Exercise", type: "timer", color: "red")
        
        return ActivityTimerEntry(
            date: Date(),
            activity: activity,
            isRunning: false,
            isPaused: false,
            currentDuration: 0,
            todaysTotal: 0,
            configuration: configuration
        )
    }
    
    func timeline(for configuration: SelectTimerActivityIntent, in context: Context) async -> Timeline<ActivityTimerEntry> {
        let dataService = WidgetDataService.shared
        let timerService = WidgetTimerService.shared
        
        do {
            // Get timer activities only
            let allActivities = try await dataService.getAllActivities()
            let timerActivities = allActivities.filter { $0.type == "timer" }
            
            let activity = configuration.activity ?? timerActivities.first
            
            guard let selectedActivity = activity else {
                let emptyEntry = ActivityTimerEntry(
                    date: Date(),
                    activity: nil,
                    isRunning: false,
                    isPaused: false,
                    currentDuration: 0,
                    todaysTotal: 0,
                    configuration: configuration
                )
                return Timeline(entries: [emptyEntry], policy: .after(Date().addingTimeInterval(3600)))
            }
            
            let timerState = timerService.getTimerState(for: selectedActivity.id)
            let todaysSessions = try await dataService.getTodaysSessions(for: selectedActivity.id)
            let todaysTotal = todaysSessions.reduce(0) { $0 + ($1.duration ?? 0) }
            
            let entry = ActivityTimerEntry(
                date: Date(),
                activity: selectedActivity,
                isRunning: timerState?.isRunning ?? false,
                isPaused: timerState?.isPaused ?? false,
                currentDuration: timerState?.currentDuration ?? 0,
                todaysTotal: todaysTotal,
                configuration: configuration
            )
            
            // Update more frequently if timer is running
            let isRunning = timerState?.isRunning == true && timerState?.isPaused == false
            let nextUpdate = isRunning ? Date().addingTimeInterval(30) : Date().addingTimeInterval(300)
            return Timeline(entries: [entry], policy: .after(nextUpdate))
            
        } catch {
            let errorEntry = ActivityTimerEntry(
                date: Date(),
                activity: nil,
                isRunning: false,
                isPaused: false,
                currentDuration: 0,
                todaysTotal: 0,
                configuration: configuration
            )
            return Timeline(entries: [errorEntry], policy: .after(Date().addingTimeInterval(3600)))
        }
    }
}

// MARK: - Activity Stats Provider
struct ActivityStatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> ActivityStatsEntry {
        ActivityStatsEntry(
            date: Date(),
            topActivities: [
                WidgetActivityStats(
                    id: "1",
                    name: "Exercise",
                    color: "red",
                    type: "timer",
                    totalSessions: 45,
                    totalDuration: 81000,
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
                )
            ],
            totalActiveDays: 28,
            longestStreak: 12,
            currentStreak: 7
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ActivityStatsEntry) -> ()) {
        completion(placeholder(in: context))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ActivityStatsEntry>) -> ()) {
        Task {
            let dataService = WidgetDataService.shared
            
            do {
                let stats = try await dataService.getActivityStats()
                let topActivities = Array(stats.prefix(3)) // Show top 3 activities
                
                let totalActiveDays = Set(stats.flatMap { stat in
                    // This would need actual session dates calculation
                    return [stat.totalSessions] // Simplified
                }).count
                
                let longestStreak = stats.map { $0.bestStreak }.max() ?? 0
                let currentStreak = stats.map { $0.currentStreak }.max() ?? 0
                
                let entry = ActivityStatsEntry(
                    date: Date(),
                    topActivities: topActivities,
                    totalActiveDays: totalActiveDays,
                    longestStreak: longestStreak,
                    currentStreak: currentStreak
                )
                
                // Update once per hour for stats
                let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
                
            } catch {
                let errorEntry = ActivityStatsEntry(
                    date: Date(),
                    topActivities: [],
                    totalActiveDays: 0,
                    longestStreak: 0,
                    currentStreak: 0
                )
                let timeline = Timeline(entries: [errorEntry], policy: .after(Date().addingTimeInterval(3600)))
                completion(timeline)
            }
        }
    }
}

