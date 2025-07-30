import Foundation
import CoreData
import SwiftUI

// MARK: - Activity Extensions
extension Activity {
    
    // MARK: - Computed Properties
    var activityType: ActivityType {
        get {
            return ActivityType(rawValue: type ?? "numeric") ?? .numeric
        }
        set {
            type = newValue.rawValue
        }
    }
    
    var displayColor: Color {
        return Color(hex: color ?? "#CD3A2E")
    }
    
    var displayName: String {
        return name ?? "Unknown Activity"
    }
    
    var isTimerType: Bool {
        return activityType == .timer
    }
    
    var isNumericType: Bool {
        return activityType == .numeric
    }

    private func sessions(for dateRange: ClosedRange<Date>) -> [ActivitySession] {
        guard let allSessions = sessions?.allObjects as? [ActivitySession] else { return [] }
        return allSessions.filter { session in
            guard let sessionDate = session.sessionDate else { return false }
            return dateRange.contains(sessionDate)
        }
    }

    // MARK: - Session Statistics
    func todaysSessions() -> [ActivitySession] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }
        return sessions(for: today...tomorrow)
    }
    
    func todaysTotal() -> Double {
        let todaySessions = todaysSessions()
        
        if isTimerType {
            return todaySessions.reduce(0) { $0 + $1.duration }
        } else {
            return todaySessions.reduce(0) { $0 + $1.numericValue }
        }
    }
    
    func todaysFormattedTotal() -> String {
        let total = todaysTotal()
        
        if isTimerType {
            return formatDuration(total)
        } else {
            return "\(Int(total))"
        }
    }
    
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
    
    func totalForDate(_ date: Date) -> Double {
        guard let sessions = sessions?.allObjects as? [ActivitySession] else { return 0 }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return 0 }
        
        let daySessions = sessions.filter { session in
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
    func currentStreak() -> Int {
        return Int(self.currentStreak)
    }

    func longestStreak() -> Int {
        return Int(self.longestStreak)
    }
    
    // MARK: - Helper Methods
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
struct ValidationResult {
    let isValid: Bool
    let errors: [String]
}

// MARK: - Core Data Fetch Requests
extension Activity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Activity> {
        return NSFetchRequest<Activity>(entityName: "Activity")
    }
    
    static func activitiesFetchRequest() -> NSFetchRequest<Activity> {
        let request: NSFetchRequest<Activity> = Activity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Activity.sortOrder, ascending: true)]
        request.predicate = NSPredicate(format: "%K == %@", #keyPath(Activity.isActive), NSNumber(value: true))
        return request
    }
    
    static func allActivitiesFetchRequest() -> NSFetchRequest<Activity> {
        let request: NSFetchRequest<Activity> = Activity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Activity.createdAt, ascending: false)]
        return request
    }
    
    static func activityByIdFetchRequest(_ id: UUID) -> NSFetchRequest<Activity> {
        let request: NSFetchRequest<Activity> = Activity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return request
    }
}

// MARK: - CloudKit Support
extension Activity {
    
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

