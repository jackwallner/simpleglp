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

    // MARK: - Every-N-days cadence

    func testEveryNDaysFirstDoseAnchorsOnStartDayAtPreferredTime() {
        // Non-weekly plans anchor on the start date itself (not a weekday), at the preferred time.
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 10, minute: 18))!
        let plan = MedicationPlan(scheduleStartDate: start, preferredHour: 9, preferredMinute: 0, intervalDays: 3)
        let first = ScheduleEngine.firstScheduledDate(plan: plan, calendar: cal)
        let expected = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 9, minute: 0))!
        XCTAssertEqual(first, expected)
    }

    func testEveryNDaysNextExpectedStepsByCadence() {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 9))!
        let now = cal.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 12))!
        let plan = MedicationPlan(scheduleStartDate: start, preferredHour: 9, preferredMinute: 0, intervalDays: 3)
        let next = ScheduleEngine.nextExpectedDate(after: now, plan: plan, calendar: cal)
        let expected = cal.date(from: DateComponents(year: 2026, month: 1, day: 4, hour: 9))!
        XCTAssertEqual(next, expected)
    }

    func testEveryNDaysScheduledDateOnOrBefore() {
        // Occurrences: Jan 1, 4, 7, 10 — largest on/before Jan 8 is Jan 7.
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 9))!
        let date = cal.date(from: DateComponents(year: 2026, month: 1, day: 8, hour: 12))!
        let plan = MedicationPlan(scheduleStartDate: start, preferredHour: 9, preferredMinute: 0, intervalDays: 3)
        let prior = ScheduleEngine.scheduledDate(onOrBefore: date, plan: plan, calendar: cal)
        let expected = cal.date(from: DateComponents(year: 2026, month: 1, day: 7, hour: 9))!
        XCTAssertEqual(prior, expected)
    }

    func testEveryNDaysMatchOnSchedule() {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 9))!
        let plan = MedicationPlan(scheduleStartDate: start, preferredHour: 9, preferredMinute: 0, intervalDays: 3)
        let match = ScheduleEngine.match(
            timestamp: cal.date(from: DateComponents(year: 2026, month: 1, day: 4, hour: 9))!,
            plan: plan,
            calendar: cal
        )
        XCTAssertEqual(match.status, .onSchedule)
    }

    func testDailyCadenceNextExpected() {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 8))!
        let now = cal.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 12))!
        let plan = MedicationPlan(scheduleStartDate: start, preferredHour: 8, preferredMinute: 0, intervalDays: 1)
        let next = ScheduleEngine.nextExpectedDate(after: now, plan: plan, calendar: cal)
        let expected = cal.date(from: DateComponents(year: 2026, month: 1, day: 6, hour: 8))!
        XCTAssertEqual(next, expected)
    }

    func testCadenceDaysGuardsAgainstZeroInterval() {
        // A 0 left by an older migration must not produce a degenerate schedule.
        let plan = MedicationPlan(intervalDays: 0)
        XCTAssertEqual(plan.cadenceDays, 1)
    }

    func testIntervalLabel() {
        XCTAssertEqual(GLPScheduleFormat.intervalLabel(1), "day")
        XCTAssertEqual(GLPScheduleFormat.intervalLabel(7), "week")
        XCTAssertEqual(GLPScheduleFormat.intervalLabel(14), "2 weeks")
        XCTAssertEqual(GLPScheduleFormat.intervalLabel(10), "10 days")
        XCTAssertEqual(GLPScheduleFormat.intervalLabel(0), "day")
    }
}
