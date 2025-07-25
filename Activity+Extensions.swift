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
    
    // MARK: - Session Statistics
    func todaysSessions() -> [ActivitySession] {
        guard let sessions = sessions?.allObjects as? [ActivitySession] else { return [] }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        return sessions.filter { session in
            guard let sessionDate = session.sessionDate else { return false }
            return sessionDate >= today && sessionDate < tomorrow
        }
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
        guard let sessions = sessions?.allObjects as? [ActivitySession] else { return 0 }
        
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        
        let weeklySessions = sessions.filter { session in
            guard let sessionDate = session.sessionDate else { return false }
            return sessionDate >= weekAgo
        }
        
        if isTimerType {
            return weeklySessions.reduce(0) { $0 + $1.duration }
        } else {
            return weeklySessions.reduce(0) { $0 + $1.numericValue }
        }
    }
    
    func monthlyTotal() -> Double {
        guard let sessions = sessions?.allObjects as? [ActivitySession] else { return 0 }
        
        let calendar = Calendar.current
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: Date())!
        
        let monthlySessions = sessions.filter { session in
            guard let sessionDate = session.sessionDate else { return false }
            return sessionDate >= monthAgo
        }
        
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
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
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
        guard let sessions = sessions?.allObjects as? [ActivitySession] else { return 0 }
        
        let calendar = Calendar.current
        let sortedSessions = sessions
            .compactMap { $0.sessionDate }
            .map { calendar.startOfDay(for: $0) }
            .sorted(by: >)
        
        guard !sortedSessions.isEmpty else { return 0 }
        
        let uniqueDates = Array(Set(sortedSessions)).sorted(by: >)
        let today = calendar.startOfDay(for: Date())
        
        var streak = 0
        var currentDate = today
        
        for date in uniqueDates {
            if calendar.isDate(date, inSameDayAs: currentDate) {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else if date < currentDate {
                break
            }
        }
        
        return streak
    }
    
    func longestStreak() -> Int {
        guard let sessions = sessions?.allObjects as? [ActivitySession] else { return 0 }
        
        let calendar = Calendar.current
        let uniqueDates = Array(Set(sessions
            .compactMap { $0.sessionDate }
            .map { calendar.startOfDay(for: $0) }
        )).sorted()
        
        guard !uniqueDates.isEmpty else { return 0 }
        
        var maxStreak = 1
        var currentStreak = 1
        
        for i in 1..<uniqueDates.count {
            let previousDate = uniqueDates[i - 1]
            let currentDate = uniqueDates[i]
            
            if calendar.dateInterval(of: .day, for: previousDate)?.end == currentDate {
                currentStreak += 1
                maxStreak = max(maxStreak, currentStreak)
            } else {
                currentStreak = 1
            }
        }
        
        return maxStreak
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
        request.predicate = NSPredicate(format: "isActive == %@", NSNumber(value: true))
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

