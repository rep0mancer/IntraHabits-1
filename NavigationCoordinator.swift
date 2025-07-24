import SwiftUI
import Combine

// MARK: - Navigation Coordinator
class NavigationCoordinator: ObservableObject {
    @Published var currentTab: AppTab = .activities
    @Published var showingAddActivity = false
    @Published var showingSettings = false
    @Published var showingPaywall = false
    @Published var selectedActivity: Activity?
    @Published var showingActivityDetail = false
    @Published var showingTimer = false
    @Published var showingCalendar = false
    
    // Navigation stack for deep linking
    @Published var navigationPath = NavigationPath()
    
    // MARK: - Tab Navigation
    func selectTab(_ tab: AppTab) {
        currentTab = tab
    }
    
    // MARK: - Modal Presentations
    func presentAddActivity() {
        showingAddActivity = true
    }
    
    func presentSettings() {
        showingSettings = true
    }
    
    func presentPaywall() {
        showingPaywall = true
    }
    
    func presentTimer(for activity: Activity) {
        selectedActivity = activity
        showingTimer = true
    }
    
    func presentActivityDetail(for activity: Activity) {
        selectedActivity = activity
        showingActivityDetail = true
    }
    
    func presentCalendar() {
        showingCalendar = true
    }
    
    // MARK: - Dismiss Methods
    func dismissAll() {
        showingAddActivity = false
        showingSettings = false
        showingPaywall = false
        showingActivityDetail = false
        showingTimer = false
        showingCalendar = false
        selectedActivity = nil
    }
    
    func dismissAddActivity() {
        showingAddActivity = false
    }
    
    func dismissSettings() {
        showingSettings = false
    }
    
    func dismissPaywall() {
        showingPaywall = false
    }
    
    func dismissTimer() {
        showingTimer = false
        selectedActivity = nil
    }
    
    func dismissActivityDetail() {
        showingActivityDetail = false
        selectedActivity = nil
    }
    
    func dismissCalendar() {
        showingCalendar = false
    }
    
    // MARK: - Deep Linking
    func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host else { return }
        
        switch host {
        case "activity":
            if let activityIdString = components.queryItems?.first(where: { $0.name == "id" })?.value,
               let activityId = UUID(uuidString: activityIdString) {
                // Navigate to specific activity
                // This would require fetching the activity from Core Data
                AppLogger.info("Deep link to activity: \(activityId)")
            }
        case "timer":
            if let activityIdString = components.queryItems?.first(where: { $0.name == "id" })?.value,
               let activityId = UUID(uuidString: activityIdString) {
                // Navigate to timer for specific activity
                AppLogger.info("Deep link to timer for activity: \(activityId)")
            }
        case "add":
            presentAddActivity()
        case "settings":
            presentSettings()
        default:
            break
        }
    }
}

// MARK: - App Tabs
enum AppTab: String, CaseIterable {
    case activities = "activities"
    case calendar = "calendar"
    case statistics = "statistics"
    
    var title: LocalizedStringKey {
        switch self {
        case .activities:
            return "tab.activities"
        case .calendar:
            return "tab.calendar"
        case .statistics:
            return "tab.statistics"
        }
    }
    
    var icon: String {
        switch self {
        case .activities:
            return "list.bullet"
        case .calendar:
            return "calendar"
        case .statistics:
            return "chart.bar"
        }
    }
    
    var selectedIcon: String {
        switch self {
        case .activities:
            return "list.bullet"
        case .calendar:
            return "calendar"
        case .statistics:
            return "chart.bar.fill"
        }
    }
}

// MARK: - Navigation Destination
enum NavigationDestination: Hashable {
    case activityDetail(Activity)
    case calendar
    case statistics
    case settings
    
    static func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
        switch (lhs, rhs) {
        case (.activityDetail(let lhsActivity), .activityDetail(let rhsActivity)):
            return lhsActivity.id == rhsActivity.id
        case (.calendar, .calendar),
             (.statistics, .statistics),
             (.settings, .settings):
            return true
        default:
            return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .activityDetail(let activity):
            hasher.combine("activityDetail")
            hasher.combine(activity.id)
        case .calendar:
            hasher.combine("calendar")
        case .statistics:
            hasher.combine("statistics")
        case .settings:
            hasher.combine("settings")
        }
    }
}

// MARK: - Navigation View Modifier
struct NavigationCoordinatorModifier: ViewModifier {
    @StateObject private var coordinator = NavigationCoordinator()
    @Environment(\.managedObjectContext) private var viewContext
    
    func body(content: Content) -> some View {
        content
            .environmentObject(coordinator)
            .sheet(isPresented: $coordinator.showingAddActivity) {
                AddActivityView()
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(coordinator)
            }
            .sheet(isPresented: $coordinator.showingSettings) {
                SettingsView()
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(coordinator)
            }
            .sheet(isPresented: $coordinator.showingPaywall) {
                PaywallView()
                    .environmentObject(coordinator)
            }
            .sheet(isPresented: $coordinator.showingTimer) {
                if let activity = coordinator.selectedActivity {
                    TimerView(activity: activity)
                        .environment(\.managedObjectContext, viewContext)
                        .environmentObject(coordinator)
                }
            }
            .sheet(isPresented: $coordinator.showingActivityDetail) {
                if let activity = coordinator.selectedActivity {
                    ActivityDetailView(activity: activity)
                        .environment(\.managedObjectContext, viewContext)
                        .environmentObject(coordinator)
                }
            }
            .onOpenURL { url in
                coordinator.handleDeepLink(url)
            }
    }
}

// MARK: - View Extension
extension View {
    func withNavigationCoordinator() -> some View {
        modifier(NavigationCoordinatorModifier())
    }
}

