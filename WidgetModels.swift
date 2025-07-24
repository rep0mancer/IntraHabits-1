import Foundation
import AppIntents
import SwiftUI

// MARK: - Activity Entity for App Intents
struct ActivityEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Activity"
    static var defaultQuery = ActivityEntityQuery()
    
    var id: String
    var name: String
    var type: String // "numeric" or "timer"
    var color: String
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    
    init(id: String, name: String, type: String, color: String) {
        self.id = id
        self.name = name
        self.type = type
        self.color = color
    }
}

// MARK: - Activity Entity Query
struct ActivityEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ActivityEntity] {
        let dataService = WidgetDataService.shared
        return try await dataService.getActivities(withIds: identifiers)
    }
    
    func suggestedEntities() async throws -> [ActivityEntity] {
        let dataService = WidgetDataService.shared
        return try await dataService.getAllActivities()
    }
    
    func defaultResult() async -> ActivityEntity? {
        let dataService = WidgetDataService.shared
        let activities = try? await dataService.getAllActivities()
        return activities?.first
    }
}

// MARK: - Widget Entry Models
struct ActivityQuickActionsEntry: TimelineEntry {
    let date: Date
    let activity: ActivityEntity?
    let todaysSessions: [WidgetSession]
    let isTimerRunning: Bool
    let currentTimerDuration: TimeInterval
    let configuration: SelectActivityIntent
}

struct TodaysProgressEntry: TimelineEntry {
    let date: Date
    let activities: [WidgetActivityProgress]
    let totalSessions: Int
    let totalDuration: TimeInterval
}

struct ActivityTimerEntry: TimelineEntry {
    let date: Date
    let activity: ActivityEntity?
    let isRunning: Bool
    let isPaused: Bool
    let currentDuration: TimeInterval
    let todaysTotal: TimeInterval
    let configuration: SelectTimerActivityIntent
}

struct ActivityStatsEntry: TimelineEntry {
    let date: Date
    let topActivities: [WidgetActivityStats]
    let totalActiveDays: Int
    let longestStreak: Int
    let currentStreak: Int
}

// MARK: - Supporting Data Models
struct WidgetSession {
    let id: String
    let activityId: String
    let date: Date
    let numericValue: Double?
    let duration: TimeInterval?
    let isCompleted: Bool
}

struct WidgetActivityProgress {
    let id: String
    let name: String
    let color: String
    let type: String
    let todaysSessions: Int
    let todaysDuration: TimeInterval
    let todaysNumericTotal: Double
    let targetValue: Double?
    let progressPercentage: Double
}

struct WidgetActivityStats {
    let id: String
    let name: String
    let color: String
    let type: String
    let totalSessions: Int
    let totalDuration: TimeInterval
    let totalNumericValue: Double
    let currentStreak: Int
    let bestStreak: Int
    let averagePerDay: Double
}

// MARK: - Timer State Model
struct WidgetTimerState {
    let activityId: String
    let isRunning: Bool
    let isPaused: Bool
    let startTime: Date?
    let pausedDuration: TimeInterval
    let totalDuration: TimeInterval
    
    var currentDuration: TimeInterval {
        guard isRunning, let startTime = startTime else {
            return totalDuration + pausedDuration
        }
        
        if isPaused {
            return totalDuration + pausedDuration
        } else {
            return totalDuration + pausedDuration + Date().timeIntervalSince(startTime)
        }
    }
}

// MARK: - Widget Configuration
struct WidgetConfiguration {
    static let maxActivitiesInWidget = 4
    static let refreshInterval: TimeInterval = 300 // 5 minutes
    static let timerRefreshInterval: TimeInterval = 30 // 30 seconds for active timers
    
    // Widget colors matching app design
    static let primaryColor = Color(red: 0.8, green: 0.23, blue: 0.18) // #CD3A2E
    static let tealColor = Color(red: 0, green: 0.55, blue: 0.55) // #008C8C
    static let indigoColor = Color(red: 0.29, green: 0.36, blue: 0.77) // #4B5CC4
    static let amberColor = Color(red: 0.96, green: 0.69, blue: 0.26) // #F6B042
    
    static func colorForActivity(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "red": return primaryColor
        case "teal": return tealColor
        case "indigo": return indigoColor
        case "amber": return amberColor
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "brown": return .brown
        default: return primaryColor
        }
    }
}

// MARK: - Widget Error Types
enum WidgetError: Error, LocalizedError {
    case noActivities
    case activityNotFound
    case timerNotRunning
    case dataServiceError(String)
    case invalidConfiguration
    
    var errorDescription: String? {
        switch self {
        case .noActivities:
            return "No activities found. Create activities in the main app first."
        case .activityNotFound:
            return "Selected activity not found."
        case .timerNotRunning:
            return "Timer is not currently running."
        case .dataServiceError(let message):
            return "Data error: \(message)"
        case .invalidConfiguration:
            return "Invalid widget configuration."
        }
    }
}

