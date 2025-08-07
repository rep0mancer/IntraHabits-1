import XCTest
@testable import IntraHabits

final class WidgetTimerServiceTests: XCTestCase {
    func testSchedulesAndCancelsRepeatingUpdateTimer() async throws {
        let service = WidgetTimerService.shared
        let activityId = UUID().uuidString
        
        // Ensure clean state
        _ = try? await service.stopTimer(for: activityId)
        
        // Start timer and expect update timer to be scheduled
        try await service.startTimer(for: activityId)
        XCTAssertTrue(service.hasScheduledUpdateTimer(for: activityId))
        
        // Pause should cancel the update timer
        try await service.pauseTimer(for: activityId)
        // Give the run loop a moment to process invalidation
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        XCTAssertFalse(service.hasScheduledUpdateTimer(for: activityId))
        
        // Resume should reschedule
        try await service.resumeTimer(for: activityId)
        XCTAssertTrue(service.hasScheduledUpdateTimer(for: activityId))
        
        // Stop should cancel again
        _ = try await service.stopTimer(for: activityId)
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        XCTAssertFalse(service.hasScheduledUpdateTimer(for: activityId))
    }
}