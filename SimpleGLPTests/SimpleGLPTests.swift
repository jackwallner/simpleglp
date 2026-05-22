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

    func testScheduleEngineSecondShotInSameWeekIsExtra() {
        let plan = MedicationPlan(
            scheduleStartDate: Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!,
            preferredWeekday: 5,
            preferredHour: 9,
            preferredMinute: 0
        )
        let firstTimestamp = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 8, hour: 9))!
        let first = ScheduleEngine.match(timestamp: firstTimestamp, plan: plan)
        let existing = ShotEvent(
            timestamp: firstTimestamp,
            scheduledDate: first.scheduledDate,
            scheduleStatus: first.status,
            minutesFromSchedule: first.minutesFromSchedule
        )
        let second = ScheduleEngine.match(
            timestamp: Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 8, hour: 14))!,
            plan: plan,
            existingEvents: [existing]
        )
        XCTAssertEqual(second.status, .extra)
    }

    func testCaptureStatusTransitions() {
        let event = ShotEvent()
        XCTAssertEqual(event.captureStatus, .pending)
        event.finalizeCapture()
        XCTAssertTrue(event.captureStatus == .partial || event.captureStatus == .complete)
    }
}
