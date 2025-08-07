import Foundation
import CoreData
import SwiftUI

/// Extensions on the ``Activity`` Core Data entity that provide statistics
/// calculated directly in the database for improved performance.  These
/// implementations replace the earlier in‑memory reductions and push
/// aggregation into ``NSPersistentStoreCoordinator`` using
/// ``NSExpressionDescription``.
extension Activity {
    /// Helper that performs a sum over either the ``duration`` or
    /// ``numericValue`` property of associated ``ActivitySession`` objects
    /// constrained to a date range.  It returns the total as a ``Double``.
    private func totalValue(for dateRange: ClosedRange<Date>) -> Double {
        guard let context = self.managedObjectContext else { return 0.0 }
        let request = NSFetchRequest<NSDictionary>(entityName: "ActivitySession")
        request.resultType = .dictionaryResultType

        let expressionDescription = NSExpressionDescription()
        expressionDescription.name = "totalValue"
        // Choose the key path based on the activity type.
        let valueKeyPath = isTimerType ? #keyPath(ActivitySession.duration) : #keyPath(ActivitySession.numericValue)
        expressionDescription.expression = NSExpression(forFunction: "sum:", arguments: [NSExpression(forKeyPath: valueKeyPath)])
        expressionDescription.expressionResultType = .doubleAttributeType

        request.propertiesToFetch = [expressionDescription]
        request.predicate = NSPredicate(format: "activity == %@ AND sessionDate >= %@ AND sessionDate <= %@",
                                        self, dateRange.lowerBound as NSDate, dateRange.upperBound as NSDate)

        do {
            let result = try context.fetch(request)
            return (result.first?["totalValue"] as? Double) ?? 0.0
        } catch {
            AppLogger.error("Failed to perform aggregation fetch: \(error)")
            return 0.0
        }
    }

    /// Total for the current day.  Calculates the start and end of the day
    /// using ``Calendar.current`` and defers computation to ``totalValue(for:)``.
    func todaysTotal() -> Double {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        guard let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) else { return 0 }
        return totalValue(for: todayStart...todayEnd)
    }

    /// Total for the previous seven days.  Uses DST‑safe calendar math to
    /// calculate the lower bound and defers to ``totalValue(for:)``.
    func weeklyTotal() -> Double {
        // Calculate "one week ago" using noon as a safe anchor to avoid
        // daylight saving transitions that can make midnight ambiguous.
        let calendar = Calendar.current
        let now = Date()
        let safeNow = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
        guard let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: safeNow) else { return 0 }
        return totalValue(for: weekAgo...now)
    }

    /// Total for the previous month.  Calculates the date one month ago and
    /// defers to ``totalValue(for:)``.
    func monthlyTotal() -> Double {
        guard let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) else { return 0 }
        return totalValue(for: monthAgo...Date())
    }
}

// MARK: - Display & Type Helpers
extension Activity {
    var displayName: String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? NSLocalizedString("activity.untitled", comment: "") : trimmed
    }

    var activityType: ActivityType {
        ActivityType(rawValue: type ?? ActivityType.numeric.rawValue) ?? .numeric
    }

    var isTimerType: Bool { activityType == .timer }
    var isNumericType: Bool { activityType == .numeric }

    var displayColor: Color {
        let hex = color ?? (DesignSystem.Colors.activityColors.first ?? "#000000")
        return Color(hex: hex)
    }

    func todaysFormattedTotal() -> String {
        let total = todaysTotal()
        if isTimerType {
            let minutes = Int(total / 60)
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return hours > 0 ? "\(hours)h \(remainingMinutes)m" : "\(remainingMinutes)m"
        } else {
            return "\(Int(total))"
        }
    }
}

// MARK: - Validation
extension Activity {
    func validate() -> ValidationResult {
        var errors: [String] = []

        let trimmedName = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { errors.append("Activity name cannot be empty") }

        if let rawType = type, ActivityType(rawValue: rawType) == nil {
            errors.append("Invalid activity type")
        }

        if let hex = color {
            let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            let isValidHex = CharacterSet(charactersIn: trimmed).isSubset(of: CharacterSet(charactersIn: "0123456789ABCDEFabcdef")) && (trimmed.count == 6 || trimmed.count == 8 || trimmed.count == 3)
            if !isValidHex { errors.append("Invalid color value") }
        } else {
            errors.append("Activity color must be selected")
        }

        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
}

// MARK: - Streaks
extension Activity {
    /// Returns the current and longest streak lengths in days based on sessions associated with this activity.
    static func calculateStreaks(for activity: Activity) -> (current: Int, longest: Int) {
        guard let context = activity.managedObjectContext else { return (0, 0) }

        let request: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
        request.predicate = NSPredicate(format: "activity == %@", activity)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ActivitySession.sessionDate, ascending: true)]

        do {
            let sessions = try context.fetch(request)
            // Build a sorted unique set of days that have at least one session
            let calendar = Calendar.current
            let days: [Date] = Array(Set(sessions.compactMap { $0.sessionDate }.map { calendar.startOfDay(for: $0) })).sorted()

            var longest = 0
            var currentRun = 0
            var previousDay: Date?

            for day in days {
                if let prev = previousDay, calendar.date(byAdding: .day, value: 1, to: prev) == day {
                    currentRun += 1
                } else {
                    currentRun = 1
                }
                longest = max(longest, currentRun)
                previousDay = day
            }

            // Compute current streak ending today (or yesterday if no entry today)
            var current = 0
            if let mostRecent = days.last {
                let startOfToday = calendar.startOfDay(for: Date())
                let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday

                if mostRecent == startOfToday || mostRecent == startOfYesterday {
                    // Walk backwards while consecutive
                    current = 1
                    var idx = days.count - 1
                    var cursor = days[idx]
                    while idx > 0 {
                        let prior = days[idx - 1]
                        if calendar.date(byAdding: .day, value: -1, to: cursor) == prior {
                            current += 1
                            idx -= 1
                            cursor = prior
                        } else {
                            break
                        }
                    }
                } else {
                    current = 0
                }
            }

            return (current, longest)
        } catch {
            AppLogger.error("Failed calculating streaks: \(error)")
            return (0, 0)
        }
    }

    func currentStreak() -> Int { Self.calculateStreaks(for: self).current }
    func longestStreak() -> Int { Self.calculateStreaks(for: self).longest }
}

// MARK: - Fetch Helpers
extension Activity {
    static func activityByIdFetchRequest(_ id: UUID) -> NSFetchRequest<Activity> {
        let request: NSFetchRequest<Activity> = Activity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return request
    }
}