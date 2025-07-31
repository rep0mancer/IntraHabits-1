import Foundation
import CoreData

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
        // Use the calendar's ``weekOfYear`` component to subtract one week
        // rather than seven days.  This avoids bugs around daylight saving
        // transitions where a day is not always 24 hours long.
        guard let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) else { return 0 }
        return totalValue(for: weekAgo...Date())
    }

    /// Total for the previous month.  Calculates the date one month ago and
    /// defers to ``totalValue(for:)``.
    func monthlyTotal() -> Double {
        guard let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) else { return 0 }
        return totalValue(for: monthAgo...Date())
    }
}