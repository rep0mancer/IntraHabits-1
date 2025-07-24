import SwiftUI
import CoreData

struct CalendarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = CalendarViewModel()
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Activity.sortOrder, ascending: true)],
        predicate: NSPredicate(format: "isActive == %@", NSNumber(value: true)),
        animation: .default
    )
    private var activities: FetchedResults<Activity>
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Calendar Header
                calendarHeader
                
                // Calendar Grid
                calendarGrid
                
                // Selected Date Details
                selectedDateDetails
                
                Spacer()
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("calendar.title")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("calendar.today") {
                        withAnimation {
                            selectedDate = Date()
                            currentMonth = Date()
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.setContext(viewContext)
            viewModel.loadSessionsForMonth(currentMonth)
        }
        .onChange(of: currentMonth) { newMonth in
            viewModel.loadSessionsForMonth(newMonth)
        }
    }
    
    // MARK: - Calendar Header
    private var calendarHeader: some View {
        HStack {
            Button(action: { changeMonth(-1) }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.primary)
            }
            
            Spacer()
            
            Text(monthYearFormatter.string(from: currentMonth))
                .font(DesignSystem.Typography.title2)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: { changeMonth(1) }) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.primary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
    
    // MARK: - Calendar Grid
    private var calendarGrid: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            // Weekday Headers
            HStack {
                ForEach(weekdaySymbols, id: \.self) { weekday in
                    Text(weekday)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            
            // Calendar Days
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: DesignSystem.Spacing.xs) {
                ForEach(calendarDays, id: \.self) { date in
                    CalendarDayView(
                        date: date,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                        isCurrentMonth: Calendar.current.isDate(date, equalTo: currentMonth, toGranularity: .month),
                        isToday: Calendar.current.isDateInToday(date),
                        sessionsCount: viewModel.sessionsCount(for: date),
                        hasActivity: viewModel.hasActivity(for: date)
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDate = date
                        }
                        viewModel.loadSessionsForDate(date)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
        .cardStyle()
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
    
    // MARK: - Selected Date Details
    private var selectedDateDetails: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text(dateFormatter.string(from: selectedDate))
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !viewModel.selectedDateSessions.isEmpty {
                    Text("\(viewModel.selectedDateSessions.count) sessions")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            if viewModel.selectedDateSessions.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.minus",
                    title: "calendar.no_sessions.title",
                    subtitle: "calendar.no_sessions.subtitle"
                )
                .frame(height: 120)
            } else {
                LazyVStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(viewModel.selectedDateSessions, id: \.id) { session in
                        CalendarSessionRowView(session: session)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle()
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.top, DesignSystem.Spacing.md)
    }
    
    // MARK: - Computed Properties
    private var calendarDays: [Date] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
        let range = calendar.range(of: .day, in: .month, for: currentMonth) ?? 1..<32
        
        var days: [Date] = []
        
        // Add days from previous month to fill the first week
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let daysFromPreviousMonth = (firstWeekday - calendar.firstWeekday + 7) % 7
        
        for i in (1...daysFromPreviousMonth).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: startOfMonth) {
                days.append(date)
            }
        }
        
        // Add days of current month
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        
        // Add days from next month to fill the last week
        let totalCells = 42 // 6 weeks * 7 days
        let remainingCells = totalCells - days.count
        let lastDayOfMonth = days.last ?? currentMonth
        
        for i in 1...remainingCells {
            if let date = calendar.date(byAdding: .day, value: i, to: lastDayOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        return formatter.shortWeekdaySymbols
    }
    
    private var monthYearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }
    
    // MARK: - Actions
    private func changeMonth(_ direction: Int) {
        withAnimation {
            if let newMonth = Calendar.current.date(byAdding: .month, value: direction, to: currentMonth) {
                currentMonth = newMonth
            }
        }
    }
}

// MARK: - Calendar Day View
struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let isCurrentMonth: Bool
    let isToday: Bool
    let sessionsCount: Int
    let hasActivity: Bool
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text(dayNumber)
                .font(DesignSystem.Typography.subheadline)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundColor(textColor)
            
            // Activity indicator
            if hasActivity {
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 6, height: 6)
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 40, height: 40)
        .background(backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: isSelected ? 2 : 0)
        )
    }
    
    private var textColor: Color {
        if !isCurrentMonth {
            return .secondary.opacity(0.5)
        } else if isSelected {
            return .white
        } else if isToday {
            return DesignSystem.Colors.primary
        } else {
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return DesignSystem.Colors.primary
        } else if isToday {
            return DesignSystem.Colors.primary.opacity(0.1)
        } else {
            return Color.clear
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return DesignSystem.Colors.primary
        } else {
            return Color.clear
        }
    }
    
    private var indicatorColor: Color {
        if isSelected {
            return .white
        } else if hasActivity {
            return DesignSystem.Colors.primary
        } else {
            return Color.clear
        }
    }
}

// MARK: - Calendar Session Row View
struct CalendarSessionRowView: View {
    let session: ActivitySession
    
    var body: some View {
        HStack {
            // Activity color indicator
            Circle()
                .fill(session.activity?.displayColor ?? DesignSystem.Colors.primary)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(session.activity?.displayName ?? "Unknown Activity")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.primary)
                
                Text(session.displayValue)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(timeFormatter.string(from: session.sessionDate ?? Date()))
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Calendar View Model
class CalendarViewModel: ObservableObject {
    @Published var selectedDateSessions: [ActivitySession] = []
    @Published var monthSessions: [ActivitySession] = []
    
    private var viewContext: NSManagedObjectContext?
    private var cancellables = Set<AnyCancellable>()
    
    func setContext(_ context: NSManagedObjectContext) {
        self.viewContext = context
        
        // Listen for changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshData()
                }
            }
            .store(in: &cancellables)
    }
    
    func loadSessionsForMonth(_ month: Date) {
        guard let context = viewContext else { return }
        
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: month)?.start ?? month
        let endOfMonth = calendar.dateInterval(of: .month, for: month)?.end ?? month
        
        let request: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
        request.predicate = NSPredicate(format: "sessionDate >= %@ AND sessionDate < %@", 
                                      startOfMonth as NSDate, endOfMonth as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ActivitySession.sessionDate, ascending: false)]
        
        do {
            monthSessions = try context.fetch(request)
        } catch {
            AppLogger.error("Error loading month sessions: \(error)")
            monthSessions = []
        }
    }
    
    func loadSessionsForDate(_ date: Date) {
        guard let context = viewContext else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
        request.predicate = NSPredicate(format: "sessionDate >= %@ AND sessionDate < %@", 
                                      startOfDay as NSDate, endOfDay as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ActivitySession.sessionDate, ascending: false)]
        
        do {
            selectedDateSessions = try context.fetch(request)
        } catch {
            AppLogger.error("Error loading date sessions: \(error)")
            selectedDateSessions = []
        }
    }
    
    func sessionsCount(for date: Date) -> Int {
        let calendar = Calendar.current
        return monthSessions.filter { session in
            guard let sessionDate = session.sessionDate else { return false }
            return calendar.isDate(sessionDate, inSameDayAs: date)
        }.count
    }
    
    func hasActivity(for date: Date) -> Bool {
        return sessionsCount(for: date) > 0
    }
    
    private func refreshData() {
        // Refresh current data
        if let lastSelectedDate = selectedDateSessions.first?.sessionDate {
            loadSessionsForDate(lastSelectedDate)
        }
    }
}

// MARK: - Preview
struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(NavigationCoordinator())
            .preferredColorScheme(.dark)
    }
}

