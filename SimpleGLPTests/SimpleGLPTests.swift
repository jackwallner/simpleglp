import XCTest
@testable import SimpleGLP

final class SimpleGLPTests: XCTestCase {
    func testScheduleEngineMatchOnSchedule() {
        let plan = MedicationPlan(
            scheduleStartDate: Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!,
            preferredWeekday: 5,
            preferredHour: 9,
            preferredMinute: 0
        )
        let match = ScheduleEngine.match(
            timestamp: Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 8, hour: 9))!,
            plan: plan
        )
        XCTAssertEqual(match.status, .onSchedule)
    }

    func testScheduleEngineMatchEarly() {
        let plan = MedicationPlan(
            scheduleStartDate: Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!,
            preferredWeekday: 5,
            preferredHour: 9,
            preferredMinute: 0
        )
        let match = ScheduleEngine.match(
            timestamp: Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 7, hour: 9))!,
            plan: plan
        )
        XCTAssertEqual(match.status, .early)
    }

    func testCaptureStatusTransitions() {
        let event = ShotEvent()
        XCTAssertEqual(event.captureStatus, .pending)
        event.finalizeCapture()
        XCTAssertTrue(event.captureStatus == .partial || event.captureStatus == .complete)
    }
}
