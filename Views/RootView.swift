import SwiftUI

struct RootView: View {
    @StateObject var cloudService = CloudKitService()

    var body: some View {
        Group {
            if cloudService.isSignedIn {
                ContentView()
            } else {
                OnboardingView()
            }
        }
        .onAppear { Task { await cloudService.checkAccountStatus() } }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RootView().previewDisplayName("Light")
            RootView().preferredColorScheme(.dark).previewDisplayName("Dark")
        }
    }
}
