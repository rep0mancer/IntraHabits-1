import XCTest
import CoreData
@testable import IntraHabits

final class WidgetDataServiceTests: XCTestCase {
    var service: WidgetDataService!
    var persistence: PersistenceController!
    var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        persistence = PersistenceController(inMemory: true)
        service = WidgetDataService.shared
        service.persistentContainer = persistence.container
        context = persistence.container.viewContext
    }

    override func tearDownWithError() throws {
        service = nil
        context = nil
        persistence = nil
    }

    private func createActivity(name: String, type: ActivityType, color: String, active: Bool = true) -> Activity {
        let activity = Activity(context: context)
        activity.id = UUID()
        activity.name = name
        activity.type = type.rawValue
        activity.color = color
        activity.createdAt = Date()
        activity.isActive = active
        return activity
    }

    func testGetAllActivitiesReturnsActiveOnly() async throws {
        let active = createActivity(name: "Active", type: .numeric, color: "#CD3A2E")
        let inactive = createActivity(name: "Inactive", type: .numeric, color: "#CD3A2E", active: false)
        try context.save()

        let activities = try await service.getAllActivities()
        XCTAssertEqual(activities.count, 1)
        XCTAssertEqual(activities.first?.id, active.id?.uuidString)
        XCTAssertFalse(activities.contains { $0.id == inactive.id?.uuidString })
    }

    func testCreateSessionAndFetchTodaysSessions() async throws {
        let activity = createActivity(name: "Test", type: .numeric, color: "#CD3A2E")
        try context.save()

        try await service.createSession(activityId: activity.id!.uuidString, numericValue: 3, duration: nil)
        let sessions = try await service.getTodaysSessions(for: activity.id!.uuidString)

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.numericValue, 3)
    }

    func testGetTodaysProgressCalculatesTotals() async throws {
        let activity = createActivity(name: "Progress", type: .numeric, color: "#CD3A2E")
        try context.save()

        try await service.createSession(activityId: activity.id!.uuidString, numericValue: 2, duration: nil)
        try await service.createSession(activityId: activity.id!.uuidString, numericValue: 3, duration: nil)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let oldSession = ActivitySession(context: context)
        oldSession.id = UUID()
        oldSession.activity = activity
        oldSession.sessionDate = yesterday
        oldSession.numericValue = 5
        oldSession.isCompleted = true
        oldSession.createdAt = yesterday
        try context.save()

        let progress = try await service.getTodaysProgress()
        XCTAssertEqual(progress.count, 1)
        let item = progress[0]
        XCTAssertEqual(item.todaysSessions, 2)
        XCTAssertEqual(item.todaysNumericTotal, 5)
        XCTAssertEqual(item.progressPercentage, 1.0, accuracy: 0.001)
    }
}

