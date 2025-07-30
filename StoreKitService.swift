import Foundation
import StoreKit
import Combine

@MainActor
class StoreKitService: ObservableObject {
    
    // Product IDs
    private let unlimitedActivitiesProductID = "com.intrahabits.unlimited_activities"
    
    // Published properties
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Transaction listener
    private var transactionListener: Task<Void, Error>?

    init() {
        // Start listening for transactions
        transactionListener = listenForTransactions()
        
        // Load products and check purchase status
        Task {
            await loadProducts()
            await updatePurchaseStatus()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Product Loading
    
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let products = try await Product.products(for: [unlimitedActivitiesProductID])
            self.products = products
            
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            AppLogger.error("Error loading products: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase Management
    
    func purchase(_ product: Product) async -> PurchaseResult {
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                
                // Update purchase status
                await updatePurchaseStatus()
                
                // Finish the transaction
                await transaction.finish()
                
                // Haptic feedback
                HapticManager.notification(.success)
                
                return .success
                
            case .userCancelled:
                return .userCancelled
                
            case .pending:
                return .pending
                
            @unknown default:
                return .unknown
            }
            
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            AppLogger.error("Purchase error: \(error)")
            return .failed(error)
        }
    }
    
    func restorePurchases() async -> RestoreResult {
        do {
            try await AppStore.sync()
            await updatePurchaseStatus()
            
            if hasUnlimitedActivities {
                // Haptic feedback
                HapticManager.notification(.success)
                
                return .success
            } else {
                return .nothingToRestore
            }
            
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
            AppLogger.error("Restore error: \(error)")
            return .failed(error)
        }
    }
    
    // MARK: - Purchase Status
    
    var hasUnlimitedActivities: Bool {
        purchasedProductIDs.contains(unlimitedActivitiesProductID)
    }
    
    var unlimitedActivitiesProduct: Product? {
        products.first { $0.id == unlimitedActivitiesProductID }
    }
    
    func updatePurchaseStatus() async {
        var purchasedProducts: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                purchasedProducts.insert(transaction.productID)
            } catch {
                AppLogger.error("Transaction verification failed: \(error)")
            }
        }
        
        self.purchasedProductIDs = purchasedProducts
        
        // Update UserDefaults for quick access
        UserDefaults.standard.set(hasUnlimitedActivities, forKey: "hasUnlimitedActivities")
    }
    
    // MARK: - Transaction Listening
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    await MainActor.run {
                        Task {
                            await self.updatePurchaseStatus()
                        }
                    }
                    
                    await transaction.finish()
                } catch {
                    AppLogger.error("Transaction update error: \(error)")
                }
            }
        }
    }
    
    // MARK: - Verification
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Activity Limit Check
    
    func canAddMoreActivities(currentCount: Int) -> Bool {
        if hasUnlimitedActivities {
            return true
        }
        
        return currentCount < 5 // Free limit is 5 activities
    }
    
    func shouldShowPaywall(currentCount: Int) -> Bool {
        return !hasUnlimitedActivities && currentCount >= 5
    }
}

// MARK: - Purchase Result
enum PurchaseResult {
    case success
    case userCancelled
    case pending
    case failed(Error)
    case unknown
}

// MARK: - Restore Result
enum RestoreResult {
    case success
    case nothingToRestore
    case failed(Error)
}

// MARK: - StoreKit Errors
enum StoreKitError: LocalizedError {
    case failedVerification
    case productNotFound
    case purchaseNotAllowed
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return NSLocalizedString("storekit.error.verification_failed", comment: "")
        case .productNotFound:
            return NSLocalizedString("storekit.error.product_not_found", comment: "")
        case .purchaseNotAllowed:
            return NSLocalizedString("storekit.error.purchase_not_allowed", comment: "")
        }
    }
}

// MARK: - Purchase Manager
class PurchaseManager: ObservableObject {
    @Published var isPurchasing = false
    @Published var isRestoring = false
    @Published var showingPurchaseSuccess = false
    @Published var showingPurchaseError = false
    @Published var errorMessage: String?
    
    private let storeKitService = AppDependencies.shared.storeService
    
    func purchaseUnlimitedActivities() async {
        guard let product = storeKitService.unlimitedActivitiesProduct else {
            errorMessage = "Product not available"
            showingPurchaseError = true
            return
        }
        
        isPurchasing = true
        
        let result = await storeKitService.purchase(product)
        
        switch result {
        case .success:
            showingPurchaseSuccess = true
        case .userCancelled:
            // No action needed
            break
        case .pending:
            errorMessage = "Purchase is pending approval"
            showingPurchaseError = true
        case .failed(let error):
            errorMessage = error.localizedDescription
            showingPurchaseError = true
        case .unknown:
            errorMessage = "Unknown purchase result"
            showingPurchaseError = true
        }
        
        isPurchasing = false
    }
    
    func restorePurchases() async {
        isRestoring = true
        
        let result = await storeKitService.restorePurchases()
        
        switch result {
        case .success:
            showingPurchaseSuccess = true
        case .nothingToRestore:
            errorMessage = "No previous purchases found"
            showingPurchaseError = true
        case .failed(let error):
            errorMessage = error.localizedDescription
            showingPurchaseError = true
        }
        
        isRestoring = false
    }
}

