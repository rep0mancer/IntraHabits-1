import Foundation
import CoreData
import Combine

@MainActor
final class ActivityListViewModel: ObservableObject {
    @Published var activities: [Activity] = []
    @Published var cardViewModels: [UUID: ActivityCardViewModel] = [:]
    @Published var errorMessage: String?

    private let viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        fetchActivities()
    }

    func fetchActivities() {
        let context = viewContext
        let request: NSFetchRequest<Activity> = Activity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Activity.sortOrder, ascending: true)]
        request.predicate = NSPredicate(format: "%K == %@", #keyPath(Activity.isActive), NSNumber(value: true))
        do {
            activities = try context.fetch(request)
            cardViewModels.removeAll()
            for activity in activities {
                if let id = activity.id {
                    let vm = ActivityCardViewModel()
                    vm.setActivity(activity, context: context)
                    cardViewModels[id] = vm
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func deleteActivity(_ activity: Activity) {
        let context = viewContext
        
        activity.isActive = false
        activity.updatedAt = Date()
        
        do {
            try context.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func reorderActivities(from source: IndexSet, to destination: Int, items: [Activity]) {
        let context = viewContext

        var reorderedActivities = items
        reorderedActivities.move(fromOffsets: source, toOffset: destination)

        for (index, activity) in reorderedActivities.enumerated() {
            activity.sortOrder = Int32(index)
        }

        do {
            try context.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
class ActivityCardViewModel: ObservableObject {
    @Published var todayCount: Int = 0
    @Published var formattedDuration: String = "0min"
    
    private var activity: Activity?
    private var viewContext: NSManagedObjectContext?
    private var cancellables = Set<AnyCancellable>()
    
    func setActivity(_ activity: Activity, context: NSManagedObjectContext) {
        self.activity = activity
        self.viewContext = context
        updateDisplayValues()
    }
    
    // New convenience properties used in various views
    var todaysFormattedValue: String {
        guard let activity else { return "0" }
        return activity.isTimerType ? formattedDuration : "\(todayCount)"
    }
    
    var currentStreak: Int {
        guard let activity else { return 0 }
        return activity.currentStreak()
    }

    // Overload to support +N steps from action sheet with a single save
    func incrementActivity(by step: Int) {
        guard step > 0,
              let activity = activity,
              let context = viewContext,
              activity.type == ActivityType.numeric.rawValue else { return }

        let now = Date()
        for _ in 0..<step {
            let session = ActivitySession(context: context)
            session.id = UUID()
            session.activity = activity
            session.sessionDate = now
            session.numericValue = 1.0
            session.createdAt = now
            session.isCompleted = true
        }

        do {
            updateStreaks(for: activity)
            try context.save()
            updateDisplayValues()
        } catch {
            AppLogger.error("Error saving sessions: \(error)")
        }
    }
    
    func incrementActivity() {
        guard let activity = activity,
              let context = viewContext,
              activity.type == ActivityType.numeric.rawValue else { return }
        
        let session = ActivitySession(context: context)
        session.id = UUID()
        session.activity = activity
        session.sessionDate = Date()
        session.numericValue = 1.0
        session.createdAt = Date()
        session.isCompleted = true
        
        do {
            updateStreaks(for: activity)
            try context.save()
            updateDisplayValues()
        } catch {
            AppLogger.error("Error saving session: \(error)")
        }
    }
    
    private func updateDisplayValues() {
        guard let activity = activity else { return }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return }
        
        let predicate = NSPredicate(format: "activity == %@ AND sessionDate >= %@ AND sessionDate < %@", 
                                  activity, today as NSDate, tomorrow as NSDate)
        
        let request: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
        request.predicate = predicate
        
        do {
            let sessions = try viewContext?.fetch(request) ?? []
            
            if activity.type == ActivityType.numeric.rawValue {
                todayCount = sessions.reduce(0) { $0 + Int($1.numericValue) }
            } else {
                let totalDuration = sessions.reduce(0) { $0 + $1.duration }
                formattedDuration = formatDuration(totalDuration)
            }
        } catch {
            AppLogger.error("Error fetching sessions: \(error)")
        }
    }

    private func updateStreaks(for activity: Activity) {
        let streaks = Activity.calculateStreaks(for: activity)
        activity.currentStreak = Int32(streaks.current)
        activity.longestStreak = Int32(streaks.longest)
    }
    
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
}

