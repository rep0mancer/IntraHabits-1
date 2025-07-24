import Foundation
import CoreData
import Combine

// MARK: - Repository Protocols
protocol ActivityRepositoryProtocol {
    func fetchAll() -> AnyPublisher<[Activity], Error>
    func fetchActive() -> AnyPublisher<[Activity], Error>
    func fetchById(_ id: UUID) -> AnyPublisher<Activity?, Error>
    func create(_ activity: Activity) -> AnyPublisher<Activity, Error>
    func update(_ activity: Activity) -> AnyPublisher<Activity, Error>
    func delete(_ activity: Activity) -> AnyPublisher<Void, Error>
    func reorder(_ activities: [Activity]) -> AnyPublisher<Void, Error>
}

protocol SessionRepositoryProtocol {
    func fetchAll() -> AnyPublisher<[ActivitySession], Error>
    func fetchForActivity(_ activity: Activity) -> AnyPublisher<[ActivitySession], Error>
    func fetchForDate(_ date: Date) -> AnyPublisher<[ActivitySession], Error>
    func fetchForActivityAndDate(_ activity: Activity, date: Date) -> AnyPublisher<[ActivitySession], Error>
    func create(_ session: ActivitySession) -> AnyPublisher<ActivitySession, Error>
    func update(_ session: ActivitySession) -> AnyPublisher<ActivitySession, Error>
    func delete(_ session: ActivitySession) -> AnyPublisher<Void, Error>
}

// MARK: - Core Data Activity Repository
class CoreDataActivityRepository: ActivityRepositoryProtocol {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func fetchAll() -> AnyPublisher<[Activity], Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            let request = Activity.allActivitiesFetchRequest()
            
            do {
                let activities = try self.context.fetch(request)
                promise(.success(activities))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func fetchActive() -> AnyPublisher<[Activity], Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            let request = Activity.activitiesFetchRequest()
            
            do {
                let activities = try self.context.fetch(request)
                promise(.success(activities))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func fetchById(_ id: UUID) -> AnyPublisher<Activity?, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            let request = Activity.activityByIdFetchRequest(id)
            
            do {
                let activity = try self.context.fetch(request).first
                promise(.success(activity))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func create(_ activity: Activity) -> AnyPublisher<Activity, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            // Validate the activity
            let validationResult = activity.validate()
            guard validationResult.isValid else {
                promise(.failure(RepositoryError.validationFailed(validationResult.errors)))
                return
            }
            
            do {
                try self.context.save()
                promise(.success(activity))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func update(_ activity: Activity) -> AnyPublisher<Activity, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            // Validate the activity
            let validationResult = activity.validate()
            guard validationResult.isValid else {
                promise(.failure(RepositoryError.validationFailed(validationResult.errors)))
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
    
    func delete(_ activity: Activity) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
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
    
    func reorder(_ activities: [Activity]) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
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
}

// MARK: - Core Data Session Repository
class CoreDataSessionRepository: SessionRepositoryProtocol {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func fetchAll() -> AnyPublisher<[ActivitySession], Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            let request = ActivitySession.sessionsFetchRequest()
            
            do {
                let sessions = try self.context.fetch(request)
                promise(.success(sessions))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func fetchForActivity(_ activity: Activity) -> AnyPublisher<[ActivitySession], Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            let request = ActivitySession.sessionsForActivityFetchRequest(activity)
            
            do {
                let sessions = try self.context.fetch(request)
                promise(.success(sessions))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func fetchForDate(_ date: Date) -> AnyPublisher<[ActivitySession], Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            let request = ActivitySession.sessionsForDateFetchRequest(date)
            
            do {
                let sessions = try self.context.fetch(request)
                promise(.success(sessions))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func fetchForActivityAndDate(_ activity: Activity, date: Date) -> AnyPublisher<[ActivitySession], Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            let request = ActivitySession.sessionsForActivityAndDateFetchRequest(activity, date: date)
            
            do {
                let sessions = try self.context.fetch(request)
                promise(.success(sessions))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func create(_ session: ActivitySession) -> AnyPublisher<ActivitySession, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            // Validate the session
            let validationResult = session.validate()
            guard validationResult.isValid else {
                promise(.failure(RepositoryError.validationFailed(validationResult.errors)))
                return
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
    
    func update(_ session: ActivitySession) -> AnyPublisher<ActivitySession, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            // Validate the session
            let validationResult = session.validate()
            guard validationResult.isValid else {
                promise(.failure(RepositoryError.validationFailed(validationResult.errors)))
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
    
    func delete(_ session: ActivitySession) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
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
}

// MARK: - Repository Manager
class RepositoryManager {
    let activityRepository: ActivityRepositoryProtocol
    let sessionRepository: SessionRepositoryProtocol
    
    init(context: NSManagedObjectContext) {
        self.activityRepository = CoreDataActivityRepository(context: context)
        self.sessionRepository = CoreDataSessionRepository(context: context)
    }
}

// MARK: - Repository Errors
enum RepositoryError: LocalizedError {
    case contextNotAvailable
    case entityNotFound
    case validationFailed([String])
    case saveFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .contextNotAvailable:
            return "Database context is not available"
        case .entityNotFound:
            return "The requested entity was not found"
        case .validationFailed(let errors):
            return "Validation failed: \(errors.joined(separator: ", "))"
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        }
    }
}

// MARK: - Mock Repositories for Testing
class MockActivityRepository: ActivityRepositoryProtocol {
    private var activities: [Activity] = []
    
    func fetchAll() -> AnyPublisher<[Activity], Error> {
        Just(activities)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetchActive() -> AnyPublisher<[Activity], Error> {
        Just(activities.filter { $0.isActive })
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetchById(_ id: UUID) -> AnyPublisher<Activity?, Error> {
        Just(activities.first { $0.id == id })
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func create(_ activity: Activity) -> AnyPublisher<Activity, Error> {
        activities.append(activity)
        return Just(activity)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func update(_ activity: Activity) -> AnyPublisher<Activity, Error> {
        if let index = activities.firstIndex(where: { $0.id == activity.id }) {
            activities[index] = activity
        }
        return Just(activity)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func delete(_ activity: Activity) -> AnyPublisher<Void, Error> {
        activity.isActive = false
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func reorder(_ activities: [Activity]) -> AnyPublisher<Void, Error> {
        for (index, activity) in activities.enumerated() {
            activity.sortOrder = Int32(index)
        }
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

class MockSessionRepository: SessionRepositoryProtocol {
    private var sessions: [ActivitySession] = []
    
    func fetchAll() -> AnyPublisher<[ActivitySession], Error> {
        Just(sessions)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetchForActivity(_ activity: Activity) -> AnyPublisher<[ActivitySession], Error> {
        Just(sessions.filter { $0.activity == activity })
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetchForDate(_ date: Date) -> AnyPublisher<[ActivitySession], Error> {
        Just(sessions.filter { session in
            guard let sessionDate = session.sessionDate else { return false }
            return Calendar.current.isDate(sessionDate, inSameDayAs: date)
        })
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
    }
    
    func fetchForActivityAndDate(_ activity: Activity, date: Date) -> AnyPublisher<[ActivitySession], Error> {
        Just(sessions.filter { session in
            guard let sessionDate = session.sessionDate else { return false }
            return session.activity == activity && Calendar.current.isDate(sessionDate, inSameDayAs: date)
        })
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
    }
    
    func create(_ session: ActivitySession) -> AnyPublisher<ActivitySession, Error> {
        sessions.append(session)
        return Just(session)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func update(_ session: ActivitySession) -> AnyPublisher<ActivitySession, Error> {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
        return Just(session)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func delete(_ session: ActivitySession) -> AnyPublisher<Void, Error> {
        sessions.removeAll { $0.id == session.id }
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

