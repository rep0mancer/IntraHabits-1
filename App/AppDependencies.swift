import Foundation

final class AppDependencies {
    let cloudService: CloudKitService
    let storeService: StoreKitService
    let errorHandler: ErrorHandler

    init() {
        cloudService = CloudKitService()
        storeService = StoreKitService()
        errorHandler = ErrorHandler()
    }

    static let shared = AppDependencies()
}
