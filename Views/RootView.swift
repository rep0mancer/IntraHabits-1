import SwiftUI

struct RootView: View {
    @EnvironmentObject private var syncController: SyncController
    @StateObject private var listViewModel: ActivityListViewModel
    @State private var signedIn = false

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        _listViewModel = StateObject(wrappedValue: ActivityListViewModel(context: context))
    }

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
            RootView(context: PersistenceController.preview.container.viewContext).previewDisplayName("Light")
            RootView(context: PersistenceController.preview.container.viewContext).preferredColorScheme(.dark).previewDisplayName("Dark")
        }
    }
}
