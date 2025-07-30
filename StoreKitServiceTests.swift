import XCTest
import StoreKit
@testable import IntraHabits

final class StoreKitServiceTests: XCTestCase {
    var storeKitService: StoreKitService!
    
    override func setUpWithError() throws {
        storeKitService = StoreKitService()
    }
    
    override func tearDownWithError() throws {
        storeKitService = nil
    }
    
    // MARK: - Activity Limit Tests
    
    func testCanAddMoreActivitiesWithoutPurchase() {
        // Given
        let currentCount = 3
        
        // When
        let canAdd = storeKitService.canAddMoreActivities(currentCount: currentCount)
        
        // Then
        XCTAssertTrue(canAdd, "Should be able to add more activities when under the free limit")
    }
    
    func testCannotAddMoreActivitiesAtFreeLimit() {
        // Given
        let currentCount = 5
        
        // When
        let canAdd = storeKitService.canAddMoreActivities(currentCount: currentCount)
        
        // Then
        XCTAssertFalse(canAdd, "Should not be able to add more activities at the free limit")
    }
    
    func testCanAddMoreActivitiesOverLimitWithPurchase() {
        // Given
        let currentCount = 10
        // Simulate having unlimited activities
        UserDefaults.standard.set(true, forKey: "hasUnlimitedActivities")
        storeKitService.purchasedProductIDs.insert("com.intrahabits.unlimited_activities")
        
        // When
        let canAdd = storeKitService.canAddMoreActivities(currentCount: currentCount)
        
        // Then
        XCTAssertTrue(canAdd, "Should be able to add more activities with unlimited purchase")
        
        // Cleanup
        UserDefaults.standard.removeObject(forKey: "hasUnlimitedActivities")
        storeKitService.purchasedProductIDs.removeAll()
    }
    
    func testShouldShowPaywallAtLimit() {
        // Given
        let currentCount = 5
        
        // When
        let shouldShow = storeKitService.shouldShowPaywall(currentCount: currentCount)
        
        // Then
        XCTAssertTrue(shouldShow, "Should show paywall when at the free limit")
    }
    
    func testShouldNotShowPaywallUnderLimit() {
        // Given
        let currentCount = 3
        
        // When
        let shouldShow = storeKitService.shouldShowPaywall(currentCount: currentCount)
        
        // Then
        XCTAssertFalse(shouldShow, "Should not show paywall when under the free limit")
    }
    
    func testShouldNotShowPaywallWithPurchase() {
        // Given
        let currentCount = 10
        // Simulate having unlimited activities
        storeKitService.purchasedProductIDs.insert("com.intrahabits.unlimited_activities")
        
        // When
        let shouldShow = storeKitService.shouldShowPaywall(currentCount: currentCount)
        
        // Then
        XCTAssertFalse(shouldShow, "Should not show paywall with unlimited purchase")
        
        // Cleanup
        storeKitService.purchasedProductIDs.removeAll()
    }
    
    // MARK: - Purchase Status Tests
    
    func testHasUnlimitedActivitiesWithoutPurchase() {
        // Given
        storeKitService.purchasedProductIDs.removeAll()
        
        // When
        let hasUnlimited = storeKitService.hasUnlimitedActivities
        
        // Then
        XCTAssertFalse(hasUnlimited, "Should not have unlimited activities without purchase")
    }
    
    func testHasUnlimitedActivitiesWithPurchase() {
        // Given
        storeKitService.purchasedProductIDs.insert("com.intrahabits.unlimited_activities")
        
        // When
        let hasUnlimited = storeKitService.hasUnlimitedActivities
        
        // Then
        XCTAssertTrue(hasUnlimited, "Should have unlimited activities with purchase")
        
        // Cleanup
        storeKitService.purchasedProductIDs.removeAll()
    }
    
    // MARK: - Product Loading Tests
    
    func testLoadProducts() async {
        // Given
        let expectation = XCTestExpectation(description: "Load products")
        
        // When
        await storeKitService.loadProducts()
        
        // Then
        DispatchQueue.main.async {
            // In a real test environment with StoreKit testing, we would check for products
            // For now, we just verify the loading state is handled correctly
            XCTAssertFalse(self.storeKitService.isLoading, "Should not be loading after completion")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testPurchaseWithTestSession() async throws {
        let session = try SKTestSession(configurationFileNamed: "Products.storekit")
        session.disableDialogs = true
        session.clearTransactions()

        await storeKitService.loadProducts()
        guard let product = storeKitService.unlimitedActivitiesProduct else {
            XCTFail("Product not available")
            return
        }
        _ = await storeKitService.purchase(product)
    }
    
    // MARK: - Error Handling Tests
    
    func testStoreKitErrorDescriptions() {
        // Test error descriptions
        let verificationError = StoreKitError.failedVerification
        let productNotFoundError = StoreKitError.productNotFound
        let purchaseNotAllowedError = StoreKitError.purchaseNotAllowed
        
        XCTAssertNotNil(verificationError.errorDescription)
        XCTAssertNotNil(productNotFoundError.errorDescription)
        XCTAssertNotNil(purchaseNotAllowedError.errorDescription)
        
        XCTAssertEqual(verificationError.errorDescription, NSLocalizedString("storekit.error.verification_failed", comment: ""))
        XCTAssertEqual(productNotFoundError.errorDescription, NSLocalizedString("storekit.error.product_not_found", comment: ""))
        XCTAssertEqual(purchaseNotAllowedError.errorDescription, NSLocalizedString("storekit.error.purchase_not_allowed", comment: ""))
    }
    
    // MARK: - Purchase Manager Tests
    
    func testPurchaseManagerInitialState() {
        // Given
        let purchaseManager = PurchaseManager()
        
        // Then
        XCTAssertFalse(purchaseManager.isPurchasing)
        XCTAssertFalse(purchaseManager.isRestoring)
        XCTAssertFalse(purchaseManager.showingPurchaseSuccess)
        XCTAssertFalse(purchaseManager.showingPurchaseError)
        XCTAssertNil(purchaseManager.errorMessage)
    }
    
    // MARK: - Integration Tests
    
    func testActivityLimitWorkflow() {
        // Test the complete workflow of activity limits and paywall
        
        // Step 1: User can add activities under the limit
        for i in 1...4 {
            XCTAssertTrue(storeKitService.canAddMoreActivities(currentCount: i))
            XCTAssertFalse(storeKitService.shouldShowPaywall(currentCount: i))
        }
        
        // Step 2: User reaches the limit
        XCTAssertFalse(storeKitService.canAddMoreActivities(currentCount: 5))
        XCTAssertTrue(storeKitService.shouldShowPaywall(currentCount: 5))
        
        // Step 3: User purchases unlimited activities
        storeKitService.purchasedProductIDs.insert("com.intrahabits.unlimited_activities")
        
        // Step 4: User can now add unlimited activities
        XCTAssertTrue(storeKitService.canAddMoreActivities(currentCount: 10))
        XCTAssertFalse(storeKitService.shouldShowPaywall(currentCount: 10))
        
        // Cleanup
        storeKitService.purchasedProductIDs.removeAll()
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceActivityLimitCheck() {
        measure {
            for i in 0..<1000 {
                _ = storeKitService.canAddMoreActivities(currentCount: i % 10)
                _ = storeKitService.shouldShowPaywall(currentCount: i % 10)
            }
        }
    }
}

