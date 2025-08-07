import SwiftUI

struct OnboardingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Please sign in to iCloud in Settings")
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
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
