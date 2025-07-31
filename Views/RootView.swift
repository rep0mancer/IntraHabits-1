import SwiftUI
import CoreData

struct RootView: View {
    @EnvironmentObject private var syncController: SyncController
    @StateObject private var listViewModel: ActivityListViewModel
    @State private var signedIn = false

    /// Dependency-inject the managed-object context (previews and tests can pass their own).
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
        let previewContext = PersistenceController.preview.container.viewContext
        RootView(context: previewContext)
            .preferredColorScheme(.light)
        RootView(context: previewContext)
            .preferredColorScheme(.dark)
    }
}
