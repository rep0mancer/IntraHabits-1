import Foundation
import CoreData
import WidgetKit

// MARK: - Widget Data Service
class WidgetDataService: ObservableObject {
    static let shared = WidgetDataService()
    
    private let containerName = "DataModel"
    private let appGroupIdentifier = "group.com.intrahabits.shared"
    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: containerName)
        
        // Configure for app group sharing
        if let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?.appendingPathComponent("DataModel.sqlite") {
            let storeDescription = NSPersistentStoreDescription(url: storeURL)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            container.persistentStoreDescriptions = [storeDescription]
        }
        
        container.loadPersistentStores { _, error in
            if let error = error {
                AppLogger.error("Widget Core Data error: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    private var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    private init() {}
    
    // MARK: - Activity Management
    func getAllActivities() async throws -> [ActivityEntity] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request: NSFetchRequest<Activity> = Activity.fetchRequest()
                    request.predicate = NSPredicate(format: "%K == true", #keyPath(Activity.isActive))
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \Activity.createdAt, ascending: true)]
                    
                    let activities = try self.context.fetch(request)
                    let entities = activities.map { activity in
                        ActivityEntity(
                            id: activity.id?.uuidString ?? "",
                            name: activity.name ?? "",
                            type: activity.type ?? "",
                            color: activity.color ?? ""
                        )
                    }
                    continuation.resume(returning: entities)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func getActivities(withIds ids: [String]) async throws -> [ActivityEntity] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let uuids = ids.compactMap { UUID(uuidString: $0) }
                    let request: NSFetchRequest<Activity> = Activity.fetchRequest()
                    request.predicate = NSPredicate(format: "id IN %@ AND %K == true", uuids, #keyPath(Activity.isActive))
                    
                    let activities = try self.context.fetch(request)
                    let entities = activities.map { activity in
                        ActivityEntity(
                            id: activity.id?.uuidString ?? "",
                            name: activity.name ?? "",
                            type: activity.type ?? "",
                            color: activity.color ?? ""
                        )
                    }
                    continuation.resume(returning: entities)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func getActivity(withId id: String) async throws -> ActivityEntity? {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    guard let uuid = UUID(uuidString: id) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let request: NSFetchRequest<Activity> = Activity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@ AND %K == true", uuid as CVarArg, #keyPath(Activity.isActive))
                    request.fetchLimit = 1
                    
                    let activities = try self.context.fetch(request)
                    if let activity = activities.first {
                        let entity = ActivityEntity(
                            id: activity.id?.uuidString ?? "",
                            name: activity.name ?? "",
                            type: activity.type ?? "",
                            color: activity.color ?? ""
                        )
                        continuation.resume(returning: entity)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Session Management
    func createSession(activityId: String, numericValue: Double?, duration: TimeInterval?) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    guard let uuid = UUID(uuidString: activityId) else {
                        continuation.resume(throwing: WidgetError.activityNotFound)
                        return
                    }
                    
                    // Find the activity
                    let activityRequest: NSFetchRequest<Activity> = Activity.fetchRequest()
                    activityRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
                    activityRequest.fetchLimit = 1
                    
                    guard let activity = try self.context.fetch(activityRequest).first else {
                        continuation.resume(throwing: WidgetError.activityNotFound)
                        return
                    }
                    
                    // Create new session
                    let session = ActivitySession(context: self.context)
                    session.id = UUID()
                    session.activity = activity
                    session.sessionDate = Date()
                    session.numericValue = numericValue ?? 0
                    session.duration = duration ?? 0
                    session.isCompleted = true
                    session.createdAt = Date()
                    
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func getTodaysSessions(for activityId: String) async throws -> [WidgetSession] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    guard let uuid = UUID(uuidString: activityId) else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: Date())
                    guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    let request: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
                    request.predicate = NSPredicate(format: "activity.id == %@ AND sessionDate >= %@ AND sessionDate < %@", 
                                                  uuid as CVarArg, startOfDay as NSDate, endOfDay as NSDate)
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \ActivitySession.sessionDate, ascending: false)]
                    
                    let sessions = try self.context.fetch(request)
                    let widgetSessions = sessions.map { session in
                        WidgetSession(
                            id: session.id?.uuidString ?? "",
                            activityId: session.activity?.id?.uuidString ?? "",
                            date: session.sessionDate ?? Date(),
                            numericValue: session.numericValue > 0 ? session.numericValue : nil,
                            duration: session.duration > 0 ? session.duration : nil,
                            isCompleted: session.isCompleted
                        )
                    }
                    continuation.resume(returning: widgetSessions)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Progress Data
    func getTodaysProgress() async throws -> [WidgetActivityProgress] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: Date())
                    guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    // Get all active activities
                    let activityRequest: NSFetchRequest<Activity> = Activity.fetchRequest()
                    activityRequest.predicate = NSPredicate(format: "%K == true", #keyPath(Activity.isActive))
                    activityRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Activity.createdAt, ascending: true)]
                    
                    let activities = try self.context.fetch(activityRequest)
                    var progressList: [WidgetActivityProgress] = []
                    
                    for activity in activities {
                        // Get today's sessions for this activity
                        let sessionRequest: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
                        sessionRequest.predicate = NSPredicate(format: "activity == %@ AND sessionDate >= %@ AND sessionDate < %@",
                                                             activity, startOfDay as NSDate, endOfDay as NSDate)
                        
                        let sessions = try self.context.fetch(sessionRequest)
                        
                        let todaysSessions = sessions.count
                        let todaysDuration = sessions.reduce(0) { $0 + $1.duration }
                        let todaysNumericTotal = sessions.reduce(0) { $0 + $1.numericValue }
                        
                        // Calculate progress percentage (simplified)
                        let targetValue: Double = activity.type == "timer" ? 1800 : 5 // 30 minutes or 5 units
                        let currentValue = activity.type == "timer" ? todaysDuration : todaysNumericTotal
                        let progressPercentage = min(currentValue / targetValue, 1.0)
                        
                        let progress = WidgetActivityProgress(
                            id: activity.id?.uuidString ?? "",
                            name: activity.name ?? "",
                            color: activity.color ?? "",
                            type: activity.type ?? "",
                            todaysSessions: todaysSessions,
                            todaysDuration: todaysDuration,
                            todaysNumericTotal: todaysNumericTotal,
                            targetValue: targetValue,
                            progressPercentage: progressPercentage
                        )
                        
                        progressList.append(progress)
                    }
                    
                    continuation.resume(returning: progressList)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Statistics Data
    func getActivityStats() async throws -> [WidgetActivityStats] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let activityRequest: NSFetchRequest<Activity> = Activity.fetchRequest()
                    activityRequest.predicate = NSPredicate(format: "%K == true", #keyPath(Activity.isActive))
                    activityRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Activity.createdAt, ascending: true)]
                    
                    let activities = try self.context.fetch(activityRequest)
                    var statsList: [WidgetActivityStats] = []
                    
                    for activity in activities {
                        let sessionRequest: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
                        sessionRequest.predicate = NSPredicate(format: "activity == %@", activity)
                        
                        let sessions = try self.context.fetch(sessionRequest)
                        
                        let totalSessions = sessions.count
                        let totalDuration = sessions.reduce(0) { $0 + $1.duration }
                        let totalNumericValue = sessions.reduce(0) { $0 + $1.numericValue }
                        
                        // Calculate streaks (simplified)
                        let currentStreak = self.calculateCurrentStreak(for: sessions)
                        let bestStreak = self.calculateBestStreak(for: sessions)
                        
                        // Calculate average per day
                        let daysSinceCreation = Calendar.current.dateComponents([.day], from: activity.createdAt ?? Date(), to: Date()).day ?? 1
                        let averagePerDay = Double(totalSessions) / Double(max(daysSinceCreation, 1))
                        
                        let stats = WidgetActivityStats(
                            id: activity.id?.uuidString ?? "",
                            name: activity.name ?? "",
                            color: activity.color ?? "",
                            type: activity.type ?? "",
                            totalSessions: totalSessions,
                            totalDuration: totalDuration,
                            totalNumericValue: totalNumericValue,
                            currentStreak: currentStreak,
                            bestStreak: bestStreak,
                            averagePerDay: averagePerDay
                        )
                        
                        statsList.append(stats)
                    }
                    
                    // Sort by total sessions descending
                    statsList.sort { $0.totalSessions > $1.totalSessions }
                    
                    continuation.resume(returning: statsList)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func calculateCurrentStreak(for sessions: [ActivitySession]) -> Int {
        let calendar = Calendar.current
        let sortedSessions = sessions.sorted { ($0.sessionDate ?? Date()) > ($1.sessionDate ?? Date()) }
        
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        for session in sortedSessions {
            let sessionDate = calendar.startOfDay(for: session.sessionDate ?? Date())
            
            if calendar.isDate(sessionDate, inSameDayAs: currentDate) {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else if sessionDate < currentDate {
                break
            }
        }
        
        return streak
    }
    
    private func calculateBestStreak(for sessions: [ActivitySession]) -> Int {
        let calendar = Calendar.current
        let sortedSessions = sessions.sorted { ($0.sessionDate ?? Date()) < ($1.sessionDate ?? Date()) }
        
        var bestStreak = 0
        var currentStreak = 0
        var lastDate: Date?
        
        for session in sortedSessions {
            let sessionDate = calendar.startOfDay(for: session.sessionDate ?? Date())
            
            if let last = lastDate {
                let daysBetween = calendar.dateComponents([.day], from: last, to: sessionDate).day ?? 0
                
                if daysBetween == 1 {
                    currentStreak += 1
                } else if daysBetween > 1 {
                    bestStreak = max(bestStreak, currentStreak)
                    currentStreak = 1
                }
            } else {
                currentStreak = 1
            }
            
            lastDate = sessionDate
        }
        
        return max(bestStreak, currentStreak)
    }
}

