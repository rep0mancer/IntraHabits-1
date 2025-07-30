import Foundation
import CoreData
import Combine

// MARK: - Activity List View Model
/// View model responsible for fetching, ordering and soft deleting activities. Each activity is also paired with its own `ActivityCardViewModel`.
class ActivityListViewModel: ObservableObject {
    @Published var activities: [Activity] = []
    @Published var cardViewModels: [UUID: ActivityCardViewModel] = [:]
    @Published var errorMessage: String?

    private var viewContext: NSManagedObjectContext?

    /// Assigns the managed object context and loads the activities from storage.
    func setContext(_ context: NSManagedObjectContext) {
        self.viewContext = context
        fetchActivities()
    }

    /// Fetches all active activities from Core Data, sorts them by their `sortOrder` and instantiates a corresponding card view model for each.
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

    /// Soft deletes an activity by marking it inactive and updating its `updatedAt` timestamp.
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

    /// Persists a new ordering for activities after a drag and drop reorder operation.
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

// MARK: - Activity Card View Model
/// A lightweight view model used by `ActivityListViewModel` to update the display for an individual activity card.
class ActivityCardViewModel: ObservableObject {
    @Published var todayCount: Int = 0
    @Published var formattedDuration: String = "0min"

    private var activity: Activity?
    private var viewContext: NSManagedObjectContext?
    private var cancellables = Set<AnyCancellable>()

    /// Assigns the activity and context and triggers an initial update of the card values.
    func setActivity(_ activity: Activity, context: NSManagedObjectContext) {
        self.activity = activity
        self.viewContext = context
        updateDisplayValues()
    }

    /// Creates a new numeric session for the activity, updates its streaks, saves it and refreshes the UI.
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

    /// Refreshes the UI by counting today's sessions and calculating today's duration or numeric total.
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

    /// Updates the `currentStreak` and `longestStreak` properties on an activity by delegating to the central `calculateStreaks` function.
    private func updateStreaks(for activity: Activity) {
        let streaks = Activity.calculateStreaks(for: activity)
        activity.currentStreak = Int32(streaks.current)
        activity.longestStreak = Int32(streaks.longest)
    }

    /// Formats a duration in seconds into a human readable string for the card.
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