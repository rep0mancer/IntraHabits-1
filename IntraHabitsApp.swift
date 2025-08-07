import SwiftUI
import CoreData
import BackgroundTasks

@main
struct IntraHabitsApp: App {
    @StateObject private var persistenceController = PersistenceController.shared
    @StateObject private var errorHandler = AppDependencies.shared.errorHandler
    @State private var persistenceError: Error?
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            RootView(context: persistenceController.container.viewContext)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .withNavigationCoordinator()
                .onAppear {
                    setupAppearance()
                    persistenceError = persistenceController.loadError
                    registerBackgroundTask()
                }
                .environmentObject(errorHandler)
                .environmentObject(AppDependencies.shared.syncController)
                .alert(isPresented: $errorHandler.showingAlert) {
                    Alert(
                        title: Text("common.error"),
                        message: Text(errorHandler.currentError?.localizedDescription ?? NSLocalizedString("common.unknown_error", comment: "")),
                        dismissButton: .default(Text("common.ok"))
                    )
                }
                .alert("persistence.error.title", isPresented: Binding(get: { persistenceError != nil }, set: { _ in persistenceError = nil })) {
                    Button("common.ok", role: .cancel) {}
                } message: {
                    Text(persistenceError?.localizedDescription ?? NSLocalizedString("common.unknown_error", comment: ""))
                }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                scheduleAppRefresh()
            }
        }
    }
    
    private func setupAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(DesignSystem.Colors.background)
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(DesignSystem.Colors.secondaryBackground)
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Configure other UI elements
        UITableView.appearance().backgroundColor = UIColor(DesignSystem.Colors.background)
        UITableViewCell.appearance().backgroundColor = UIColor.clear
    }

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.intrahabits.app.sync", using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self.handleAppRefresh(task: refreshTask)
        }
    }

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.intrahabits.app.sync")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            AppLogger.error("Could not schedule app refresh: \(error)")
        }
    }

    func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh()

        let operation = BlockOperation {
            Task {
                await AppDependencies.shared.cloudService.sync()
                task.setTaskCompleted(success: true)
            }
        }

        task.expirationHandler = {
            operation.cancel()
        }

        operation.start()
    }
}

// MARK: - Persistence Controller
class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    @Published var loadError: Error?
    
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Add sample data for previews
        let sampleActivity = Activity(context: viewContext)
        sampleActivity.id = UUID()
        sampleActivity.name = "Sample Activity"
        sampleActivity.type = ActivityType.numeric.rawValue
        sampleActivity.color = "#CD3A2E"
        sampleActivity.createdAt = Date()
        sampleActivity.isActive = true
        sampleActivity.sortOrder = 0
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            AppLogger.error("Preview data save failed: \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
    
    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        var persistentContainer = NSPersistentCloudKitContainer(name: "DataModel")

        if inMemory {
            persistentContainer.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure CloudKit
            let storeDescription = persistentContainer.persistentStoreDescriptions.first
            storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }

        var loadError: Error?
        persistentContainer.loadPersistentStores { _, error in
            loadError = error
        }

        if let error = loadError {
            self.loadError = error
            // Fallback: disable CloudKit and retry with a local store
            persistentContainer = NSPersistentCloudKitContainer(name: "DataModel")
            let description = persistentContainer.persistentStoreDescriptions.first
            if inMemory {
                description?.url = URL(fileURLWithPath: "/dev/null")
            } else {
                description?.cloudKitContainerOptions = nil
            }

            persistentContainer.loadPersistentStores { _, fallbackError in
                if let fallbackError = fallbackError {
                    self.loadError = fallbackError
                    // Final fallback to an in-memory store
                    persistentContainer = NSPersistentCloudKitContainer(name: "DataModel")
                    persistentContainer.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
                    persistentContainer.loadPersistentStores { _, _ in }
                }
            }
        }

        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        container = persistentContainer
    }
}

// MARK: - Activity Type Enum
enum ActivityType: String, CaseIterable {
    case numeric = "numeric"
    case timer = "timer"
    
    var displayName: String {
        switch self {
        case .numeric:
            return NSLocalizedString("activity.type.numeric", comment: "Numeric activity type")
        case .timer:
            return NSLocalizedString("activity.type.timer", comment: "Timer activity type")
        }
    }
}

