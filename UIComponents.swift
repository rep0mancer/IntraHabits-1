import SwiftUI

// MARK: - Loading View
struct LoadingView: View {
    let message: String
    
    init(_ message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
            
            Text(LocalizedStringKey(message))
                .font(DesignSystem.Typography.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let buttonTitle: LocalizedStringKey?
    let buttonAction: (() -> Void)?
    
    init(
        icon: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        buttonTitle: LocalizedStringKey? = nil,
        buttonAction: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.buttonTitle = buttonTitle
        self.buttonAction = buttonAction
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()
            
            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundColor(DesignSystem.Colors.systemGray3)
                
                Text(title)
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }
            
            if let buttonTitle = buttonTitle, let buttonAction = buttonAction {
                Button(action: buttonAction) {
                    Text(buttonTitle)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Error View
struct ErrorView: View {
    let error: Error
    let retryAction: (() -> Void)?
    
    init(error: Error, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()
            
            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("error.title")
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(.primary)
                
                Text(error.localizedDescription)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }
            
            if let retryAction = retryAction {
                Button(action: retryAction) {
                    Text("error.retry")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Floating Action Button
struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    let backgroundColor: Color
    let foregroundColor: Color
    
    init(
        icon: String,
        backgroundColor: Color = DesignSystem.Colors.primary,
        foregroundColor: Color = .white,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(foregroundColor)
                .frame(width: 56, height: 56)
                .background(backgroundColor)
                .clipShape(Circle())
                .shadow(
                    color: DesignSystem.Shadow.button.color,
                    radius: DesignSystem.Shadow.button.radius,
                    x: DesignSystem.Shadow.button.x,
                    y: DesignSystem.Shadow.button.y
                )
        }
        .hapticFeedback(.medium)
    }
}

// MARK: - Segmented Control
struct CustomSegmentedControl<T: Hashable>: View {
    let options: [T]
    let optionLabels: [T: String]
    @Binding var selection: T
    
    init(
        options: [T],
        optionLabels: [T: String],
        selection: Binding<T>
    ) {
        self.options = options
        self.optionLabels = optionLabels
        self._selection = selection
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button(action: { selection = option }) {
                    Text(optionLabels[option] ?? "")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(selection == option ? .white : DesignSystem.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            selection == option ? 
                            DesignSystem.Colors.primary : 
                            Color.clear
                        )
                }
                .hapticFeedback(.light)
            }
        }
        .background(DesignSystem.Colors.systemGray6)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .animation(DesignSystem.Animation.quick, value: selection)
    }
}

// MARK: - Badge View
struct BadgeView: View {
    let text: String
    let backgroundColor: Color
    let foregroundColor: Color
    
    init(
        text: String,
        backgroundColor: Color = DesignSystem.Colors.primary,
        foregroundColor: Color = .white
    ) {
        self.text = text
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }
    
    var body: some View {
        Text(text)
            .font(DesignSystem.Typography.caption2)
            .fontWeight(.semibold)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(12)
    }
}

// MARK: - Progress Ring
struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    let color: Color
    
    init(
        progress: Double,
        lineWidth: CGFloat = 8,
        size: CGFloat = 60,
        color: Color = DesignSystem.Colors.primary
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.size = size
        self.color = color
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(DesignSystem.Animation.standard, value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: LocalizedStringKey
    let value: String
    let subtitle: String?
    let icon: String?
    let color: Color
    
    init(
        title: LocalizedStringKey,
        value: String,
        subtitle: String? = nil,
        icon: String? = nil,
        color: Color = DesignSystem.Colors.primary
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            Text(value)
                .font(DesignSystem.Typography.numberLarge)
                .foregroundColor(color)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle()
    }
}

// MARK: - Haptic Feedback Button
struct HapticButton<Content: View>: View {
    let style: UIImpactFeedbackGenerator.FeedbackStyle
    let action: () -> Void
    let content: Content
    
    init(
        style: UIImpactFeedbackGenerator.FeedbackStyle = .medium,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: style)
            impactFeedback.impactOccurred()
            action()
        }) {
            content
        }
    }
}

// MARK: - Previews
struct UIComponents_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                LoadingView("Loading activities...")
                
                EmptyStateView(
                    icon: "plus.circle",
                    title: "No Activities",
                    subtitle: "Add your first activity to get started",
                    buttonTitle: "Add Activity",
                    buttonAction: {}
                )
                .frame(height: 300)
                
                HStack {
                    StatCard(
                        title: "Today",
                        value: "5",
                        subtitle: "activities completed",
                        icon: "checkmark.circle",
                        color: DesignSystem.Colors.teal
                    )
                    
                    StatCard(
                        title: "Streak",
                        value: "12",
                        subtitle: "days",
                        icon: "flame",
                        color: .orange
                    )
                }
                
                HStack {
                    ProgressRing(progress: 0.7, color: DesignSystem.Colors.primary)
                    ProgressRing(progress: 0.4, color: DesignSystem.Colors.teal)
                    ProgressRing(progress: 0.9, color: DesignSystem.Colors.amber)
                }
                
                FloatingActionButton(icon: "plus", action: {})
            }
            .padding()
        }
        .background(DesignSystem.Colors.background)
        .preferredColorScheme(.dark)
    }
}

