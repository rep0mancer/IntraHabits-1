import Foundation
import WidgetKit

// MARK: - Widget Timer Service
class WidgetTimerService: ObservableObject {
    static let shared = WidgetTimerService()
    
    private let userDefaults: UserDefaults
    private let appGroupIdentifier = DefaultsKeys.appGroupIdentifier
    private(set) var isEnabled = true
    
    private var timerStates: [String: WidgetTimerState] = [:]
    // Repeating timers for widget refreshes keyed by activityId
    private var updateTimers: [String: Timer] = [:]
    
    private init() {
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            self.userDefaults = sharedDefaults
            loadTimerStates()
        } else {
            self.userDefaults = UserDefaults.standard
            self.isEnabled = false
            AppLogger.error("WidgetTimerService: Unable to create shared UserDefaults. Timer widgets are disabled.")
        }
    }
    
    // MARK: - Timer State Management
    func getTimerState(for activityId: String) -> WidgetTimerState? {
        return timerStates[activityId]
    }
    
    func isTimerRunning(for activityId: String) -> Bool {
        return timerStates[activityId]?.isRunning == true
    }
    
    func isTimerPaused(for activityId: String) -> Bool {
        return timerStates[activityId]?.isPaused == true
    }
    
    func getCurrentDuration(for activityId: String) -> TimeInterval {
        return timerStates[activityId]?.currentDuration ?? 0
    }
    
    // Exposed for tests to verify lifecycle of update timers
    func hasScheduledUpdateTimer(for activityId: String) -> Bool {
        return updateTimers[activityId] != nil
    }
    
    // MARK: - Timer Actions
    func startTimer(for activityId: String) async throws {
        let currentState = timerStates[activityId]
        
        let newState = WidgetTimerState(
            activityId: activityId,
            isRunning: true,
            isPaused: false,
            startTime: Date(),
            pausedDuration: currentState?.pausedDuration ?? 0,
            totalDuration: currentState?.totalDuration ?? 0
        )
        
        timerStates[activityId] = newState
        saveTimerStates()
        
        // Schedule widget updates
        scheduleTimerUpdates(for: activityId)
    }
    
    func pauseTimer(for activityId: String) async throws {
        guard var currentState = timerStates[activityId],
              currentState.isRunning,
              !currentState.isPaused else {
            throw WidgetError.timerNotRunning
        }
        
        let pausedDuration = currentState.pausedDuration + (currentState.startTime.map { Date().timeIntervalSince($0) } ?? 0)
        
        let newState = WidgetTimerState(
            activityId: activityId,
            isRunning: true,
            isPaused: true,
            startTime: nil,
            pausedDuration: pausedDuration,
            totalDuration: currentState.totalDuration
        )
        
        timerStates[activityId] = newState
        saveTimerStates()
        
        // Cancel scheduled updates
        cancelTimerUpdates(for: activityId)
    }
    
    func resumeTimer(for activityId: String) async throws {
        guard var currentState = timerStates[activityId],
              currentState.isRunning,
              currentState.isPaused else {
            throw WidgetError.timerNotRunning
        }
        
        let newState = WidgetTimerState(
            activityId: activityId,
            isRunning: true,
            isPaused: false,
            startTime: Date(),
            pausedDuration: currentState.pausedDuration,
            totalDuration: currentState.totalDuration
        )
        
        timerStates[activityId] = newState
        saveTimerStates()
        
        // Resume scheduled updates
        scheduleTimerUpdates(for: activityId)
    }
    
    func stopTimer(for activityId: String) async throws -> TimeInterval {
        guard let currentState = timerStates[activityId],
              currentState.isRunning else {
            throw WidgetError.timerNotRunning
        }
        
        let finalDuration = currentState.currentDuration
        
        // Clear timer state
        timerStates.removeValue(forKey: activityId)
        saveTimerStates()
        
        // Cancel scheduled updates
        cancelTimerUpdates(for: activityId)
        
        return finalDuration
    }
    
    // MARK: - Persistence
    private func loadTimerStates() {
        guard let data = userDefaults.data(forKey: DefaultsKeys.widgetTimerStates) else {
            return
        }

        do {
            let decoded = try JSONDecoder().decode([String: TimerStateData].self, from: data)
            timerStates = decoded.mapValues { data in
                WidgetTimerState(
                    activityId: data.activityId,
                    isRunning: data.isRunning,
                    isPaused: data.isPaused,
                    startTime: data.startTime,
                    pausedDuration: data.pausedDuration,
                    totalDuration: data.totalDuration
                )
            }
        } catch {
            AppLogger.error("WidgetTimerService: Failed to decode timer states - \(error.localizedDescription)")
        }
    }
    
    private func saveTimerStates() {
        let data = timerStates.mapValues { state in
            TimerStateData(
                activityId: state.activityId,
                isRunning: state.isRunning,
                isPaused: state.isPaused,
                startTime: state.startTime,
                pausedDuration: state.pausedDuration,
                totalDuration: state.totalDuration
            )
        }
        
        if let encoded = try? JSONEncoder().encode(data) {
            userDefaults.set(encoded, forKey: DefaultsKeys.widgetTimerStates)
        }
    }
    
    // MARK: - Widget Updates
    private func scheduleTimerUpdates(for activityId: String) {
        // Avoid scheduling multiple timers for the same activity
        if updateTimers[activityId] != nil {
            return
        }
        
        // Trigger an immediate refresh
        WidgetCenter.shared.reloadTimelines(ofKind: "ActivityTimerWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "ActivityQuickActionsWidget")
        
        // Create a repeating timer to refresh every 30 seconds while running
        let timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isTimerRunning(for: activityId) {
                WidgetCenter.shared.reloadTimelines(ofKind: "ActivityTimerWidget")
                WidgetCenter.shared.reloadTimelines(ofKind: "ActivityQuickActionsWidget")
            } else {
                // If it is no longer running, clean up this timer
                self.cancelTimerUpdates(for: activityId)
            }
        }
        // Ensure the timer fires on common run loop modes to not pause during interactions
        RunLoop.main.add(timer, forMode: .common)
        updateTimers[activityId] = timer
    }
    
    private func cancelTimerUpdates(for activityId: String) {
        if let timer = updateTimers[activityId] {
            timer.invalidate()
            updateTimers.removeValue(forKey: activityId)
        }
        // Trigger a final refresh to reflect stopped/paused state
        WidgetCenter.shared.reloadTimelines(ofKind: "ActivityTimerWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "ActivityQuickActionsWidget")
    }
    
    // MARK: - Cleanup
    func cleanupExpiredTimers() {
        let now = Date()
        let maxTimerDuration: TimeInterval = 24 * 60 * 60 // 24 hours
        
        for (activityId, state) in timerStates {
            if let startTime = state.startTime,
               now.timeIntervalSince(startTime) > maxTimerDuration {
                timerStates.removeValue(forKey: activityId)
                cancelTimerUpdates(for: activityId)
            }
        }
        
        saveTimerStates()
    }
}

// MARK: - Timer State Data (for persistence)
private struct TimerStateData: Codable {
    let activityId: String
    let isRunning: Bool
    let isPaused: Bool
    let startTime: Date?
    let pausedDuration: TimeInterval
    let totalDuration: TimeInterval
}

