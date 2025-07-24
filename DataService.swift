import Foundation
import CoreData
import CloudKit
import Combine

// MARK: - Data Service Protocol
@MainActor
protocol DataServiceProtocol {
    func fetchActivities() async throws -> [Activity]
    func createActivity(name: String, type: ActivityType, color: String) async throws -> Activity
    func updateActivity(_ activity: Activity) async throws -> Activity
    func deleteActivity(_ activity: Activity) async throws
    func reorderActivities(_ activities: [Activity]) async throws

    func fetchSessions(for activity: Activity, date: Date?) async throws -> [ActivitySession]
    func createSession(for activity: Activity, duration: TimeInterval?, numericValue: Double?) async throws -> ActivitySession
    func updateSession(_ session: ActivitySession) async throws -> ActivitySession
    func deleteSession(_ session: ActivitySession) async throws

    func exportData() async throws -> Data
    func resetAllData() async throws
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

            // TODO: Check premium subscription status from StoreKitService
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
            let request: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ActivitySession.sessionDate, ascending: false)]

            var predicates = [NSPredicate(format: "activity == %@", activity)]

            if let date = date {
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: date)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                predicates.append(NSPredicate(format: "sessionDate >= %@ AND sessionDate < %@",
                                            startOfDay as NSDate, endOfDay as NSDate))
            }

            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

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

            if let duration = duration {
                session.duration = duration
            }

            if let numericValue = numericValue {
                session.numericValue = numericValue
            }

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
}

// MARK: - Async/Await Data Service
class DataService {
    private let persistenceController: PersistenceController
    private var context: NSManagedObjectContext { persistenceController.container.viewContext }

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    // MARK: - Activity Operations
    func createActivity(name: String, type: String, color: String) async throws -> Activity {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DataServiceError.validationError("Activity name cannot be empty")
        }
        guard let activityType = ActivityType(rawValue: type) else {
            throw DataServiceError.validationError("Invalid activity type")
        }

        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let countRequest: NSFetchRequest<Activity> = Activity.fetchRequest()
                    countRequest.predicate = NSPredicate(format: "isActive == %@", NSNumber(value: true))
                    let existingCount = try self.context.count(for: countRequest)

                    let activity = Activity(context: self.context)
                    activity.id = UUID()
                    activity.name = trimmed
                    activity.type = activityType.rawValue
                    activity.color = color
                    activity.createdAt = Date()
                    activity.updatedAt = Date()
                    activity.isActive = true
                    activity.sortOrder = Int32(existingCount)

                    try self.context.save()
                    continuation.resume(returning: activity)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchActivities() async throws -> [Activity] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = Activity.activitiesFetchRequest()
                    let activities = try self.context.fetch(request)
                    continuation.resume(returning: activities)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func updateActivity(_ activity: Activity, name: String, type: String, color: String) async throws -> Activity {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DataServiceError.validationError("Activity name cannot be empty")
        }
        guard let activityType = ActivityType(rawValue: type) else {
            throw DataServiceError.validationError("Invalid activity type")
        }

        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    activity.name = trimmed
                    activity.type = activityType.rawValue
                    activity.color = color
                    activity.updatedAt = Date()
                    try self.context.save()
                    continuation.resume(returning: activity)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteActivity(_ activity: Activity) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    activity.isActive = false
                    activity.updatedAt = Date()
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Session Operations
    func createSession(for activity: Activity, sessionDate: Date, numericValue: Double?, duration: TimeInterval?) async throws -> ActivitySession {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let session = ActivitySession(context: self.context)
                    session.id = UUID()
                    session.activity = activity
                    session.sessionDate = sessionDate
                    session.numericValue = numericValue ?? 0
                    session.duration = duration ?? 0
                    session.isCompleted = true
                    session.createdAt = Date()
                    session.updatedAt = Date()
                    try self.context.save()
                    continuation.resume(returning: session)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchSessions(for activity: Activity) async throws -> [ActivitySession] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = ActivitySession.sessionsForActivityFetchRequest(activity)
                    let sessions = try self.context.fetch(request)
                    continuation.resume(returning: sessions)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteSession(_ session: ActivitySession) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    self.context.delete(session)
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Statistics
    func getTodayTotal(for activity: Activity) async throws -> Double {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                continuation.resume(returning: activity.todaysTotal())
            }
        }
    }

    func getWeeklyTotal(for activity: Activity) async throws -> Double {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                continuation.resume(returning: activity.weeklyTotal())
            }
        }
    }

    func getCurrentStreak(for activity: Activity) async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                continuation.resume(returning: activity.currentStreak())
            }
        }
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


