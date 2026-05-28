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

    func testScheduledDateOnOrBeforeReturnsNilWhenFirstDoseIsInFuture() {
        // Plan starts today at 10:18, preferred Sat 09:00 — first canonical
        // dose is next Saturday, so there is no scheduled occurrence on or
        // before "now" (today 10:30).
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 5, day: 23, hour: 10, minute: 18))!
        let now = cal.date(from: DateComponents(year: 2026, month: 5, day: 23, hour: 10, minute: 30))!
        let plan = MedicationPlan(
            scheduleStartDate: start,
            preferredWeekday: 7,
            preferredHour: 9,
            preferredMinute: 0
        )
        XCTAssertNil(ScheduleEngine.scheduledDate(onOrBefore: now, plan: plan, calendar: cal))
    }

    func testCSVEscapingQuotesFieldsWithSpecialCharacters() {
        XCTAssertEqual(ExportService.csvEscaped("simple"), "simple")
        XCTAssertEqual(ExportService.csvEscaped("a,b"), "\"a,b\"")
        XCTAssertEqual(ExportService.csvEscaped("say \"hi\""), "\"say \"\"hi\"\"\"")
        XCTAssertEqual(ExportService.csvEscaped("line1\nline2"), "\"line1\nline2\"")
    }

    func testCSVRoundTripPreservesCommasQuotesAndNewlines() {
        // A note containing a comma, quote, and newline must survive export → import.
        let note = "felt great, took it \"early\"\nslept well"
        let header = ExportService.header
        let row = [
            ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 1_700_000_000)),
            "Mounjaro",
            "5.0",
            "onSchedule",
            "Abdomen",
            note
        ].map(ExportService.csvEscaped).joined(separator: ",")

        let records = ImportService.parseCSV(header + "\n" + row)
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[1].count, 6)
        XCTAssertEqual(records[1][1], "Mounjaro")
        XCTAssertEqual(records[1][4], "Abdomen")
        XCTAssertEqual(records[1][5], note)
    }

    func testNextExpectedDateUsesPreferredTimeWhenStartIsToday() {
        // Regression for "Overdue by -7 days" on home: nextExpectedDate must
        // be the next aligned Saturday 09:00, not the literal start moment.
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 5, day: 23, hour: 10, minute: 18))!
        let now = cal.date(from: DateComponents(year: 2026, month: 5, day: 23, hour: 10, minute: 30))!
        let plan = MedicationPlan(
            scheduleStartDate: start,
            preferredWeekday: 7,
            preferredHour: 9,
            preferredMinute: 0
        )
        let next = ScheduleEngine.nextExpectedDate(after: now, plan: plan, calendar: cal)
        let expected = cal.date(from: DateComponents(year: 2026, month: 5, day: 30, hour: 9, minute: 0))!
        XCTAssertEqual(next, expected)
    }
}
