import SwiftUI
import CoreData

struct ActivityCard: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var activity: Activity
    @StateObject var viewModel: ActivityCardViewModel
    @State private var showingTimer = false
    @State private var showingStepSelector = false
    @State private var selectedStepSize = 1

    private let stepSizes = [1, 2, 5, 10, 25, 50]

    init(activity: Activity, viewModel: ActivityCardViewModel = ActivityCardViewModel()) {
        self.activity = activity
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Activity Info Section
            activityInfoSection
            
            Spacer()
            
            // Statistics Section
            statisticsSection
            
            // Action Button
            actionButton
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle(backgroundColor: DesignSystem.Colors.secondaryBackground)
        .sheet(isPresented: $showingTimer) {
            TimerView(activity: activity)
                .environment(\.managedObjectContext, viewContext)
        }
        .actionSheet(isPresented: $showingStepSelector) {
            stepSelectorActionSheet
        }
    }
    
    // MARK: - Activity Info Section
    private var activityInfoSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                // Activity Color Indicator
                Circle()
                    .fill(activity.displayColor)
                    .frame(width: 12, height: 12)
                
                Text(activity.displayName)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            
            // Activity Type Badge
            HStack {
                Image(systemName: activity.isTimerType ? "timer" : "number")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(activity.activityType.displayName)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Statistics Section
    private var statisticsSection: some View {
        VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
            // Today's Value
            Text(viewModel.todaysFormattedValue)
                .font(DesignSystem.Typography.numberMedium)
                .foregroundColor(activity.displayColor)
            
            // Streak Info
            if viewModel.currentStreak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    
                    Text("\(viewModel.currentStreak)")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Action Button
    private var actionButton: some View {
        Group {
            if activity.isTimerType {
                timerActionButton
            } else {
                numericActionButton
            }
        }
    }
    
    private var timerActionButton: some View {
        Button(action: { showingTimer = true }) {
            Image(systemName: "play.fill")
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(activity.displayColor)
                .cornerRadius(DesignSystem.CornerRadius.medium)
        }
        .hapticFeedback(.medium)
    }
    
    private var numericActionButton: some View {
        Button(action: {
            let step = selectedStepSize
            let style: UIImpactFeedbackGenerator.FeedbackStyle = step > 1 ? .heavy : .medium
            HapticManager.impact(style)
            viewModel.incrementActivity(by: step)
        }) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.title3)
                
                if selectedStepSize > 1 {
                    Text("\(selectedStepSize)")
                        .font(DesignSystem.Typography.caption1)
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .background(activity.displayColor)
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
        .onLongPressGesture {
            showingStepSelector = true
        }
    }
    
    // MARK: - Step Selector Action Sheet
    private var stepSelectorActionSheet: ActionSheet {
        ActionSheet(
            title: Text("activity.step.selector.title"),
            message: Text("activity.step.selector.message"),
            buttons: stepSizes.map { stepSize in
                .default(Text("+\(stepSize)")) {
                    selectedStepSize = stepSize
                    let style: UIImpactFeedbackGenerator.FeedbackStyle = stepSize > 1 ? .heavy : .medium
                    HapticManager.impact(style)
                    viewModel.incrementActivity(by: stepSize)
                }
            } + [.cancel()]
        )
    }
}

// MARK: - Enhanced Activity Card View Model
class ActivityCardViewModel: ObservableObject {
    @Published var todaysFormattedValue: String = "0"
    @Published var currentStreak: Int = 0
    @Published var weeklyTotal: Double = 0
    @Published var monthlyTotal: Double = 0
    
    private var activity: Activity?
    private var viewContext: NSManagedObjectContext?
    private var cancellables = Set<AnyCancellable>()
    
    func setActivity(_ activity: Activity, context: NSManagedObjectContext) {
        self.activity = activity
        self.viewContext = context
        updateDisplayValues()
        
        // Listen for changes to update the display
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateDisplayValues()
                }
            }
            .store(in: &cancellables)
    }
    
    func incrementActivity(by value: Int = 1) {
        guard let activity = activity,
              let context = viewContext,
              activity.isNumericType else { return }
        
        let session = ActivitySession(context: context)
        session.id = UUID()
        session.activity = activity
        session.sessionDate = Date()
        session.numericValue = Double(value)
        session.createdAt = Date()
        session.isCompleted = true
        
        do {
            try context.save()
            updateDisplayValues()
            
        } catch {
            AppLogger.error("Error saving session: \(error)")
        }
    }
    
    private func updateDisplayValues() {
        guard let activity = activity else { return }
        
        todaysFormattedValue = activity.todaysFormattedTotal()
        currentStreak = activity.currentStreak()
        weeklyTotal = activity.weeklyTotal()
        monthlyTotal = activity.monthlyTotal()
    }
}

// MARK: - Preview
struct ActivityCard_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        let timerActivity = Activity(context: context)
        timerActivity.id = UUID()
        timerActivity.name = "Exercise"
        timerActivity.type = ActivityType.timer.rawValue
        timerActivity.color = "#CD3A2E"
        timerActivity.createdAt = Date()
        timerActivity.isActive = true
        timerActivity.sortOrder = 0
        
        let numericActivity = Activity(context: context)
        numericActivity.id = UUID()
        numericActivity.name = "Reading Pages"
        numericActivity.type = ActivityType.numeric.rawValue
        numericActivity.color = "#008C8C"
        numericActivity.createdAt = Date()
        numericActivity.isActive = true
        numericActivity.sortOrder = 1
        
        return VStack(spacing: DesignSystem.Spacing.md) {
            ActivityCard(activity: timerActivity)
            ActivityCard(activity: numericActivity)
        }
        .padding()
        .background(DesignSystem.Colors.background)
        .environment(\.managedObjectContext, context)
        .preferredColorScheme(.dark)
    }
}

