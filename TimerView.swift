import SwiftUI
import CoreData
import Combine

struct TimerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var activity: Activity
    @StateObject private var viewModel: TimerViewModel

    init(activity: Activity) {
        self.activity = activity
        _viewModel = StateObject(wrappedValue: TimerViewModel(activity: activity, context: PersistenceController.shared.container.viewContext))
    }
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: DesignSystem.Spacing.xl) {
                // Header
                headerSection
                
                Spacer()
                
                // Timer Display
                timerDisplay
                
                // Today's Total
                todaysTotalSection
                
                Spacer()
                
                // Control Buttons
                controlButtons
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .onDisappear {
            viewModel.stopTimer()
        }
        .alert("timer.save.title", isPresented: $viewModel.showingSaveConfirmation) {
            Button("common.cancel", role: .cancel) {
                viewModel.discardSession()
            }
            Button("timer.save.save") {
                if viewModel.saveSession() {
                    HapticManager.notification(.success)
                }
                dismiss()
            }
        } message: {
            Text("timer.save.message")
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Button(action: {
                if viewModel.timerState == .stopped && viewModel.currentDuration > 0 {
                    viewModel.showingSaveConfirmation = true
                } else {
                    dismiss()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(DesignSystem.Colors.secondaryBackground)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text(activity.displayName)
                .font(DesignSystem.Typography.title2)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            // Invisible button for balance
            Button(action: {}) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.clear)
                    .frame(width: 44, height: 44)
            }
            .disabled(true)
        }
    }
    
    // MARK: - Timer Display
    private var timerDisplay: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Main Timer
            Text(viewModel.formattedTime)
                .font(DesignSystem.Typography.timerLarge)
                .foregroundColor(activity.displayColor)
                .monospacedDigit()
                .scaleEffect(viewModel.timerState == .running ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: viewModel.timerState)
            
            // Timer State Indicator
            HStack(spacing: DesignSystem.Spacing.xs) {
                Circle()
                    .fill(stateIndicatorColor)
                    .frame(width: 8, height: 8)
                    .scaleEffect(viewModel.timerState == .running ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), 
                              value: viewModel.timerState == .running)
                
                Text(stateText)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Today's Total Section
    private var todaysTotalSection: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Text("timer.todays_total")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(.secondary)
            
            Text(viewModel.todaysFormattedTotal)
                .font(DesignSystem.Typography.title3)
                .foregroundColor(.primary)
                .monospacedDigit()
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.secondaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    // MARK: - Control Buttons
    private var controlButtons: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            // Stop Button
            Button(action: {
                HapticManager.impact(.light)
                viewModel.stopTimer()
                if viewModel.currentDuration > 0 {
                    viewModel.showingSaveConfirmation = true
                }
            }) {
                Image(systemName: "stop.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(DesignSystem.Colors.systemGray)
                    .clipShape(Circle())
            }
            .disabled(viewModel.currentDuration == 0)
            .opacity(viewModel.currentDuration == 0 ? 0.5 : 1.0)
            
            // Play/Pause Button
            Button(action: {
                switch viewModel.timerState {
                case .stopped:
                    HapticManager.impact(.medium)
                    viewModel.startTimer()
                case .running:
                    HapticManager.impact(.light)
                    viewModel.pauseTimer()
                case .paused:
                    HapticManager.impact(.medium)
                    viewModel.resumeTimer()
                }
            }) {
                Image(systemName: playPauseIcon)
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
                    .background(activity.displayColor)
                    .clipShape(Circle())
                    .scaleEffect(viewModel.timerState == .running ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.timerState)
            }
            // Save Button
            Button(action: {
                if viewModel.saveSession() {
                    HapticManager.notification(.success)
                }
                dismiss()
            }) {
                Image(systemName: "checkmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.green)
                    .clipShape(Circle())
            }
            .disabled(viewModel.currentDuration == 0)
            .opacity(viewModel.currentDuration == 0 ? 0.5 : 1.0)
        }
    }
    
    // MARK: - Computed Properties
    private var playPauseIcon: String {
        switch viewModel.timerState {
        case .stopped, .paused:
            return "play.fill"
        case .running:
            return "pause.fill"
        }
    }
    
    private var stateIndicatorColor: Color {
        switch viewModel.timerState {
        case .stopped:
            return .secondary
        case .running:
            return .green
        case .paused:
            return .orange
        }
    }
    
    private var stateText: String {
        switch viewModel.timerState {
        case .stopped:
            return NSLocalizedString("timer.state.stopped", comment: "")
        case .running:
            return NSLocalizedString("timer.state.running", comment: "")
        case .paused:
            return NSLocalizedString("timer.state.paused", comment: "")
        }
    }
}

// MARK: - Timer State
enum TimerState {
    case stopped
    case running
    case paused
}

// MARK: - Timer View Model
class TimerViewModel: ObservableObject {
    @Published var currentDuration: TimeInterval = 0
    @Published var timerState: TimerState = .stopped
    @Published var todaysFormattedTotal = "0m"
    @Published var showingSaveConfirmation = false
    @Published var errorMessage: String?
    
    private let activity: Activity
    private let viewContext: NSManagedObjectContext
    private var timer: Timer?
    private var startTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var cancellables = Set<AnyCancellable>()

    init(activity: Activity, context: NSManagedObjectContext) {
        self.activity = activity
        self.viewContext = context
        updateTodaysTotal()

        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateTodaysTotal()
                }
            }
            .store(in: &cancellables)
    }
    
    var formattedTime: String {
        formatDuration(currentDuration)
    }
    
    
    func startTimer() {
        guard timerState == .stopped else { return }
        
        timerState = .running
        startTime = Date()
        pausedDuration = 0
        
        startTimerLoop()
    }
    
    func pauseTimer() {
        guard timerState == .running else { return }
        
        timerState = .paused
        pausedDuration = currentDuration
        stopTimerLoop()
    }
    
    func resumeTimer() {
        guard timerState == .paused else { return }
        
        timerState = .running
        startTime = Date().addingTimeInterval(-pausedDuration)
        
        startTimerLoop()
    }
    
    func stopTimer() {
        timerState = .stopped
        stopTimerLoop()
    }
    
    
    func saveSession() -> Bool {
        let activity = activity
        let context = viewContext
        guard currentDuration > 0 else { return false }

        let session = ActivitySession(context: context)
        session.id = UUID()
        session.activity = activity
        session.sessionDate = Date()
        session.duration = currentDuration
        session.createdAt = Date()
        session.isCompleted = true

        do {
            updateStreaks(for: activity)
            try context.save()

            // Reset timer
            currentDuration = 0
            timerState = .stopped
            pausedDuration = 0

            return true
        } catch {
            AppLogger.error("Error saving timer session: (error)")
            errorMessage = error.localizedDescription
            return false
        }
    }
        
    }
    
    func discardSession() {
        currentDuration = 0
        timerState = .stopped
        pausedDuration = 0
        showingSaveConfirmation = false
    }
    
    private func startTimerLoop() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateCurrentDuration()
        }
    }
    
    private func stopTimerLoop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateCurrentDuration() {
        guard let startTime = startTime else { return }
        currentDuration = Date().timeIntervalSince(startTime)
    }
    
    private func updateTodaysTotal() {
        todaysFormattedTotal = activity.todaysFormattedTotal()
    }

    private func updateStreaks(for activity: Activity) {
        guard let sessions = activity.sessions?.allObjects as? [ActivitySession] else {
            activity.currentStreak = 0
            activity.longestStreak = 0
            return
        }

        let calendar = Calendar.current
        let sessionDates = sessions.compactMap { $0.sessionDate }.map { calendar.startOfDay(for: $0) }

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
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    deinit {
        stopTimerLoop()
    }
}

// MARK: - Preview
struct TimerView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        let activity = Activity(context: context)
        activity.id = UUID()
        activity.name = "Exercise"
        activity.type = ActivityType.timer.rawValue
        activity.color = "#CD3A2E"
        activity.createdAt = Date()
        activity.isActive = true
        
        return TimerView(activity: activity)
            .environment(\.managedObjectContext, context)
            .preferredColorScheme(.dark)
    }
}

