import Foundation
import CoreData
import CloudKit
import Combine

// MARK: - Data Service Protocol
protocol DataServiceProtocol {
    func fetchActivities() -> AnyPublisher<[Activity], Error>
    func createActivity(name: String, type: ActivityType, color: String) -> AnyPublisher<Activity, Error>
    func updateActivity(_ activity: Activity) -> AnyPublisher<Activity, Error>
    func deleteActivity(_ activity: Activity) -> AnyPublisher<Void, Error>
    func reorderActivities(_ activities: [Activity]) -> AnyPublisher<Void, Error>
    
    func fetchSessions(for activity: Activity, date: Date?) -> AnyPublisher<[ActivitySession], Error>
    func createSession(for activity: Activity, duration: TimeInterval?, numericValue: Double?) -> AnyPublisher<ActivitySession, Error>
    func updateSession(_ session: ActivitySession) -> AnyPublisher<ActivitySession, Error>
    func deleteSession(_ session: ActivitySession) -> AnyPublisher<Void, Error>
    
    func exportData() -> AnyPublisher<Data, Error>
    func resetAllData() -> AnyPublisher<Void, Error>
}

// MARK: - Core Data Service Implementation
class CoreDataService: DataServiceProtocol {
    private let persistentContainer: NSPersistentCloudKitContainer
    private let context: NSManagedObjectContext
    
    init(container: NSPersistentCloudKitContainer) {
        self.persistentContainer = container
        self.context = container.viewContext
    }
    
    // MARK: - Activity Operations
    func fetchActivities() -> AnyPublisher<[Activity], Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(DataServiceError.contextNotAvailable))
                return
            }
            
            let request: NSFetchRequest<Activity> = Activity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Activity.sortOrder, ascending: true)]
            request.predicate = NSPredicate(format: "isActive == %@", NSNumber(value: true))
            
            do {
                let activities = try self.context.fetch(request)
                promise(.success(activities))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func createActivity(name: String, type: ActivityType, color: String) -> AnyPublisher<Activity, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(DataServiceError.contextNotAvailable))
                return
            }
            
            // Check activity limit
            let countRequest: NSFetchRequest<Activity> = Activity.fetchRequest()
            countRequest.predicate = NSPredicate(format: "isActive == %@", NSNumber(value: true))
            
            do {
                let existingCount = try self.context.count(for: countRequest)
                
                // TODO: Check premium subscription status
                let hasUnlimitedActivities = false
                if existingCount >= 5 && !hasUnlimitedActivities {
                    promise(.failure(DataServiceError.activityLimitReached))
                    return
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
                promise(.success(activity))
                
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func updateActivity(_ activity: Activity) -> AnyPublisher<Activity, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(DataServiceError.contextNotAvailable))
                return
            }
            
            activity.updatedAt = Date()
            
            do {
                try self.context.save()
                promise(.success(activity))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func deleteActivity(_ activity: Activity) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(DataServiceError.contextNotAvailable))
                return
            }
            
            // Soft delete
            activity.isActive = false
            activity.updatedAt = Date()
            
            do {
                try self.context.save()
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func reorderActivities(_ activities: [Activity]) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(DataServiceError.contextNotAvailable))
                return
            }
            
            for (index, activity) in activities.enumerated() {
                activity.sortOrder = Int32(index)
                activity.updatedAt = Date()
            }
            
            do {
                try self.context.save()
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Session Operations
    func fetchSessions(for activity: Activity, date: Date? = nil) -> AnyPublisher<[ActivitySession], Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(DataServiceError.contextNotAvailable))
                return
            }
            
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
            
            do {
                let sessions = try self.context.fetch(request)
                promise(.success(sessions))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func createSession(for activity: Activity, duration: TimeInterval? = nil, numericValue: Double? = nil) -> AnyPublisher<ActivitySession, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(DataServiceError.contextNotAvailable))
                return
            }
            
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
            
            do {
                try self.context.save()
                promise(.success(session))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func updateSession(_ session: ActivitySession) -> AnyPublisher<ActivitySession, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(DataServiceError.contextNotAvailable))
                return
            }
            
            session.updatedAt = Date()
            
            do {
                try self.context.save()
                promise(.success(session))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func deleteSession(_ session: ActivitySession) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(DataServiceError.contextNotAvailable))
                return
            }
            
            self.context.delete(session)
            
            do {
                try self.context.save()
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Data Management
    func exportData() -> AnyPublisher<Data, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(DataServiceError.contextNotAvailable))
                return
            }
            
            let activityRequest: NSFetchRequest<Activity> = Activity.fetchRequest()
            let sessionRequest: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
            
            do {
                let activities = try self.context.fetch(activityRequest)
                let sessions = try self.context.fetch(sessionRequest)
                
                let exportData = ExportData(
                    activities: activities.map { ActivityExport(from: $0) },
                    sessions: sessions.map { SessionExport(from: $0) },
                    exportDate: Date()
                )
                
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let jsonData = try encoder.encode(exportData)
                
                promise(.success(jsonData))
                
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func resetAllData() -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(DataServiceError.contextNotAvailable))
                return
            }
            
            let activityRequest: NSFetchRequest<NSFetchRequestResult> = Activity.fetchRequest()
            let sessionRequest: NSFetchRequest<NSFetchRequestResult> = ActivitySession.fetchRequest()
            
            let activityDeleteRequest = NSBatchDeleteRequest(fetchRequest: activityRequest)
            let sessionDeleteRequest = NSBatchDeleteRequest(fetchRequest: sessionRequest)
            
            do {
                try self.context.execute(sessionDeleteRequest)
                try self.context.execute(activityDeleteRequest)
                try self.context.save()
                
                promise(.success(()))
                
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Data Service Errors
enum DataServiceError: LocalizedError {
    case contextNotAvailable
    case activityLimitReached
    case invalidData
    case syncFailed
    
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
        }
    }
}

// MARK: - CloudKit Service
class CloudKitService {
    private let container: CKContainer
    private let database: CKDatabase
    
    init() {
        self.container = CKContainer.default()
        self.database = container.privateCloudDatabase
    }
    
    func checkAccountStatus() -> AnyPublisher<CKAccountStatus, Error> {
        Future { [weak self] promise in
            self?.container.accountStatus { status, error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(status))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func requestPermissions() -> AnyPublisher<CKContainer.ApplicationPermissionStatus, Error> {
        Future { [weak self] promise in
            self?.container.requestApplicationPermission(.userDiscoverability) { status, error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(status))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

