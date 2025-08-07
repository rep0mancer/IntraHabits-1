import XCTest
import CoreData
@testable import IntraHabits

final class WidgetDataServiceTests: XCTestCase {
    var service: WidgetDataService?
    var persistence: PersistenceController?
    var context: NSManagedObjectContext?

    override func setUpWithError() throws {
        let persist = PersistenceController(inMemory: true)
        persistence = persist
        service = WidgetDataService.shared
        service?.persistentContainer = persist.container
        context = persist.container.viewContext
    }

    override func tearDownWithError() throws {
        service = nil
        context = nil
        persistence = nil
    }

    private func createActivity(name: String, type: ActivityType, color: String, active: Bool = true) -> Activity {
        guard let context = context else {
            XCTFail("Missing context")
            return Activity()
        }
        let activity = Activity(context: context)
        activity.id = UUID()
        activity.name = name
        activity.type = type.rawValue
        activity.color = color
        activity.createdAt = Date()
        activity.isActive = active
        activity.sortOrder = 0
        return activity
    }

    func testGetAllActivitiesReturnsActiveOnly() async throws {
        guard let service = service, let context = context else { return }
        let active = createActivity(name: "Active", type: .numeric, color: "#CD3A2E")
        let inactive = createActivity(name: "Inactive", type: .numeric, color: "#CD3A2E", active: false)
        try context.save()

        let activities = try await service.getAllActivities()
        XCTAssertEqual(activities.count, 1)
        XCTAssertEqual(activities.first?.id, active.id?.uuidString)
        XCTAssertFalse(activities.contains { $0.id == inactive.id?.uuidString })
    }

    func testCreateSessionAndFetchTodaysSessions() async throws {
        guard let service = service, let context = context else { return }
        let activity = createActivity(name: "Test", type: .numeric, color: "#CD3A2E")
        try context.save()

        if let id = activity.id?.uuidString {
            try await service.createSession(activityId: id, numericValue: 3, duration: nil)
            let sessions = try await service.getTodaysSessions(for: id)

            XCTAssertEqual(sessions.count, 1)
            XCTAssertEqual(sessions.first?.numericValue, 3)
        } else {
            XCTFail("Missing activity ID")
        }
    }

    func testGetTodaysProgressCalculatesTotals() async throws {
        guard let service = service, let context = context else { return }
        let activity = createActivity(name: "Progress", type: .numeric, color: "#CD3A2E")
        try context.save()

        if let id = activity.id?.uuidString {
            try await service.createSession(activityId: id, numericValue: 2, duration: nil)
            try await service.createSession(activityId: id, numericValue: 3, duration: nil)
        } else {
            XCTFail("Missing activity ID")
            return
        }

        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return }
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

