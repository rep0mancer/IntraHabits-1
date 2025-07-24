import Foundation
import CoreData

// MARK: - Data Service Protocol
@MainActor
protocol DataServiceProtocol {
    // Activity
    func fetchActivities() async throws -> [Activity]
    func createActivity(name: String, type: ActivityType, color: String) async throws -> Activity
    func updateActivity(_ activity: Activity) async throws -> Activity
    func deleteActivity(_ activity: Activity) async throws
    func reorderActivities(_ activities: [Activity]) async throws

    // Sessions
    func fetchSessions(for activity: Activity, date: Date?) async throws -> [ActivitySession]
    func createSession(for activity: Activity, duration: TimeInterval?, numericValue: Double?) async throws -> ActivitySession
    func updateSession(_ session: ActivitySession) async throws -> ActivitySession
    func deleteSession(_ session: ActivitySession) async throws

    // Data export
    func exportData() async throws -> Data
    func resetAllData() async throws

    // Statistics
    func getTodayTotal(for activity: Activity) async throws -> Double
    func getWeeklyTotal(for activity: Activity) async throws -> Double
    func getCurrentStreak(for activity: Activity) async throws -> Int
}

// MARK: - Core Data Service Implementation
@MainActor
class CoreDataService: DataServiceProtocol {
    private let persistentContainer: NSPersistentCloudKitContainer
    private let context: NSManagedObjectContext

    init(container: NSPersistentCloudKitContainer) {
        self.persistentContainer = container
        self.context = container.viewContext
    }

    // MARK: - Activity Operations
    func fetchActivities() async throws -> [Activity] {
        try await context.perform {
            let request = Activity.activitiesFetchRequest()
            return try self.context.fetch(request)
        }
    }

    func createActivity(name: String, type: ActivityType, color: String) async throws -> Activity {
        try await context.perform {
            let countRequest: NSFetchRequest<Activity> = Activity.fetchRequest()
            countRequest.predicate = NSPredicate(format: "isActive == %@", NSNumber(value: true))
            let existingCount = try self.context.count(for: countRequest)

            let hasUnlimitedActivities = StoreKitService.shared.hasUnlimitedActivities
            if existingCount >= 5 && !hasUnlimitedActivities {
                throw DataServiceError.activityLimitReached
            }

            let activity = Activity(context: self.context)
            activity.id = UUID()
            activity.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            activity.type = type.rawValue
            activity.color = color
            activity.createdAt = Date()
            activity.updatedAt = Date()
            activity.isActive = true
            activity.sortOrder = Int32(existingCount)

            try self.context.save()
            return activity
        }
    }

    func updateActivity(_ activity: Activity) async throws -> Activity {
        try await context.perform {
            activity.updatedAt = Date()
            try self.context.save()
            return activity
        }
    }

    func deleteActivity(_ activity: Activity) async throws {
        try await context.perform {
            activity.isActive = false
            activity.updatedAt = Date()
            try self.context.save()
        }
    }

    func reorderActivities(_ activities: [Activity]) async throws {
        try await context.perform {
            for (index, activity) in activities.enumerated() {
                activity.sortOrder = Int32(index)
                activity.updatedAt = Date()
            }
            try self.context.save()
        }
    }

    // MARK: - Session Operations
    func fetchSessions(for activity: Activity, date: Date? = nil) async throws -> [ActivitySession] {
        try await context.perform {
            let request = ActivitySession.sessionsForActivityFetchRequest(activity)
            // Add date filtering if needed
            if let date = date {
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: date)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "activity == %@", activity),
                    NSPredicate(format: "sessionDate >= %@ AND sessionDate < %@", startOfDay as NSDate, endOfDay as NSDate)
                ])
            }
            return try self.context.fetch(request)
        }
    }

    func createSession(for activity: Activity, duration: TimeInterval? = nil, numericValue: Double? = nil) async throws -> ActivitySession {
        try await context.perform {
            let session = ActivitySession(context: self.context)
            session.id = UUID()
            session.activity = activity
            session.sessionDate = Date()
            session.createdAt = Date()
            session.updatedAt = Date()
            session.isCompleted = true

            if let duration = duration { session.duration = duration }
            if let numericValue = numericValue { session.numericValue = numericValue }

            try self.context.save()
            return session
        }
    }

    func updateSession(_ session: ActivitySession) async throws -> ActivitySession {
        try await context.perform {
            session.updatedAt = Date()
            try self.context.save()
            return session
        }
    }

    func deleteSession(_ session: ActivitySession) async throws {
        try await context.perform {
            self.context.delete(session)
            try self.context.save()
        }
    }

    // MARK: - Data Management
    func exportData() async throws -> Data {
        try await context.perform {
            let activityRequest: NSFetchRequest<Activity> = Activity.fetchRequest()
            let sessionRequest: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()

            let activities = try self.context.fetch(activityRequest)
            let sessions = try self.context.fetch(sessionRequest)

            let exportData = ExportData(
                activities: activities.map { ActivityExport(from: $0) },
                sessions: sessions.map { SessionExport(from: $0) },
                exportDate: Date()
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(exportData)
        }
    }

    func resetAllData() async throws {
        try await context.perform {
            let activityRequest: NSFetchRequest<NSFetchRequestResult> = Activity.fetchRequest()
            let sessionRequest: NSFetchRequest<NSFetchRequestResult> = ActivitySession.fetchRequest()

            let activityDeleteRequest = NSBatchDeleteRequest(fetchRequest: activityRequest)
            let sessionDeleteRequest = NSBatchDeleteRequest(fetchRequest: sessionRequest)

            try self.context.execute(sessionDeleteRequest)
            try self.context.execute(activityDeleteRequest)
            try self.context.save()
        }
    }

    // MARK: - Statistics
    func getTodayTotal(for activity: Activity) async throws -> Double {
        try await context.perform { activity.todaysTotal() }
    }

    func getWeeklyTotal(for activity: Activity) async throws -> Double {
        try await context.perform { activity.weeklyTotal() }
    }

    func getCurrentStreak(for activity: Activity) async throws -> Int {
        try await context.perform { activity.currentStreak() }
    }
}

// MARK: - Data Service Errors
enum DataServiceError: LocalizedError {
    case contextNotAvailable
    case activityLimitReached
    case invalidData
    case syncFailed
    case validationError(String)

    var errorDescription: String? {
        switch self {
        case .contextNotAvailable:
            return "Database context is not available"
        case .activityLimitReached:
            return "You've reached the limit of 5 free activities. Upgrade to add more."
        case .invalidData:
            return "The provided data is invalid"
        case .syncFailed:
            return "Failed to sync with iCloud"
        case .validationError(let message):
            return message
        }
    }
}

