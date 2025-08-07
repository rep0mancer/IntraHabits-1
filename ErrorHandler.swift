import SwiftUI

@MainActor
final class ErrorHandler: ObservableObject {
    @Published var currentError: Error?
    @Published var showingAlert = false

    func handle(_ error: Error) {
        currentError = error
        showingAlert = true
    }
}
