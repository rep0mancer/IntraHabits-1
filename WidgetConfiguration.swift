import SwiftUI

// MARK: - Widget Configuration
struct WidgetConfiguration {
    // MARK: - Design Constants
    static let primaryColor = Color(red: 0.8, green: 0.23, blue: 0.18) // #CD3A2E
    static let tealColor = Color(red: 0.0, green: 0.55, blue: 0.55) // #008C8C
    static let indigoColor = Color(red: 0.29, green: 0.36, blue: 0.77) // #4B5CC4
    static let amberColor = Color(red: 0.96, green: 0.69, blue: 0.26) // #F6B042
    
    static let cornerRadius: CGFloat = 12
    static let shadowRadius: CGFloat = 4
    static let shadowOffset: CGSize = CGSize(width: 0, height: 2)
    
    // MARK: - Widget Limits
    static let maxActivitiesInWidget = 4
    static let maxStatsActivities = 3
    
    // MARK: - Color Mapping
    static func colorForActivity(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "red":
            return primaryColor
        case "teal":
            return tealColor
        case "indigo":
            return indigoColor
        case "amber", "orange":
            return amberColor
        case "green":
            return .green
        case "purple":
            return .purple
        case "blue":
            return .blue
        case "brown":
            return .brown
        case "gray", "grey":
            return .gray
        default:
            return primaryColor
        }
    }
    
    // MARK: - Typography
    static let titleFont = Font.system(.caption, design: .rounded, weight: .semibold)
    static let bodyFont = Font.system(.caption, design: .default, weight: .regular)
    static let numberFont = Font.system(.caption, design: .rounded, weight: .bold)
    static let smallFont = Font.system(.caption2, design: .default, weight: .regular)
    
    // MARK: - Spacing
    static let smallSpacing: CGFloat = 4
    static let mediumSpacing: CGFloat = 8
    static let largeSpacing: CGFloat = 12
    static let extraLargeSpacing: CGFloat = 16
    
    // MARK: - Icon Sizes
    static let smallIconSize: CGFloat = 12
    static let mediumIconSize: CGFloat = 16
    static let largeIconSize: CGFloat = 20
    
    // MARK: - Progress Indicators
    static let progressBarHeight: CGFloat = 4
    static let progressRingLineWidth: CGFloat = 4
    static let smallProgressRingSize: CGFloat = 24
    static let mediumProgressRingSize: CGFloat = 60
    
    // MARK: - Button Styles
    static let buttonCornerRadius: CGFloat = 8
    static let capsuleButtonCornerRadius: CGFloat = 20
    static let buttonPadding = EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
    
    // MARK: - Animation Durations
    static let shortAnimation: Double = 0.2
    static let mediumAnimation: Double = 0.3
    static let longAnimation: Double = 0.5
}

// MARK: - Widget Error Types
enum WidgetError: Error, LocalizedError {
    case activityNotFound
    case timerNotRunning
    case dataServiceError
    case invalidConfiguration
    
    var errorDescription: String? {
        switch self {
        case .activityNotFound:
            return "Activity not found"
        case .timerNotRunning:
            return "Timer is not running"
        case .dataServiceError:
            return "Data service error"
        case .invalidConfiguration:
            return "Invalid widget configuration"
        }
    }
}

// MARK: - Widget Helper Functions
extension WidgetConfiguration {
    // MARK: - Time Formatting
    static func formatDuration(_ duration: TimeInterval, style: DurationStyle = .abbreviated) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        switch style {
        case .abbreviated:
            if hours > 0 {
                return String(format: "%dh %dm", hours, minutes)
            } else if minutes > 0 {
                return String(format: "%dm", minutes)
            } else {
                return "< 1m"
            }
            
        case .precise:
            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%d:%02d", minutes, seconds)
            }
            
        case .compact:
            if hours > 0 {
                return String(format: "%dh", hours)
            } else if minutes > 0 {
                return String(format: "%dm", minutes)
            } else {
                return String(format: "%ds", seconds)
            }
        }
    }
    
    // MARK: - Number Formatting
    static func formatNumber(_ number: Double, style: NumberStyle = .standard) -> String {
        switch style {
        case .standard:
            if number >= 1000 {
                return String(format: "%.1fk", number / 1000)
            } else {
                return String(format: "%.0f", number)
            }
            
        case .precise:
            return String(format: "%.1f", number)
            
        case .integer:
            return String(format: "%.0f", number)
        }
    }
    
    // MARK: - Progress Calculation
    static func calculateProgress(current: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(current / target, 1.0)
    }
    
    // MARK: - Color Utilities
    static func adaptiveColor(light: Color, dark: Color) -> Color {
        return Color(.systemBackground) == .black ? dark : light
    }
    
    static func contrastingTextColor(for backgroundColor: Color) -> Color {
        // Simplified contrast calculation
        return backgroundColor == .black || backgroundColor == primaryColor ? .white : .black
    }
}

// MARK: - Supporting Enums
enum DurationStyle {
    case abbreviated  // "1h 30m"
    case precise     // "1:30:45"
    case compact     // "1h"
}

enum NumberStyle {
    case standard    // "1.2k"
    case precise     // "1234.5"
    case integer     // "1234"
}

// MARK: - Widget Size Helpers
extension WidgetConfiguration {
    static func isSmallWidget(_ family: WidgetFamily) -> Bool {
        return family == .systemSmall
    }
    
    static func isMediumWidget(_ family: WidgetFamily) -> Bool {
        return family == .systemMedium
    }
    
    static func isLargeWidget(_ family: WidgetFamily) -> Bool {
        return family == .systemLarge
    }
    
    static func maxActivitiesForFamily(_ family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall:
            return 1
        case .systemMedium:
            return 2
        case .systemLarge:
            return 4
        default:
            return 1
        }
    }
}

// MARK: - Accessibility Helpers
extension WidgetConfiguration {
    static func accessibilityLabel(for activity: ActivityEntity, value: Double, type: String) -> String {
        if type == "timer" {
            let duration = formatDuration(value, style: .abbreviated)
            return "\(activity.name), timer activity, \(duration)"
        } else {
            let count = formatNumber(value, style: .integer)
            return "\(activity.name), numeric activity, \(count)"
        }
    }
    
    static func accessibilityHint(for action: String) -> String {
        switch action {
        case "start":
            return "Double tap to start timer"
        case "stop":
            return "Double tap to stop timer"
        case "pause":
            return "Double tap to pause timer"
        case "increment":
            return "Double tap to add one"
        default:
            return "Double tap to activate"
        }
    }
}

