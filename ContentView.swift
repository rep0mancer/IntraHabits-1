import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @StateObject private var viewModel = ActivityListViewModel()
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Activity.sortOrder, ascending: true)],
        predicate: NSPredicate(format: "isActive == %@", NSNumber(value: true)),
        animation: .default
    )
    private var activities: FetchedResults<Activity>
    
    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            ZStack {
                // Background
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Content
                    contentView
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
        }
        .onAppear {
            viewModel.setContext(viewContext)
        }
        .refreshable {
            viewModel.loadActivities()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("home.title")
                    .font(DesignSystem.Typography.largeTitle)
                    .foregroundColor(.primary)
                
                if !activities.isEmpty {
                    Text("home.subtitle")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Calendar Button
                Button(action: { coordinator.presentCalendar() }) {
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .hapticFeedback(.light)
                
                // Settings Button
                Button(action: { coordinator.presentSettings() }) {
                    Image(systemName: "gearshape")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .hapticFeedback(.light)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.top, DesignSystem.Spacing.sm)
    }
    
    // MARK: - Content View
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading {
            LoadingView("home.loading")
        } else if let errorMessage = viewModel.errorMessage {
            ErrorView(
                error: NSError(domain: "IntraHabits", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage]),
                retryAction: { viewModel.loadActivities() }
            )
        } else if activities.isEmpty {
            emptyStateView
        } else {
            activityListView
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        EmptyStateView(
            icon: "plus.circle",
            title: "home.empty.title",
            subtitle: "home.empty.subtitle",
            buttonTitle: "home.empty.button",
            buttonAction: { coordinator.presentAddActivity() }
        )
    }
    
    // MARK: - Activity List View
    private var activityListView: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(activities, id: \.id) { activity in
                        ActivityCard(activity: activity)
                            .environment(\.managedObjectContext, viewContext)
                            .onTapGesture {
                                coordinator.presentActivityDetail(for: activity)
                            }
                            .contextMenu {
                                contextMenuForActivity(activity)
                            }
                    }
                    .onMove(perform: moveActivities)
                    .onDelete(perform: deleteActivities)
                    
                    // Bottom spacing for FAB
                    Spacer()
                        .frame(height: 80)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.top, DesignSystem.Spacing.md)
            }
            
            // Floating Action Button
            FloatingActionButton(
                icon: "plus",
                action: { coordinator.presentAddActivity() }
            )
            .padding(.trailing, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.md)
        }
    }
    
    // MARK: - Context Menu
    @ViewBuilder
    private func contextMenuForActivity(_ activity: Activity) -> some View {
        if activity.isTimerType {
            Button(action: { coordinator.presentTimer(for: activity) }) {
                Label("activity.context.start_timer", systemImage: "play.fill")
            }
        }
        
        Button(action: { coordinator.presentActivityDetail(for: activity) }) {
            Label("activity.context.view_details", systemImage: "info.circle")
        }
        
        Button(action: { /* TODO: Edit activity */ }) {
            Label("activity.context.edit", systemImage: "pencil")
        }
        
        Divider()
        
        Button(role: .destructive, action: { deleteActivity(activity) }) {
            Label("activity.context.delete", systemImage: "trash")
        }
    }
    
    // MARK: - Navigation Destinations
    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .activityDetail(let activity):
            ActivityDetailView(activity: activity)
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(coordinator)
        case .calendar:
            CalendarView()
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(coordinator)
        case .statistics:
            StatisticsView()
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(coordinator)
        case .settings:
            SettingsView()
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(coordinator)
        }
    }
    
    // MARK: - Actions
    private func moveActivities(from source: IndexSet, to destination: Int) {
        var activitiesArray = Array(activities)
        activitiesArray.move(fromOffsets: source, toOffset: destination)
        viewModel.reorderActivities(from: source, to: destination)
    }
    
    private func deleteActivities(offsets: IndexSet) {
        for index in offsets {
            let activity = activities[index]
            deleteActivity(activity)
        }
    }
    
    private func deleteActivity(_ activity: Activity) {
        viewModel.deleteActivity(activity)
    }
}

// MARK: - Enhanced Activity List View Model
class ActivityListViewModel: ObservableObject {
    @Published var activities: [Activity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var viewContext: NSManagedObjectContext?
    private var cancellables = Set<AnyCancellable>()
    
    func setContext(_ context: NSManagedObjectContext) {
        self.viewContext = context
        loadActivities()
        
        // Listen for Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.loadActivities()
                }
            }
            .store(in: &cancellables)
    }
    
    func loadActivities() {
        guard let context = viewContext else { return }
        
        isLoading = true
        errorMessage = nil
        
        let request: NSFetchRequest<Activity> = Activity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Activity.sortOrder, ascending: true)]
        request.predicate = NSPredicate(format: "isActive == %@", NSNumber(value: true))
        
        do {
            activities = try context.fetch(request)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func deleteActivity(_ activity: Activity) {
        guard let context = viewContext else { return }
        
        activity.isActive = false
        activity.updatedAt = Date()
        
        do {
            try context.save()
            
            // Haptic feedback
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
            
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
            activity.updatedAt = Date()
        }
        
        do {
            try context.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(NavigationCoordinator())
            .preferredColorScheme(.dark)
    }
}

