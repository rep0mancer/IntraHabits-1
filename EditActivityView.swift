import SwiftUI
import CoreData

struct EditActivityView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var activity: Activity
    @StateObject private var viewModel: EditActivityViewModel

    init(activity: Activity) {
        self.activity = activity
        _viewModel = StateObject(wrappedValue: EditActivityViewModel(activity: activity, context: PersistenceController.shared.container.viewContext))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
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
            .navigationTitle("activity.edit.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Error", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
    }
    
    // MARK: - Name Section
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("activity.edit.name.title")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(.primary)
            
            TextField("activity.edit.name.placeholder", text: $viewModel.activityName)
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
            Text("activity.edit.type.title")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(.primary)
            
            Text("activity.edit.type.note")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(.secondary)
            
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
                .disabled(viewModel.hasExistingSessions)
                .opacity(viewModel.hasExistingSessions ? 0.5 : 1.0)
                
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
                .disabled(viewModel.hasExistingSessions)
                .opacity(viewModel.hasExistingSessions ? 0.5 : 1.0)
            }
        }
    }
    
    // MARK: - Color Section
    private var colorSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("activity.edit.color.title")
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
                Task {
                    let success = await viewModel.saveChanges()
                    if success {
                        dismiss()
                    }
                }
            }) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("activity.edit.save")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!viewModel.isFormValid || viewModel.isLoading || !viewModel.hasChanges)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Edit Activity View Model
@MainActor
class EditActivityViewModel: ObservableObject {
    @Published var activityName = ""
    @Published var selectedType: ActivityType = .numeric
    @Published var selectedColor = DesignSystem.Colors.activityColors[0]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasExistingSessions = false
    
    private var activity: Activity
    private let viewContext: NSManagedObjectContext
    private var originalName = ""
    private var originalType: ActivityType = .numeric
    private var originalColor = ""
    
    var isFormValid: Bool {
        !activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var hasChanges: Bool {
        let trimmedName = activityName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName != originalName || 
               selectedType != originalType || 
               selectedColor != originalColor
    }
    
    init(activity: Activity, context: NSManagedObjectContext) {
        self.activity = activity
        self.viewContext = context

        // Load current values
        activityName = activity.displayName
        selectedType = activity.activityType
        selectedColor = activity.color ?? DesignSystem.Colors.activityColors[0]

        // Store original values
        originalName = activity.displayName
        originalType = activity.activityType
        originalColor = activity.color ?? DesignSystem.Colors.activityColors[0]

        // Check if activity has existing sessions
        checkForExistingSessions()
    }
    
    private func checkForExistingSessions() {
        let context = viewContext
        let activity = activity
        
        let request = ActivitySession.sessionsForActivityFetchRequest(activity)
        request.fetchLimit = 1
        
        do {
            let sessions = try context.fetch(request)
            hasExistingSessions = !sessions.isEmpty
        } catch {
            AppLogger.error("Error checking for existing sessions: \(error)")
            hasExistingSessions = false
        }
    }
    
    @MainActor
    func saveChanges() async -> Bool {
        let context = viewContext
        let activity = activity
        guard isFormValid,
              hasChanges else { return false }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let tempActivity = Activity(context: context)
            tempActivity.name = activityName.trimmingCharacters(in: .whitespacesAndNewlines)
            tempActivity.color = selectedColor
            tempActivity.type = selectedType.rawValue

            let validation = tempActivity.validate()
            if !validation.isValid {
                errorMessage = validation.errors.first
                isLoading = false
                context.delete(tempActivity)
                return false
            }

            // Update activity properties
            activity.name = tempActivity.name
            activity.color = tempActivity.color
            activity.updatedAt = Date()

            // Only update type if no existing sessions
            if !hasExistingSessions {
                activity.type = tempActivity.type
            }
            
            try context.save()
            
            // Haptic feedback
            HapticManager.notification(.success)
            
            isLoading = false
            return true
            
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
}

// MARK: - Preview
struct EditActivityView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        let activity = Activity(context: context)
        activity.id = UUID()
        activity.name = "Exercise"
        activity.type = ActivityType.timer.rawValue
        activity.color = "#CD3A2E"
        activity.createdAt = Date()
        activity.isActive = true
        
        return EditActivityView(activity: activity)
            .environment(\.managedObjectContext, context)
            .preferredColorScheme(.dark)
    }
}

