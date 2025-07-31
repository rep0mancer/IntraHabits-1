import SwiftUI

struct RootView: View {
    @EnvironmentObject private var syncController: SyncController
    @StateObject private var listViewModel = ActivityListViewModel()
    @State private var signedIn = false

    var body: some View {
        Group {
            if signedIn {
                ContentView(viewModel: listViewModel)
            } else {
                OnboardingView()
            }
        }
        .onAppear { checkAccountStatus() }
    }

    private func checkAccountStatus() {
        Task {
            let status = await syncController.checkAccountStatus()
            await MainActor.run { signedIn = status == .available }
        }
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
