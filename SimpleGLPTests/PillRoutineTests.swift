import XCTest
@testable import SimpleGLP

@MainActor
final class PillRoutineTests: XCTestCase {
    private let cal = Calendar.current

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 3) -> Date {
        cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func dailyPlan(startDay: Int = 1, hour: Int = 7, wait: Int = 30) -> MedicationPlan {
        let plan = MedicationPlan(
            medication: .wegovyPill,
            doseMg: 1.5,
            scheduleStartDate: date(startDay, 0),
            preferredHour: hour,
            preferredMinute: 0,
            intervalDays: 1,
            waitMinutes: wait
        )
        return plan
    }

    private func event(at timestamp: Date, plan: MedicationPlan, existing: [ShotEvent] = []) -> ShotEvent {
        let match = ScheduleEngine.match(timestamp: timestamp, plan: plan, existingEvents: existing)
        return ShotEvent(
            timestamp: timestamp,
            scheduledDate: match.scheduledDate,
            scheduleStatus: match.status,
            minutesFromSchedule: match.minutesFromSchedule
        )
    }

    // MARK: - Medication catalog

    func testPillMedicationsAreDailyPillsWithWaitDefaults() {
        XCTAssertEqual(GLPMedication.wegovyPill.form, .pill)
        XCTAssertEqual(GLPMedication.foundayo.form, .pill)
        XCTAssertEqual(GLPMedication.ozempic.form, .injection)
        XCTAssertEqual(GLPMedication.wegovyPill.defaultWaitMinutes, 30)
        XCTAssertEqual(GLPMedication.rybelsus.defaultWaitMinutes, 30)
        XCTAssertEqual(GLPMedication.foundayo.defaultWaitMinutes, 0)
        XCTAssertEqual(GLPMedication.wegovyPill.standardDoseStepsMg, [1.5, 4, 9, 25])
        XCTAssertTrue(GLPMedication.options(for: .pill).allSatisfy { $0.form == .pill })
        XCTAssertTrue(GLPMedication.otherPill.isCustom)
    }

    func testShotPlanHasNoWaitEvenIfFieldIsSet() {
        let plan = MedicationPlan(medication: .ozempic, waitMinutes: 30)
        XCTAssertEqual(plan.effectiveWaitMinutes, 0)
        XCTAssertEqual(dailyPlan().effectiveWaitMinutes, 30)
    }

    // MARK: - Daily matching

    func testDailyPillNearPlannedTimeIsOnSchedule() {
        let match = ScheduleEngine.match(timestamp: date(5, 8, 30), plan: dailyPlan())
        XCTAssertEqual(match.status, .onSchedule)
        XCTAssertEqual(match.scheduledDate, date(5, 7))
    }

    func testLateNightPillBelongsToItsOwnDay() {
        let match = ScheduleEngine.match(timestamp: date(5, 23), plan: dailyPlan())
        XCTAssertEqual(match.status, .late)
        XCTAssertEqual(match.scheduledDate, date(5, 7))
    }

    func testSecondPillSameDayIsExtra() {
        let plan = dailyPlan()
        let first = event(at: date(5, 7), plan: plan)
        let second = ScheduleEngine.match(timestamp: date(5, 12), plan: plan, existingEvents: [first])
        XCTAssertEqual(second.status, .extra)
        XCTAssertNil(second.scheduledDate)
    }

    func testPillBeforePlanStartIsExtra() {
        let match = ScheduleEngine.match(timestamp: date(2, 7), plan: dailyPlan(startDay: 3))
        XCTAssertEqual(match.status, .extra)
    }

    // MARK: - Adherence

    func testStreakCountsThroughYesterdayUntilTodayIsLogged() {
        let doses = [date(3, 7), date(4, 7), date(5, 7)]
        XCTAssertEqual(DailyAdherence.streak(doseDates: doses, now: date(6, 6)), 3)
        XCTAssertEqual(DailyAdherence.streak(doseDates: doses + [date(6, 7)], now: date(6, 8)), 4)
    }

    func testStreakBreaksOnMissedDay() {
        let doses = [date(1, 7), date(2, 7), date(4, 7), date(5, 7)]
        XCTAssertEqual(DailyAdherence.streak(doseDates: doses, now: date(5, 9)), 2)
        XCTAssertEqual(DailyAdherence.streak(doseDates: doses, now: date(7, 9)), 0)
    }

    func testRecentDaysMarksTakenDaysOldestFirst() {
        let days = DailyAdherence.recentDays(doseDates: [date(5, 7), date(7, 7)], now: date(7, 12))
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.first?.date, cal.startOfDay(for: date(1, 0)))
        XCTAssertEqual(days.last?.date, cal.startOfDay(for: date(7, 0)))
        XCTAssertEqual(days.filter(\.taken).map(\.date), [cal.startOfDay(for: date(5, 0)), cal.startOfDay(for: date(7, 0))])
    }

    // MARK: - Reminders

    func testDailyReminderSkipsTodayOnceLogged() {
        let plan = dailyPlan(hour: 9)
        let early = event(at: date(5, 7), plan: plan)
        let slots = ReminderService.upcomingReminderSlots(plan: plan, events: [early], now: date(5, 7, 5))
        XCTAssertEqual(slots.first, date(6, 9))
        XCTAssertEqual(slots.count, ReminderService.dailyReminderSlots)
    }

    func testDailyReminderIncludesTodayWhenNotLogged() {
        let slots = ReminderService.upcomingReminderSlots(plan: dailyPlan(hour: 9), events: [], now: date(5, 7))
        XCTAssertEqual(slots.first, date(5, 9))
    }

    // MARK: - Glance

    func testGlanceWaitRunsOnlyForPillsWithinTheWindow() {
        let taken = date(5, 7)
        let glance = GLPGlance(isPill: true, medicationName: "Wegovy pill", waitMinutes: 30, lastDoseAt: taken)
        XCTAssertEqual(glance.waitEndsAt(now: date(5, 7, 10)), date(5, 7, 30))
        XCTAssertNil(glance.waitEndsAt(now: date(5, 7, 31)))
        XCTAssertNil(GLPGlance(isPill: false, waitMinutes: 30, lastDoseAt: taken).waitEndsAt(now: date(5, 7, 10)))
        XCTAssertNil(GLPGlance(isPill: true, waitMinutes: 0, lastDoseAt: taken).waitEndsAt(now: date(5, 7, 10)))
    }

    // MARK: - Supply

    func testSupplyCountsOnlyDosesAfterRefill() {
        let plan = dailyPlan()
        plan.supplyCount = 30
        plan.supplyUpdatedAt = date(10, 12)
        let doses = [date(9, 7), date(10, 7), date(11, 7), date(12, 7)]
        XCTAssertEqual(SupplyMath.remaining(plan: plan, doseDates: doses), 28)
        plan.supplyUpdatedAt = nil
        XCTAssertNil(SupplyMath.remaining(plan: plan, doseDates: doses))
    }

    func testRefillReminderFiresAWeekBeforeRunningOut() {
        let plan = dailyPlan(hour: 7)
        let fire = SupplyMath.reminderDate(remaining: 10, plan: plan, now: date(10, 12))
        XCTAssertEqual(fire, date(13, 7))
        XCTAssertNil(SupplyMath.reminderDate(remaining: 7, plan: plan, now: date(10, 12)))
        XCTAssertTrue(SupplyMath.isLow(remaining: 7, plan: plan))
        XCTAssertFalse(SupplyMath.isLow(remaining: 8, plan: plan))
    }

    func testWeeklySupplyDaysScaleWithCadence() {
        let plan = MedicationPlan(medication: .zepbound, intervalDays: 7)
        XCTAssertEqual(SupplyMath.daysLeft(remaining: 3, plan: plan), 21)
    }

    // MARK: - Plan editing

    func testDailyAnchorNeverMovesIntoTheFuture() {
        let anchor = PlanEditorView.dailyAnchor(time: date(1, 6, 45), existing: date(20, 9), now: date(10, 12))
        XCTAssertEqual(anchor, date(10, 6, 45))
        let kept = PlanEditorView.dailyAnchor(time: date(1, 6, 45), existing: date(2, 9), now: date(10, 12))
        XCTAssertEqual(kept, date(2, 6, 45))
    }

    // MARK: - Late-dose nudge

    func testLateNudgeSkipsAMissedDayOnceTodaysPillIsLogged() {
        let plan = dailyPlan(hour: 7)
        // Day 9 missed; day 10's pill taken early at 6:00, before its 7:00 slot.
        let early = event(at: date(10, 6), plan: plan)
        let next = ProactiveAlertsEngine.nextUnclaimedOccurrence(now: date(10, 6, 5), plan: plan, events: [early], calendar: cal)
        XCTAssertEqual(next, date(11, 7))
    }

    func testLateNudgeStillTargetsAnUnloggedDoseToday() {
        let plan = dailyPlan(hour: 7)
        let yesterday = event(at: date(9, 7), plan: plan)
        let next = ProactiveAlertsEngine.nextUnclaimedOccurrence(now: date(10, 9), plan: plan, events: [yesterday], calendar: cal)
        XCTAssertEqual(next, date(10, 7))
    }
}
