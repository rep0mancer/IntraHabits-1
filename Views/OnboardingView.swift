import SwiftUI

struct OnboardingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("onboarding.icloud.sign_in_prompt")
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("onboardingIcloudPrompt")
            Button("onboarding.open_settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .accessibilityIdentifier("onboardingOpenSettings")
            Spacer()
        }
        .padding()
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OnboardingView().previewDisplayName("Light")
            OnboardingView().previewDisplayName("Dark")
        }
    }
}
