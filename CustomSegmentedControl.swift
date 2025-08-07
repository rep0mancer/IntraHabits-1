import SwiftUI

struct CustomSegmentedControl<T: Hashable>: View {
    let options: [T]
    let optionLabels: [T: String]
    @Binding var selection: T
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = option
                    }
                }) {
                    Text(optionLabels[option] ?? "")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(selection == option ? .white : DesignSystem.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            selection == option ? 
                            DesignSystem.Colors.primary : 
                            Color.clear
                        )
                        .cornerRadius(
                            DesignSystem.CornerRadius.small,
                            corners: cornerMask(for: index)
                        )
                }
                .hapticFeedback(.light)
                .accessibilityLabel(optionLabels[option] ?? "")
                .accessibilityAddTraits(.isButton)
            }
        }
        .background(DesignSystem.Colors.secondaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.small)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .stroke(DesignSystem.Colors.systemGray4, lineWidth: 1)
        )
    }
    
    private func cornerMask(for index: Int) -> UIRectCorner {
        if index == 0 {
            return [.topLeft, .bottomLeft]
        } else if index == options.count - 1 {
            return [.topRight, .bottomRight]
        } else {
            return []
        }
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview
struct CustomSegmentedControl_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            CustomSegmentedControl(
                options: [ActivityType.numeric, ActivityType.timer],
                optionLabels: [
                    .numeric: "Numeric",
                    .timer: "Timer"
                ],
                selection: .constant(.numeric)
            )
            
            CustomSegmentedControl(
                options: ["Week", "Month", "Year"],
                optionLabels: [
                    "Week": "Week",
                    "Month": "Month", 
                    "Year": "Year"
                ],
                selection: .constant("Week")
            )
        }
        .padding()
        .background(DesignSystem.Colors.background)
    }
}

