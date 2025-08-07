import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @State private var editingActivity: Activity?

    @ObservedObject var viewModel: ActivityListViewModel

    init(viewModel: ActivityListViewModel) {
        self.viewModel = viewModel
    }
    
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
        .sheet(item: $editingActivity) { activity in
            EditActivityView(activity: activity)
                .environment(\.managedObjectContext, viewContext)
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("home.title")
                    .font(DesignSystem.Typography.largeTitle)
                    .foregroundColor(.primary)
                    .dynamicTypeSize()
                
                if !viewModel.activities.isEmpty {
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
        if viewModel.activities.isEmpty {
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
                    ForEach(viewModel.activities, id: \.id) { activity in
                        let cardVM: ActivityCardViewModel = {
                            if let id = activity.id, let vm = viewModel.cardViewModels[id] {
                                return vm
                            } else {
                                let vm = ActivityCardViewModel()
                                vm.setActivity(activity, context: viewContext)
                                return vm
                            }
                        }()
                        ActivityCard(activity: activity, viewModel: cardVM)
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

        Button(action: { editingActivity = activity }) {
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
        var activitiesArray = viewModel.activities
        activitiesArray.move(fromOffsets: source, toOffset: destination)
        for (index, activity) in activitiesArray.enumerated() {
            activity.sortOrder = Int32(index)
        }
        do {
            try viewContext.save()
        } catch {
            // Handle the error appropriately, e.g., show an alert
            AppLogger.error("Failed to reorder activities: \(error)")
        }
    }
    
    private func deleteActivities(offsets: IndexSet) {
        for index in offsets {
            let activity = viewModel.activities[index]
            deleteActivity(activity)
        }
    }
    
    private func deleteActivity(_ activity: Activity) {
        activity.isActive = false
        activity.updatedAt = Date()
        do {
            try viewContext.save()
            HapticManager.notification(.success)
        } catch {
            // Handle the error appropriately
            AppLogger.error("Failed to delete activity: \(error)")
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: ActivityListViewModel(context: PersistenceController.preview.container.viewContext))
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(NavigationCoordinator())
            .preferredColorScheme(.dark)
    }
}

