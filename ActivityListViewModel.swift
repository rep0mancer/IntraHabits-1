import Foundation
import CoreData
import Combine

class ActivityListViewModel: ObservableObject {
    @Published var activities: [Activity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var viewContext: NSManagedObjectContext?
    private var cancellables = Set<AnyCancellable>()
    
    func setContext(_ context: NSManagedObjectContext) {
        self.viewContext = context
        loadActivities()
    }
    
    func loadActivities() {
        guard let context = viewContext else { return }
        
        let request: NSFetchRequest<Activity> = Activity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Activity.sortOrder, ascending: true)]
        request.predicate = NSPredicate(format: "isActive == %@", NSNumber(value: true))
        
        do {
            activities = try context.fetch(request)
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
            loadActivities()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func reorderActivities(from source: IndexSet, to destination: Int) {
        guard let context = viewContext else { return }
        
        var reorderedActivities = activities
        reorderedActivities.move(fromOffsets: source, toOffset: destination)
        
        for (index, activity) in reorderedActivities.enumerated() {
            activity.sortOrder = Int32(index)
        }
        
        do {
            try context.save()
            loadActivities()
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
            try context.save()
            updateDisplayValues()
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        } catch {
            AppLogger.error("Error saving session: \(error)")
        }
    }
    
    private func updateDisplayValues() {
        guard let activity = activity else { return }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
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

