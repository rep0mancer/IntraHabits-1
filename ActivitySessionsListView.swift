import SwiftUI
import CoreData

struct ActivitySessionsListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var activity: Activity
    @FetchRequest var sessions: FetchedResults<ActivitySession>

    init(activity: Activity) {
        self.activity = activity
        _sessions = FetchRequest(fetchRequest: ActivitySession.sessionsForActivityFetchRequest(activity), animation: .default)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                if sessions.isEmpty {
                    EmptyStateView(
                        icon: "clock",
                        title: "activity.detail.no_sessions.title",
                        subtitle: "activity.detail.no_sessions.subtitle"
                    )
                    .frame(height: 150)
                    .padding(DesignSystem.Spacing.md)
                } else {
                    LazyVStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(sessions, id: \.id) { session in
                            SessionRowView(session: session)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                        }
                    }
                    .cardStyle()
                    .padding(DesignSystem.Spacing.md)
                }
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("activity.sessions.title")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.close") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct ActivitySessionsListView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let activity = Activity(context: context)
        activity.id = UUID()
        activity.name = "Exercise"
        activity.type = ActivityType.timer.rawValue
        activity.color = "#CD3A2E"
        activity.createdAt = Date()
        activity.isActive = true

        return ActivitySessionsListView(activity: activity)
            .environment(\.managedObjectContext, context)
    }
}
