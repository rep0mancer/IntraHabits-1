import Foundation
import CoreData
import SwiftUI

// MARK: - Activity Extensions
extension Activity {
    // MARK: - Computed Properties
    /// Returns the strongly‑typed `ActivityType` for this activity. Defaults to `.numeric`.
    var activityType: ActivityType {
        get {
            return ActivityType(rawValue: type ?? "numeric") ?? .numeric
        }
        set {
            type = newValue.rawValue
        }
    }

    /// Convenience wrapper to access the activity color as a SwiftUI `Color`.
    var displayColor: Color {
        return Color(hex: color ?? "#CD3A2E")
    }

    /// Returns a non‑optional display name for the activity.
    var displayName: String {
        return name ?? "Unknown Activity"
    }

    /// Returns `true` when the activity is timer based.
    var isTimerType: Bool {
        return activityType == .timer
    }

    /// Returns `true` when the activity is numeric based.
    var isNumericType: Bool {
        return activityType == .numeric
    }

    /// Filters the associated sessions to those that fall within the provided date range.
    private func sessions(for dateRange: ClosedRange<Date>) -> [ActivitySession] {
        guard let allSessions = sessions?.allObjects as? [ActivitySession] else { return [] }
        return allSessions.filter { session in
            guard let sessionDate = session.sessionDate else { return false }
            return dateRange.contains(sessionDate)
        }
    }

    // MARK: - Session Statistics
    /// Returns all sessions that occur today.
    func todaysSessions() -> [ActivitySession] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }
        return sessions(for: today...tomorrow)
    }

    /// Returns the total value for all of today's sessions. For timer activities this is the sum of durations; for numeric activities it is the sum of numeric values.
    func todaysTotal() -> Double {
        let todaySessions = todaysSessions()
        if isTimerType {
            return todaySessions.reduce(0) { $0 + $1.duration }
        } else {
            return todaySessions.reduce(0) { $0 + $1.numericValue }
        }
    }

    /// Returns a formatted string of today's total depending on the activity type.
    func todaysFormattedTotal() -> String {
        let total = todaysTotal()
        if isTimerType {
            return formatDuration(total)
        } else {
            return "\(Int(total))"
        }
    }

    /// Returns the total value for the last seven days.
    func weeklyTotal() -> Double {
        let calendar = Calendar.current
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else { return 0 }
        let range = weekAgo...Date()
        let weeklySessions = sessions(for: range)
        if isTimerType {
            return weeklySessions.reduce(0) { $0 + $1.duration }
        } else {
            return weeklySessions.reduce(0) { $0 + $1.numericValue }
        }
    }

    /// Returns the total value for the last month.
    func monthlyTotal() -> Double {
        let calendar = Calendar.current
        guard let monthAgo = calendar.date(byAdding: .month, value: -1, to: Date()) else { return 0 }
        let range = monthAgo...Date()
        let monthlySessions = sessions(for: range)
        if isTimerType {
            return monthlySessions.reduce(0) { $0 + $1.duration }
        } else {
            return monthlySessions.reduce(0) { $0 + $1.numericValue }
        }
    }

    /// Returns the total value for a specific date.
    func totalForDate(_ date: Date) -> Double {
        guard let allSessions = sessions?.allObjects as? [ActivitySession] else { return 0 }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return 0 }
        let daySessions = allSessions.filter { session in
            guard let sessionDate = session.sessionDate else { return false }
            return sessionDate >= startOfDay && sessionDate < endOfDay
        }
        if isTimerType {
            return daySessions.reduce(0) { $0 + $1.duration }
        } else {
            return daySessions.reduce(0) { $0 + $1.numericValue }
        }
    }

    // MARK: - Streak Calculation
    /// Retrieves the current streak stored on the activity.
    func currentStreak() -> Int {
        return Int(self.currentStreak)
    }

    /// Retrieves the longest streak stored on the activity.
    func longestStreak() -> Int {
        return Int(self.longestStreak)
    }

    /// Calculates both the current and longest streaks for the provided activity. A streak is defined as consecutive days with at least one completed session.
    /// - Parameter activity: The activity whose sessions should be analysed.
    /// - Returns: A tuple containing the current streak and the longest streak.
    static func calculateStreaks(for activity: Activity) -> (current: Int, longest: Int) {
        // If there are no sessions associated with the activity, both streaks are zero.
        guard let sessions = activity.sessions?.allObjects as? [ActivitySession], !sessions.isEmpty else {
            return (current: 0, longest: 0)
        }
        let calendar = Calendar.current
        // Reduce the session dates down to unique start-of-day dates.
        let sessionDates = sessions.compactMap { $0.sessionDate }.map { calendar.startOfDay(for: $0) }
        let uniqueDates = Set(sessionDates)
        // Compute the current streak by walking backwards from today until a gap is encountered.
        var currentStreakCount = 0
        var datePointer = calendar.startOfDay(for: Date())
        while uniqueDates.contains(datePointer) {
            currentStreakCount += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: datePointer) else {
                break
            }
            datePointer = previousDay
        }
        // Compute the longest streak by scanning through the sorted list of dates.
        let sortedDates = uniqueDates.sorted()
        var longestStreakCount = 0
        var currentRun = 0
        var previousDate: Date? = nil
        for date in sortedDates {
            if let prev = previousDate,
               let expected = calendar.date(byAdding: .day, value: 1, to: prev),
               calendar.isDate(date, inSameDayAs: expected) {
                // Continues the run of consecutive days.
                currentRun += 1
            } else {
                // Either this is the first date or there is a gap; reset the run.
                currentRun = 1
            }
            longestStreakCount = max(longestStreakCount, currentRun)
            previousDate = date
        }
        return (current: currentStreakCount, longest: longestStreakCount)
    }

    /// Formats a duration in seconds into a human readable string of hours and minutes.
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)min"
        } else {
            return "\(remainingMinutes)min"
        }
    }

    // MARK: - Validation
    /// Performs a series of validations on the activity and returns a `ValidationResult` describing any failures.
    func validate() -> ValidationResult {
        var errors: [String] = []
        if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Activity name cannot be empty")
        }
        if displayName.count > 50 {
            errors.append("Activity name cannot exceed 50 characters")
        }
        if !DesignSystem.Colors.activityColors.contains(color ?? "") {
            errors.append("Invalid activity color")
        }
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
}

// MARK: - Validation Result
/// Represents the outcome of an activity validation check.
struct ValidationResult {
    let isValid: Bool
    let errors: [String]
}

// MARK: - Core Data Fetch Requests
extension Activity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Activity> {
        return NSFetchRequest<Activity>(entityName: "Activity")
    }

    /// A convenience fetch request that returns all active activities sorted by their sort order.
    static func activitiesFetchRequest() -> NSFetchRequest<Activity> {
        let request: NSFetchRequest<Activity> = Activity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Activity.sortOrder, ascending: true)]
        request.predicate = NSPredicate(format: "%K == %@", #keyPath(Activity.isActive), NSNumber(value: true))
        return request
    }

    /// A fetch request that returns all activities sorted by creation date descending.
    static func allActivitiesFetchRequest() -> NSFetchRequest<Activity> {
        let request: NSFetchRequest<Activity> = Activity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Activity.createdAt, ascending: false)]
        return request
    }

    /// Returns a fetch request for a single activity by id.
    static func activityByIdFetchRequest(_ id: UUID) -> NSFetchRequest<Activity> {
        let request: NSFetchRequest<Activity> = Activity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return request
    }
}

// MARK: - CloudKit Support
extension Activity {
    /// A representation of the activity suitable for upload to CloudKit.
    var cloudKitRecord: [String: Any] {
        return [
            "id": id?.uuidString ?? "",
            "name": name ?? "",
            "type": type ?? "numeric",
            "color": color ?? "#CD3A2E",
            "createdAt": createdAt ?? Date(),
            "updatedAt": updatedAt ?? Date(),
            "isActive": isActive,
            "sortOrder": sortOrder
        ]
    }

    /// Updates the activity's properties from a CloudKit record dictionary.
    func updateFromCloudKit(_ record: [String: Any]) {
        if let idString = record["id"] as? String {
            id = UUID(uuidString: idString)
        }
        name = record["name"] as? String
        type = record["type"] as? String
        color = record["color"] as? String
        createdAt = record["createdAt"] as? Date
        updatedAt = record["updatedAt"] as? Date
        isActive = record["isActive"] as? Bool ?? true
        sortOrder = record["sortOrder"] as? Int32 ?? 0
    }
}