import SwiftUI
import UIKit

// MARK: - Accessibility Helper
struct AccessibilityHelper {
    
    // MARK: - Activity Accessibility
    
    static func activityCardAccessibilityLabel(
        name: String,
        type: String,
        todayValue: String,
        isCompleted: Bool
    ) -> String {
        let typeDescription = type == "timer" ? 
            NSLocalizedString("accessibility.activity.type.timer", comment: "") :
            NSLocalizedString("accessibility.activity.type.numeric", comment: "")
        
        let completionStatus = isCompleted ?
            NSLocalizedString("accessibility.activity.completed", comment: "") :
            NSLocalizedString("accessibility.activity.not_completed", comment: "")
        
        return "\(name), \(typeDescription), \(NSLocalizedString("accessibility.activity.today", comment: "")) \(todayValue), \(completionStatus)"
    }
    
    static func activityCardAccessibilityHint(type: String) -> String {
        if type == "timer" {
            return NSLocalizedString("accessibility.activity.hint.timer", comment: "")
        } else {
            return NSLocalizedString("accessibility.activity.hint.numeric", comment: "")
        }
    }
    
    // MARK: - Timer Accessibility
    
    static func timerAccessibilityLabel(
        activityName: String,
        currentTime: String,
        state: TimerState
    ) -> String {
        let stateDescription: String
        switch state {
        case .stopped:
            stateDescription = NSLocalizedString("accessibility.timer.stopped", comment: "")
        case .running:
            stateDescription = NSLocalizedString("accessibility.timer.running", comment: "")
        case .paused:
            stateDescription = NSLocalizedString("accessibility.timer.paused", comment: "")
        }
        
        return "\(activityName) \(NSLocalizedString("accessibility.timer.label", comment: "")), \(currentTime), \(stateDescription)"
    }
    
    static func timerButtonAccessibilityLabel(state: TimerState) -> String {
        switch state {
        case .stopped:
            return NSLocalizedString("accessibility.timer.button.start", comment: "")
        case .running:
            return NSLocalizedString("accessibility.timer.button.pause", comment: "")
        case .paused:
            return NSLocalizedString("accessibility.timer.button.resume", comment: "")
        }
    }
    
    // MARK: - Statistics Accessibility
    
    static func statisticsCardAccessibilityLabel(
        title: String,
        value: String,
        subtitle: String?
    ) -> String {
        if let subtitle = subtitle {
            return "\(title), \(value), \(subtitle)"
        } else {
            return "\(title), \(value)"
        }
    }
    
    static func progressBarAccessibilityLabel(
        activity: String,
        value: Double,
        maxValue: Double
    ) -> String {
        let percentage = Int((value / maxValue) * 100)
        return "\(activity), \(percentage)% \(NSLocalizedString("accessibility.progress.completed", comment: ""))"
    }
    
    // MARK: - Calendar Accessibility
    
    static func calendarDayAccessibilityLabel(
        date: Date,
        hasSession: Bool,
        sessionCount: Int
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        let dateString = formatter.string(from: date)
        
        if hasSession {
            let sessionText = sessionCount == 1 ?
                NSLocalizedString("accessibility.calendar.one_session", comment: "") :
                String(format: NSLocalizedString("accessibility.calendar.multiple_sessions", comment: ""), sessionCount)
            return "\(dateString), \(sessionText)"
        } else {
            return "\(dateString), \(NSLocalizedString("accessibility.calendar.no_sessions", comment: ""))"
        }
    }
    
    // MARK: - Paywall Accessibility
    
    static func paywallFeatureAccessibilityLabel(
        title: String,
        description: String
    ) -> String {
        return "\(title), \(description)"
    }
    
    // MARK: - Settings Accessibility
    
    static func settingsToggleAccessibilityLabel(
        title: String,
        description: String,
        isOn: Bool
    ) -> String {
        let state = isOn ?
            NSLocalizedString("accessibility.toggle.on", comment: "") :
            NSLocalizedString("accessibility.toggle.off", comment: "")
        return "\(title), \(description), \(state)"
    }
    
    // MARK: - Sync Status Accessibility
    
    static func syncStatusAccessibilityLabel(
        status: SyncStatus,
        lastSyncDate: Date?
    ) -> String {
        let statusText = status.displayText
        
        if let lastSyncDate = lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let timeText = formatter.localizedString(for: lastSyncDate, relativeTo: Date())
            return "\(NSLocalizedString("accessibility.sync.status", comment: "")) \(statusText), \(NSLocalizedString("accessibility.sync.last_sync", comment: "")) \(timeText)"
        } else {
            return "\(NSLocalizedString("accessibility.sync.status", comment: "")) \(statusText)"
        }
    }
}

// MARK: - Timer State
enum TimerState {
    case stopped
    case running
    case paused
}

// MARK: - Accessibility View Modifiers
extension View {
    func accessibleActivityCard(
        name: String,
        type: String,
        todayValue: String,
        isCompleted: Bool
    ) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AccessibilityHelper.activityCardAccessibilityLabel(
                name: name,
                type: type,
                todayValue: todayValue,
                isCompleted: isCompleted
            ))
            .accessibilityHint(AccessibilityHelper.activityCardAccessibilityHint(type: type))
            .accessibilityAddTraits(.isButton)
    }
    
    func accessibleTimer(
        activityName: String,
        currentTime: String,
        state: TimerState
    ) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AccessibilityHelper.timerAccessibilityLabel(
                activityName: activityName,
                currentTime: currentTime,
                state: state
            ))
    }
    
    func accessibleStatisticsCard(
        title: String,
        value: String,
        subtitle: String? = nil
    ) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AccessibilityHelper.statisticsCardAccessibilityLabel(
                title: title,
                value: value,
                subtitle: subtitle
            ))
    }
    
    func accessibleProgressBar(
        activity: String,
        value: Double,
        maxValue: Double
    ) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AccessibilityHelper.progressBarAccessibilityLabel(
                activity: activity,
                value: value,
                maxValue: maxValue
            ))
            .accessibilityValue("\(Int((value / maxValue) * 100))%")
    }
    
    func accessibleCalendarDay(
        date: Date,
        hasSession: Bool,
        sessionCount: Int
    ) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AccessibilityHelper.calendarDayAccessibilityLabel(
                date: date,
                hasSession: hasSession,
                sessionCount: sessionCount
            ))
            .accessibilityAddTraits(hasSession ? [.isButton, .isSelected] : .isButton)
    }
    
    func accessibleToggle(
        title: String,
        description: String,
        isOn: Bool
    ) -> some View {
        self
            .accessibilityLabel(AccessibilityHelper.settingsToggleAccessibilityLabel(
                title: title,
                description: description,
                isOn: isOn
            ))
    }
}

// MARK: - Dynamic Type Support
extension View {
    func dynamicTypeSize() -> some View {
        self.dynamicTypeSize(.xSmall ... .accessibility5)
    }
    
    func scaledFont(_ font: Font, maxSize: CGFloat = 34) -> some View {
        self.font(font)
            .dynamicTypeSize(.xSmall ... .accessibility3)
    }
}

// MARK: - High Contrast Support
extension View {
    func adaptiveColors() -> some View {
        self.environment(\.colorSchemeContrast, .increased)
    }
}

// MARK: - Reduce Motion Support
extension View {
    func reduceMotionSensitive() -> some View {
        self.animation(.none, value: UUID())
    }
    
    func conditionalAnimation<V: Equatable>(
        _ animation: Animation?,
        value: V
    ) -> some View {
        Group {
            if UIAccessibility.isReduceMotionEnabled {
                self
            } else {
                self.animation(animation, value: value)
            }
        }
    }
}

