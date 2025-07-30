import Foundation
import CoreData
import SwiftUI

// MARK: - ActivitySession Extensions
extension ActivitySession {
    
    // MARK: - Computed Properties
    var displayDate: String? {
        guard let sessionDate = sessionDate else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: sessionDate)
    }
    
    var formattedDuration: String {
        if duration > 0 {
            return formatDuration(duration)
        }
        return "0min"
    }
    
    var formattedNumericValue: String {
        return "\(Int(numericValue))"
    }
    
    var displayValue: String {
        guard let activity = activity else { return "0" }
        
        if activity.isTimerType {
            return formattedDuration
        } else {
            return formattedNumericValue
        }
    }
    
    var isToday: Bool {
        guard let sessionDate = sessionDate else { return false }
        return Calendar.current.isDateInToday(sessionDate)
    }
    
    var isThisWeek: Bool {
        guard let sessionDate = sessionDate else { return false }
        
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: Date())
        let sessionWeekOfYear = calendar.component(.weekOfYear, from: sessionDate)
        let year = calendar.component(.year, from: Date())
        let sessionYear = calendar.component(.year, from: sessionDate)
        
        return weekOfYear == sessionWeekOfYear && year == sessionYear
    }
    
    var isThisMonth: Bool {
        guard let sessionDate = sessionDate else { return false }
        
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        let sessionMonth = calendar.component(.month, from: sessionDate)
        let year = calendar.component(.year, from: Date())
        let sessionYear = calendar.component(.year, from: sessionDate)
        
        return month == sessionMonth && year == sessionYear
    }
    
    // MARK: - Helper Methods
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm", minutes)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    func formatDurationDetailed() -> String {
        let totalMinutes = Int(duration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - Validation
    func validate() -> ValidationResult {
        var errors: [String] = []
        
        if activity == nil {
            errors.append("Session must be associated with an activity")
        }
        
        if sessionDate == nil {
            errors.append("Session must have a valid date")
        }
        
        if let activity = activity {
            if activity.isTimerType && duration <= 0 {
                errors.append("Timer sessions must have a positive duration")
            }
            
            if activity.isNumericType && numericValue <= 0 {
                errors.append("Numeric sessions must have a positive value")
            }
        }
        
        if let sessionDate = sessionDate, sessionDate > Date() {
            errors.append("Session date cannot be in the future")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // MARK: - Comparison
    func isSameDay(as otherSession: ActivitySession) -> Bool {
        guard let thisDate = sessionDate,
              let otherDate = otherSession.sessionDate else { return false }
        
        return Calendar.current.isDate(thisDate, inSameDayAs: otherDate)
    }
    
    func isSameDay(as date: Date) -> Bool {
        guard let sessionDate = sessionDate else { return false }
        return Calendar.current.isDate(sessionDate, inSameDayAs: date)
    }
}

// MARK: - Core Data Fetch Requests
extension ActivitySession {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ActivitySession> {
        return NSFetchRequest<ActivitySession>(entityName: "ActivitySession")
    }
    
    static func sessionsFetchRequest() -> NSFetchRequest<ActivitySession> {
        let request: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ActivitySession.sessionDate, ascending: false)]
        return request
    }
    
    static func sessionsForActivityFetchRequest(_ activity: Activity) -> NSFetchRequest<ActivitySession> {
        let request: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
        request.predicate = NSPredicate(format: "activity == %@", activity)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ActivitySession.sessionDate, ascending: false)]
        return request
    }
    
    static func sessionsForDateFetchRequest(_ date: Date) -> NSFetchRequest<ActivitySession> {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return NSFetchRequest<ActivitySession>() }
        
        let request: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
        request.predicate = NSPredicate(format: "sessionDate >= %@ AND sessionDate < %@", 
                                      startOfDay as NSDate, endOfDay as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ActivitySession.sessionDate, ascending: false)]
        return request
    }
    
    static func sessionsForActivityAndDateFetchRequest(_ activity: Activity, date: Date) -> NSFetchRequest<ActivitySession> {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return NSFetchRequest<ActivitySession>() }
        
        let request: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
        request.predicate = NSPredicate(format: "activity == %@ AND sessionDate >= %@ AND sessionDate < %@", 
                                      activity, startOfDay as NSDate, endOfDay as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ActivitySession.sessionDate, ascending: false)]
        return request
    }
    
    static func recentSessionsFetchRequest(limit: Int = 50) -> NSFetchRequest<ActivitySession> {
        let request: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ActivitySession.sessionDate, ascending: false)]
        request.fetchLimit = limit
        return request
    }
}

// MARK: - CloudKit Support
extension ActivitySession {
    
    var cloudKitRecord: [String: Any] {
        return [
            "id": id?.uuidString ?? "",
            "activityId": activity?.id?.uuidString ?? "",
            "sessionDate": sessionDate ?? Date(),
            "duration": duration,
            "numericValue": numericValue,
            "isCompleted": isCompleted,
            "createdAt": createdAt ?? Date(),
            "updatedAt": updatedAt ?? Date()
        ]
    }
    
    func updateFromCloudKit(_ record: [String: Any], context: NSManagedObjectContext) {
        if let idString = record["id"] as? String {
            id = UUID(uuidString: idString)
        }
        
        if let activityIdString = record["activityId"] as? String,
           let activityId = UUID(uuidString: activityIdString) {
            // Find the activity by ID
            let request = Activity.activityByIdFetchRequest(activityId)
            if let foundActivity = try? context.fetch(request).first {
                activity = foundActivity
            }
        }
        
        sessionDate = record["sessionDate"] as? Date
        duration = record["duration"] as? Double ?? 0
        numericValue = record["numericValue"] as? Double ?? 0
        isCompleted = record["isCompleted"] as? Bool ?? false
        createdAt = record["createdAt"] as? Date
        updatedAt = record["updatedAt"] as? Date
    }
}

// MARK: - Statistics Extensions
extension ActivitySession {
    
    static func totalDurationForActivity(_ activity: Activity, in context: NSManagedObjectContext) -> TimeInterval {
        let request = sessionsForActivityFetchRequest(activity)
        
        do {
            let sessions = try context.fetch(request)
            return sessions.reduce(0) { $0 + $1.duration }
        } catch {
            AppLogger.error("Error fetching sessions for total duration: \(error)")
            return 0
        }
    }
    
    static func totalCountForActivity(_ activity: Activity, in context: NSManagedObjectContext) -> Double {
        let request = sessionsForActivityFetchRequest(activity)
        
        do {
            let sessions = try context.fetch(request)
            return sessions.reduce(0) { $0 + $1.numericValue }
        } catch {
            AppLogger.error("Error fetching sessions for total count: \(error)")
            return 0
        }
    }
    
    static func averageDurationForActivity(_ activity: Activity, in context: NSManagedObjectContext) -> TimeInterval {
        let request = sessionsForActivityFetchRequest(activity)
        
        do {
            let sessions = try context.fetch(request).filter { $0.duration > 0 }
            guard !sessions.isEmpty else { return 0 }
            
            let totalDuration = sessions.reduce(0) { $0 + $1.duration }
            return totalDuration / Double(sessions.count)
        } catch {
            AppLogger.error("Error fetching sessions for average duration: \(error)")
            return 0
        }
    }
    
    static func sessionsCountForActivity(_ activity: Activity, in context: NSManagedObjectContext) -> Int {
        let request = sessionsForActivityFetchRequest(activity)
        
        do {
            return try context.count(for: request)
        } catch {
            AppLogger.error("Error counting sessions: \(error)")
            return 0
        }
    }
}

