import XCTest
import CoreData
@testable import IntraHabits

final class DataServiceTests: XCTestCase {
    var dataService: CoreDataService!
    var mockPersistenceController: PersistenceController!
    
    override func setUpWithError() throws {
        // Create in-memory Core Data stack for testing
        mockPersistenceController = PersistenceController(inMemory: true)
        dataService = CoreDataService(container: mockPersistenceController.container)
    }
    
    override func tearDownWithError() throws {
        dataService = nil
        mockPersistenceController = nil
    }
    
    // MARK: - Activity Tests
    
    func testCreateActivity() async throws {
        // Given
        let activityName = "Test Activity"
        let activityType = ActivityType.numeric
        let activityColor = "#CD3A2E"
        
        // When
        let activity = try await dataService.createActivity(
            name: activityName,
            type: activityType,
            color: activityColor
        )
        
        // Then
        XCTAssertNotNil(activity)
        XCTAssertEqual(activity.name, activityName)
        XCTAssertEqual(activity.type, activityType.rawValue)
        XCTAssertEqual(activity.color, activityColor)
        XCTAssertTrue(activity.isActive)
        XCTAssertNotNil(activity.id)
        XCTAssertNotNil(activity.createdAt)
    }
    
    func testCreateActivityWithInvalidName() async {
        // Given
        let emptyName = ""
        
        // When/Then
        do {
            _ = try await dataService.createActivity(
                name: emptyName,
                type: .numeric,
                color: "#CD3A2E"
            )
            XCTFail("Should have thrown validation error")
        } catch DataServiceError.validationError(let message) {
            XCTAssertEqual(message, "Activity name cannot be empty")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testFetchActivities() async throws {
        // Given
        let activity1 = try await dataService.createActivity(
            name: "Activity 1",
            type: .numeric,
            color: "#CD3A2E"
        )
        let activity2 = try await dataService.createActivity(
            name: "Activity 2",
            type: .timer,
            color: "#008C8C"
        )
        
        // When
        let activities = try await dataService.fetchActivities()
        
        // Then
        XCTAssertEqual(activities.count, 2)
        XCTAssertTrue(activities.contains(activity1))
        XCTAssertTrue(activities.contains(activity2))
    }
    
    func testUpdateActivity() async throws {
        // Given
        var activity = try await dataService.createActivity(
            name: "Original Name",
            type: .numeric,
            color: "#CD3A2E"
        )

        // When
        activity.name = "Updated Name"
        activity.type = ActivityType.timer.rawValue
        activity.color = "#008C8C"
        let updatedActivity = try await dataService.updateActivity(activity)
        
        // Then
        XCTAssertEqual(updatedActivity.name, "Updated Name")
        XCTAssertEqual(updatedActivity.type, ActivityType.timer.rawValue)
        XCTAssertEqual(updatedActivity.color, "#008C8C")
        XCTAssertNotNil(updatedActivity.updatedAt)
    }
    
    func testDeleteActivity() async throws {
        // Given
        let activity = try await dataService.createActivity(
            name: "Test Activity",
            type: .numeric,
            color: "#CD3A2E"
        )
        
        // When
        try await dataService.deleteActivity(activity)
        
        // Then
        let activities = try await dataService.fetchActivities()
        XCTAssertFalse(activities.contains(activity))
    }
    
    // MARK: - Session Tests
    
    func testCreateNumericSession() async throws {
        // Given
        let activity = try await dataService.createActivity(
            name: "Test Activity",
            type: .numeric,
            color: "#CD3A2E"
        )
        let numericValue = 5.0
        
        // When
        let session = try await dataService.createSession(
            for: activity,
            duration: nil,
            numericValue: numericValue
        )
        
        // Then
        XCTAssertNotNil(session)
        XCTAssertEqual(session.activity, activity)
        XCTAssertEqual(session.numericValue, numericValue)
        XCTAssertNil(session.duration)
        XCTAssertTrue(session.isCompleted)
        XCTAssertNotNil(session.id)
        XCTAssertNotNil(session.createdAt)
    }
    
    func testCreateTimerSession() async throws {
        // Given
        let activity = try await dataService.createActivity(
            name: "Test Activity",
            type: .timer,
            color: "#CD3A2E"
        )
        let duration = 300.0 // 5 minutes
        // When
        let session = try await dataService.createSession(
            for: activity,
            duration: duration,
            numericValue: nil
        )
        
        // Then
        XCTAssertNotNil(session)
        XCTAssertEqual(session.activity, activity)
        XCTAssertEqual(session.duration, duration)
        XCTAssertNil(session.numericValue)
        XCTAssertTrue(session.isCompleted)
    }
    
    func testFetchSessionsForActivity() async throws {
        // Given
        let activity = try await dataService.createActivity(
            name: "Test Activity",
            type: .numeric,
            color: "#CD3A2E"
        )
        
        let session1 = try await dataService.createSession(
            for: activity,
            duration: nil,
            numericValue: 1.0
        )
        let session2 = try await dataService.createSession(
            for: activity,
            duration: nil,
            numericValue: 2.0
        )
        
        // When
        let sessions = try await dataService.fetchSessions(for: activity)
        
        // Then
        XCTAssertEqual(sessions.count, 2)
        XCTAssertTrue(sessions.contains(session1))
        XCTAssertTrue(sessions.contains(session2))
    }
    
    func testDeleteSession() async throws {
        // Given
        let activity = try await dataService.createActivity(
            name: "Test Activity",
            type: .numeric,
            color: "#CD3A2E"
        )
        let session = try await dataService.createSession(
            for: activity,
            duration: nil,
            numericValue: 1.0
        )
        
        // When
        try await dataService.deleteSession(session)
        
        // Then
        let sessions = try await dataService.fetchSessions(for: activity)
        XCTAssertFalse(sessions.contains(session))
    }
    
    // MARK: - Statistics Tests
    
    func testActivityStatistics() async throws {
        // Given
        let activity = try await dataService.createActivity(
            name: "Test Activity",
            type: .numeric,
            color: "#CD3A2E"
        )
        
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        var s1 = try await dataService.createSession(
            for: activity,
            duration: nil,
            numericValue: 5.0
        )
        s1.sessionDate = today
        _ = try await dataService.updateSession(s1)

        var s2 = try await dataService.createSession(
            for: activity,
            duration: nil,
            numericValue: 3.0
        )
        s2.sessionDate = yesterday
        _ = try await dataService.updateSession(s2)
        
        // When
        let todayTotal = try await dataService.getTodayTotal(for: activity)
        let weeklyTotal = try await dataService.getWeeklyTotal(for: activity)
        
        // Then
        XCTAssertEqual(todayTotal, 5.0)
        XCTAssertEqual(weeklyTotal, 8.0)
    }
    
    func testCurrentStreak() async throws {
        // Given
        let activity = try await dataService.createActivity(
            name: "Test Activity",
            type: .numeric,
            color: "#CD3A2E"
        )
        
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
        
        var sToday = try await dataService.createSession(
            for: activity,
            duration: nil,
            numericValue: 1.0
        )
        sToday.sessionDate = today
        _ = try await dataService.updateSession(sToday)

        var sYesterday = try await dataService.createSession(
            for: activity,
            duration: nil,
            numericValue: 1.0
        )
        sYesterday.sessionDate = yesterday
        _ = try await dataService.updateSession(sYesterday)

        var sTwoDaysAgo = try await dataService.createSession(
            for: activity,
            duration: nil,
            numericValue: 1.0
        )
        sTwoDaysAgo.sessionDate = twoDaysAgo
        _ = try await dataService.updateSession(sTwoDaysAgo)
        
        // When
        let currentStreak = try await dataService.getCurrentStreak(for: activity)
        
        // Then
        XCTAssertEqual(currentStreak, 3)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceCreateManyActivities() throws {
        measure {
            let expectation = XCTestExpectation(description: "Create activities")
            
            Task {
                do {
                    for i in 0..<100 {
                        _ = try await dataService.createActivity(
                            name: "Activity \(i)",
                            type: .numeric,
                            color: "#CD3A2E"
                        )
                    }
                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to create activities: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testPerformanceFetchActivities() async throws {
        // Given - Create some activities first
        for i in 0..<50 {
            _ = try await dataService.createActivity(
                name: "Activity \(i)",
                type: .numeric,
                color: "#CD3A2E"
            )
        }
        
        // When/Then
        measure {
            let expectation = XCTestExpectation(description: "Fetch activities")
            
            Task {
                do {
                    _ = try await dataService.fetchActivities()
                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to fetch activities: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 2.0)
        }
    }
}

