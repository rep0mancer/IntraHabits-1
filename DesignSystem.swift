import SwiftUI

// MARK: - Design System
struct DesignSystem {
    
    // MARK: - Colors
    struct Colors {
        // Primary brand color
        static let primary = Color(hex: "#CD3A2E")
        
        // Secondary colors
        static let teal = Color(hex: "#008C8C")
        static let indigo = Color(hex: "#4B5CC4")
        static let amber = Color(hex: "#F6B042")
        
        // System grays
        static let systemGray = Color(.systemGray)
        static let systemGray2 = Color(.systemGray2)
        static let systemGray3 = Color(.systemGray3)
        static let systemGray4 = Color(.systemGray4)
        static let systemGray5 = Color(.systemGray5)
        static let systemGray6 = Color(.systemGray6)
        
        // Background colors
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let tertiaryBackground = Color(.tertiarySystemBackground)
        
        // Activity colors palette
        static let activityColors: [String] = [
            "#CD3A2E", // Primary red
            "#008C8C", // Teal
            "#4B5CC4", // Indigo
            "#F6B042", // Amber
            "#8E8E93", // System gray
            "#34C759", // Green
            "#FF9500", // Orange
            "#AF52DE", // Purple
            "#007AFF", // Blue
            "#5AC8FA", // Light blue
            "#32D74B", // Mint
            "#A2845E"  // Brown
        ]
    }
    
    // MARK: - Typography
    struct Typography {
        // SF Pro Display for headlines
        static let largeTitle = Font.system(.largeTitle, design: .default, weight: .bold)
        static let title1 = Font.system(.title, design: .default, weight: .bold)
        static let title2 = Font.system(.title2, design: .default, weight: .semibold)
        static let title3 = Font.system(.title3, design: .default, weight: .semibold)
        
        // SF Pro Text for body
        static let headline = Font.system(.headline, design: .default, weight: .semibold)
        static let body = Font.system(.body, design: .default, weight: .regular)
        static let callout = Font.system(.callout, design: .default, weight: .regular)
        static let subheadline = Font.system(.subheadline, design: .default, weight: .regular)
        static let footnote = Font.system(.footnote, design: .default, weight: .regular)
        static let caption1 = Font.system(.caption, design: .default, weight: .regular)
        static let caption2 = Font.system(.caption2, design: .default, weight: .regular)
        
        // SF Rounded for numbers and counters
        static let numberLarge = Font.system(.largeTitle, design: .rounded, weight: .bold)
        static let numberMedium = Font.system(.title, design: .rounded, weight: .semibold)
        static let numberSmall = Font.system(.headline, design: .rounded, weight: .medium)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 20
    }
    
    // MARK: - Shadows
    struct Shadow {
        static let card = ShadowDefinition(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        static let button = ShadowDefinition(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)

        struct ShadowDefinition {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
    }
    
    // MARK: - Animation
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.8)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard CharacterSet(charactersIn: trimmed).isSubset(of: CharacterSet(charactersIn: "0123456789ABCDEFabcdef")) else {
            AppLogger.error("Invalid hex string: \(hex)")
            self = .black
            return
        }
        var int: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch trimmed.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}

// MARK: - View Modifiers
struct CardStyle: ViewModifier {
    let backgroundColor: Color
    let cornerRadius: CGFloat
    let shadow: DesignSystem.Shadow.ShadowDefinition
    
    init(
        backgroundColor: Color = DesignSystem.Colors.secondaryBackground,
        cornerRadius: CGFloat = DesignSystem.CornerRadius.medium,
        shadow: DesignSystem.Shadow.ShadowDefinition = DesignSystem.Shadow.card
    ) {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.shadow = shadow
    }
    
    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(
                color: shadow.color,
                radius: shadow.radius,
                x: shadow.x,
                y: shadow.y
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool
    
    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                isEnabled ? DesignSystem.Colors.primary : DesignSystem.Colors.systemGray4
            )
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.headline)
            .foregroundColor(DesignSystem.Colors.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(DesignSystem.Colors.primary.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - View Extensions
extension View {
    func cardStyle(
        backgroundColor: Color = DesignSystem.Colors.secondaryBackground,
        cornerRadius: CGFloat = DesignSystem.CornerRadius.medium,
        shadow: DesignSystem.Shadow.ShadowDefinition = DesignSystem.Shadow.card
    ) -> some View {
        modifier(CardStyle(backgroundColor: backgroundColor, cornerRadius: cornerRadius, shadow: shadow))
    }
    
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        onTapGesture {
            let impactFeedback = UIImpactFeedbackGenerator(style: style)
            impactFeedback.impactOccurred()
        }
    }
}

