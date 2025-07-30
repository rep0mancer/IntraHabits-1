import SwiftUI
import CoreData

struct AddActivityView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AddActivityViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Form Content
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            nameSection
                            typeSection
                            colorSection
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.top, DesignSystem.Spacing.lg)
                    }
                    
                    // Bottom Button
                    bottomButton
                }
            }
            .navigationTitle("activity.add.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            viewModel.setContext(viewContext)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Name Section
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("activity.add.name.title")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(.primary)
            
            TextField("activity.add.name.placeholder", text: $viewModel.activityName)
                .font(DesignSystem.Typography.body)
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.tertiaryBackground)
                .cornerRadius(DesignSystem.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .stroke(DesignSystem.Colors.systemGray4, lineWidth: 1)
                )
                .submitLabel(.done)
        }
    }
    
    // MARK: - Type Section
    private var typeSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("activity.add.type.title")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: DesignSystem.Spacing.md) {
                // Numeric Type Button
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedType = .numeric
                    }
                }) {
                    Text("activity.type.numeric")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(viewModel.selectedType == .numeric ? .white : DesignSystem.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            viewModel.selectedType == .numeric ? 
                            DesignSystem.Colors.primary : 
                            DesignSystem.Colors.primary.opacity(0.1)
                        )
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                }
                .hapticFeedback(.light)
                
                // Timer Type Button
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedType = .timer
                    }
                }) {
                    Text("activity.type.timer")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(viewModel.selectedType == .timer ? .white : DesignSystem.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            viewModel.selectedType == .timer ? 
                            DesignSystem.Colors.primary : 
                            DesignSystem.Colors.primary.opacity(0.1)
                        )
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                }
                .hapticFeedback(.light)
            }
        }
    }
    
    // MARK: - Color Section
    private var colorSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("activity.add.color.title")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.sm), count: 4), spacing: DesignSystem.Spacing.sm) {
                ForEach(DesignSystem.Colors.activityColors, id: \.self) { colorHex in
                    ColorPickerButton(
                        color: Color(hex: colorHex),
                        isSelected: viewModel.selectedColor == colorHex
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedColor = colorHex
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Bottom Button
    private var bottomButton: some View {
        VStack(spacing: 0) {
            Divider()
                .background(DesignSystem.Colors.systemGray5)
            
            Button(action: {
                HapticManager.impact(.medium)
                Task {
                    let success = await viewModel.createActivity()
                    if success {
                        HapticManager.notification(.success)
                        dismiss()
                    } else if viewModel.shouldShowPaywall {
                        coordinator.presentPaywall()
                    }
                }
            }) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("activity.add.create")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!viewModel.isFormValid || viewModel.isLoading)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Color Picker Button
struct ColorPickerButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(color)
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .stroke(
                            isSelected ? Color.white : Color.clear,
                            lineWidth: isSelected ? 3 : 0
                        )
                )
                .overlay(
                    isSelected ? 
                    Image(systemName: "checkmark")
                        .font(.title2)
                        .foregroundColor(.white)
                        .fontWeight(.bold) : 
                    nil
                )
                .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .hapticFeedback(.light)
    }
}

// MARK: - Enhanced Add Activity View Model
class AddActivityViewModel: ObservableObject {
    @Published var activityName = ""
    @Published var selectedType: ActivityType = .numeric
    @Published var selectedColor = DesignSystem.Colors.activityColors[0]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var shouldShowPaywall = false
    
    private var viewContext: NSManagedObjectContext?
    
    var isFormValid: Bool {
        !activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func setContext(_ context: NSManagedObjectContext) {
        self.viewContext = context
    }
    
    @MainActor
    func createActivity() async -> Bool {
        guard let context = viewContext, isFormValid else { return false }

        isLoading = true
        errorMessage = nil
        shouldShowPaywall = false

        // Create a temporary activity object for validation
        let tempActivity = Activity(context: context)
        tempActivity.name = activityName.trimmingCharacters(in: .whitespacesAndNewlines)
        tempActivity.color = selectedColor
        tempActivity.type = selectedType.rawValue

        let validation = tempActivity.validate()
        if !validation.isValid {
            self.errorMessage = validation.errors.first
            self.isLoading = false
            context.rollback()
            return false
        }
        
        // Check activity limit for paywall
        let request: NSFetchRequest<Activity> = Activity.fetchRequest()
        request.predicate = NSPredicate(format: "%K == %@", #keyPath(Activity.isActive), NSNumber(value: true))
        
        do {
            let existingActivities = try context.fetch(request)

            // Check if user has unlocked unlimited activities
            let hasUnlimitedActivities = AppDependencies.shared.storeService.hasUnlimitedActivities
            
            if existingActivities.count >= 5 && !hasUnlimitedActivities {
                shouldShowPaywall = true
                isLoading = false
                return false
            }
            
            let activity = Activity(context: context)
            activity.id = UUID()
            activity.name = activityName.trimmingCharacters(in: .whitespacesAndNewlines)
            activity.type = selectedType.rawValue
            activity.color = selectedColor
            activity.createdAt = Date()
            activity.updatedAt = Date()
            activity.isActive = true
            activity.sortOrder = Int32(existingActivities.count)
            
            try context.save()
            
            
            isLoading = false
            return true
            
       } catch {
            DispatchQueue.main.async {
                AppDependencies.shared.errorHandler.handle(error)
            }
            isLoading = false
            return false
        }
    }
}

// MARK: - Preview
struct AddActivityView_Previews: PreviewProvider {
    static var previews: some View {
        AddActivityView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(NavigationCoordinator())
            .preferredColorScheme(.dark)
    }
}

