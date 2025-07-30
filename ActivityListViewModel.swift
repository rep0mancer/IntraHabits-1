import Foundation
import CoreData
import Combine

class ActivityListViewModel: ObservableObject {
    @Published var activities: [Activity] = []
    @Published var cardViewModels: [UUID: ActivityCardViewModel] = [:]
    @Published var errorMessage: String?

    private var viewContext: NSManagedObjectContext?
    
    func setContext(_ context: NSManagedObjectContext) {
        self.viewContext = context
        fetchActivities()
    }

    func fetchActivities() {
        guard let context = viewContext else { return }
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
        guard let context = viewContext else { return }
        
        activity.isActive = false
        activity.updatedAt = Date()
        
        do {
            try context.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func reorderActivities(from source: IndexSet, to destination: Int, items: [Activity]) {
        guard let context = viewContext else { return }

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
        guard let sessions = activity.sessions?.allObjects as? [ActivitySession] else {
            activity.currentStreak = 0
            activity.longestStreak = 0
            return
        }

        let calendar = Calendar.current
        let sessionDates = sessions.compactMap { $0.sessionDate }.map { calendar.startOfDay(for: $0) }

        // Current streak
        let sortedDesc = Array(Set(sessionDates)).sorted(by: >)
        var current = 0
        var datePointer = calendar.startOfDay(for: Date())
        for date in sortedDesc {
            if calendar.isDate(date, inSameDayAs: datePointer) {
                current += 1
                if let new = calendar.date(byAdding: .day, value: -1, to: datePointer) {
                    datePointer = new
                }
            } else if date < datePointer {
                break
            }
        }

        // Longest streak
        let sortedAsc = Array(Set(sessionDates)).sorted()
        var maxStreak = 0
        var streak = 0
        for i in 0..<sortedAsc.count {
            if i == 0 { streak = 1; maxStreak = 1; continue }
            let prev = sortedAsc[i - 1]
            if calendar.dateInterval(of: .day, for: prev)?.end == sortedAsc[i] {
                streak += 1
                maxStreak = max(maxStreak, streak)
            } else {
                streak = 1
            }
        }

        activity.currentStreak = Int32(current)
        activity.longestStreak = Int32(maxStreak)
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

