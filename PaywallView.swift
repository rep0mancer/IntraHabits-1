import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @StateObject private var storeKitService = StoreKitService.shared
    @StateObject private var purchaseManager = PurchaseManager()
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Header
                        headerSection
                        
                        // Features List
                        featuresSection
                        
                        // Pricing
                        pricingSection
                        
                        // Purchase Button
                        purchaseButton
                        
                        // Restore Button
                        restoreButton
                        
                        // Terms and Privacy
                        legalSection
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
            }
            .navigationTitle("paywall.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await storeKitService.loadProducts()
            }
        }
        .alert("paywall.purchase.success.title", isPresented: $purchaseManager.showingPurchaseSuccess) {
            Button("common.ok") {
                dismiss()
            }
        } message: {
            Text("paywall.purchase.success.message")
        }
        .alert("paywall.purchase.error.title", isPresented: $purchaseManager.showingPurchaseError) {
            Button("common.ok") {
                purchaseManager.errorMessage = nil
            }
        } message: {
            if let errorMessage = purchaseManager.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // App Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.primary)
            
            Text("paywall.headline")
                .font(DesignSystem.Typography.title1)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text("paywall.subheadline")
                .font(DesignSystem.Typography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Features Section
    private var featuresSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ForEach(PaywallFeature.allFeatures, id: \.id) { feature in
                FeatureRowView(feature: feature)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.secondaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.large)
    }
    
    // MARK: - Pricing Section
    private var pricingSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            if let product = storeKitService.unlimitedActivitiesProduct {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text(product.displayName)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                    
                    Text(product.displayPrice)
                        .font(DesignSystem.Typography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.primary)
                    
                    Text("paywall.one_time_purchase")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("Unlimited Activities")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                    
                    if storeKitService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("$4.99")
                            .font(DesignSystem.Typography.title2)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.primary)
                        
                        Text("paywall.one_time_purchase")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.primary.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .stroke(DesignSystem.Colors.primary, lineWidth: 2)
        )
    }
    
    // MARK: - Purchase Button
    private var purchaseButton: some View {
        Button(action: {
            Task {
                await purchaseManager.purchaseUnlimitedActivities()
            }
        }) {
            HStack {
                if purchaseManager.isPurchasing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("paywall.purchase_button")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(storeKitService.isLoading || purchaseManager.isPurchasing || storeKitService.unlimitedActivitiesProduct == nil)
    }
    
    // MARK: - Restore Button
    private var restoreButton: some View {
        Button(action: {
            Task {
                await purchaseManager.restorePurchases()
            }
        }) {
            HStack {
                if purchaseManager.isRestoring {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("paywall.restore_purchases")
                }
            }
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(purchaseManager.isRestoring)
    }
    
    // MARK: - Legal Section
    private var legalSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.lg) {
                Button("paywall.terms_of_service") {
                    if let url = URL(string: "https://example.com/terms") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(DesignSystem.Colors.primary)

                Button("paywall.privacy_policy") {
                    if let url = URL(string: "https://example.com/privacy") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(DesignSystem.Colors.primary)
            }
            
            Text("paywall.legal_disclaimer")
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Feature Row View
struct FeatureRowView: View {
    let feature: PaywallFeature
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: feature.iconName)
                .font(.title2)
                .foregroundColor(DesignSystem.Colors.primary)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.primary)
                
                Text(feature.description)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Paywall Feature
struct PaywallFeature {
    let id = UUID()
    let iconName: String
    let title: String
    let description: String
    
    static let allFeatures = [
        PaywallFeature(
            iconName: "infinity",
            title: NSLocalizedString("paywall.feature.unlimited.title", comment: ""),
            description: NSLocalizedString("paywall.feature.unlimited.description", comment: "")
        ),
        PaywallFeature(
            iconName: "icloud.fill",
            title: NSLocalizedString("paywall.feature.sync.title", comment: ""),
            description: NSLocalizedString("paywall.feature.sync.description", comment: "")
        ),
        PaywallFeature(
            iconName: "square.and.arrow.up",
            title: NSLocalizedString("paywall.feature.export.title", comment: ""),
            description: NSLocalizedString("paywall.feature.export.description", comment: "")
        ),
        PaywallFeature(
            iconName: "heart.fill",
            title: NSLocalizedString("paywall.feature.support.title", comment: ""),
            description: NSLocalizedString("paywall.feature.support.description", comment: "")
        )
    ]
}

// MARK: - Paywall Trigger View
struct PaywallTriggerView: View {
    @StateObject private var storeKitService = StoreKitService.shared
    @State private var showingPaywall = false
    
    let currentActivityCount: Int
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Icon
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.primary)
            
            // Title
            Text("paywall.limit.title")
                .font(DesignSystem.Typography.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            // Subtitle
            Text("paywall.limit.subtitle")
                .font(DesignSystem.Typography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Buttons
            VStack(spacing: DesignSystem.Spacing.md) {
                Button("paywall.upgrade_now") {
                    showingPaywall = true
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button("paywall.maybe_later") {
                    onDismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .background(DesignSystem.Colors.secondaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.large)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
                .onDisappear {
                    if storeKitService.hasUnlimitedActivities {
                        onDismiss()
                    }
                }
        }
    }
}

// MARK: - Preview
struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PaywallView()
                .environmentObject(NavigationCoordinator())
                .preferredColorScheme(.dark)
            
            PaywallTriggerView(currentActivityCount: 5) {
                // Dismiss action
            }
            .padding()
            .background(DesignSystem.Colors.background)
            .preferredColorScheme(.dark)
        }
    }
}

