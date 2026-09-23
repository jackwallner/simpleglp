import SwiftData
import XCTest
@testable import SimpleGLP

@MainActor
final class DoseRoutinePolishTests: XCTestCase {
    private let cal = Calendar.current

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 3) -> Date {
        cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func dailyPlan(startDay: Int = 1, hour: Int = 7) -> MedicationPlan {
        MedicationPlan(medication: .wegovyPill, doseMg: 4, scheduleStartDate: date(startDay, 0), preferredHour: hour, preferredMinute: 0, intervalDays: 1, waitMinutes: 30)
    }

    /// Weekly on the 5th (a Thursday) at 8:30.
    private func weeklyPlan() -> MedicationPlan {
        MedicationPlan(medication: .mounjaro, doseMg: 5, scheduleStartDate: date(5, 0), preferredHour: 8, preferredMinute: 30, intervalDays: 7)
    }

    private func event(at timestamp: Date, plan: MedicationPlan, existing: [ShotEvent] = []) -> ShotEvent {
        let match = ScheduleEngine.match(timestamp: timestamp, plan: plan, existingEvents: existing)
        return ShotEvent(timestamp: timestamp, scheduledDate: match.scheduledDate, scheduleStatus: match.status, minutesFromSchedule: match.minutesFromSchedule)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([ShotEvent.self, MedicationPlan.self, DoseStep.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    // MARK: - Next due

    func testDailyNextDueIsTodayUntilLoggedEvenAfterAMissedDay() {
        let plan = dailyPlan(hour: 7)
        let twoDaysAgo = event(at: date(8, 7), plan: plan)
        XCTAssertEqual(ScheduleEngine.nextDue(plan: plan, events: [twoDaysAgo], now: date(10, 6), calendar: cal), date(10, 7))
        XCTAssertEqual(ScheduleEngine.nextDue(plan: plan, events: [twoDaysAgo], now: date(10, 11), calendar: cal), date(10, 7))
        let today = event(at: date(10, 6, 40), plan: plan, existing: [twoDaysAgo])
        XCTAssertEqual(ScheduleEngine.nextDue(plan: plan, events: [twoDaysAgo, today], now: date(10, 7), calendar: cal), date(11, 7))
    }

    func testWeeklyShotTakenADayEarlyMovesNextDueToTheFollowingWeek() {
        let plan = weeklyPlan()
        let onTime = event(at: date(5, 8, 30), plan: plan)
        // Slot is Thursday the 12th; the shot goes in Wednesday the 11th.
        let early = event(at: date(11, 20), plan: plan, existing: [onTime])
        XCTAssertEqual(early.scheduledDate, date(12, 8, 30))
        XCTAssertEqual(ScheduleEngine.nextDue(plan: plan, events: [onTime, early], now: date(11, 21), calendar: cal), date(19, 8, 30))
    }

    func testWeeklyMissedShotStaysDueUntilLogged() {
        let plan = weeklyPlan()
        let onTime = event(at: date(5, 8, 30), plan: plan)
        XCTAssertEqual(ScheduleEngine.nextDue(plan: plan, events: [onTime], now: date(14, 9), calendar: cal), date(12, 8, 30))
    }

    // MARK: - Glance

    func testGlanceRollsTodaysPillToTomorrowOnceTakenElsewhere() {
        var glance = GLPGlance(isPill: true, medicationName: "Wegovy pill", waitMinutes: 30, lastDoseAt: date(9, 7), nextDoseAt: date(10, 7))
        XCTAssertEqual(glance.upcomingDose(now: date(10, 6)), date(10, 7))
        glance.lastDoseAt = date(10, 6, 30) // logged on the Watch; the phone hasn't republished
        XCTAssertEqual(glance.upcomingDose(now: date(10, 6, 31)), date(11, 7))
    }

    func testOldGlanceWithoutNextDoseStillDecodes() throws {
        let legacy = #"{"isPill":true,"medicationName":"Rybelsus","waitMinutes":30}"#.data(using: .utf8)
        let glance = try XCTUnwrap(GLPGlanceStore.decode(legacy))
        XCTAssertEqual(glance.medicationName, "Rybelsus")
        XCTAssertNil(glance.nextDoseAt)
    }

    func testDayDistanceReadsNaturally() {
        let now = date(10, 12)
        XCTAssertEqual(GLPGlance.dayDistance(to: date(10, 20), now: now), "Today")
        XCTAssertEqual(GLPGlance.dayDistance(to: date(11, 1), now: now), "Tomorrow")
        XCTAssertEqual(GLPGlance.dayDistance(to: date(13, 8), now: now), "In 3 days")
        XCTAssertEqual(GLPGlance.dayDistance(to: date(9, 8), now: now), "1 day late")
        XCTAssertEqual(GLPGlance.dayDistance(to: date(7, 8), now: now), "3 days late")
    }

    // MARK: - Adherence

    func testMonthSummaryCountsOnlyPlanDaysThroughToday() {
        let taken: Set<Date> = [date(3, 0), date(4, 0), date(6, 0)].reduce(into: []) { $0.insert(cal.startOfDay(for: $1)) }
        let summary = DailyAdherence.monthSummary(takenDays: taken, month: date(1, 0), planStart: date(3, 9), now: date(7, 12), calendar: cal)
        XCTAssertEqual(summary.planned, 5) // the 3rd through the 7th
        XCTAssertEqual(summary.taken, 3)
        let before = DailyAdherence.monthSummary(takenDays: [], month: date(1, 0, month: 2), planStart: date(3, 9), now: date(7, 12), calendar: cal)
        XCTAssertEqual(before.planned, 0)
    }

    func testRecentSummaryAndLongestStreak() {
        let doses = [date(1, 7), date(2, 7), date(3, 7), date(5, 7), date(6, 7)]
        let recent = DailyAdherence.recentSummary(doseDates: doses, days: 30, planStart: date(1, 0), now: date(6, 12), calendar: cal)
        XCTAssertEqual(recent.planned, 6)
        XCTAssertEqual(recent.taken, 5)
        XCTAssertEqual(DailyAdherence.longestStreak(doseDates: doses + [date(2, 20)], calendar: cal), 3)
        XCTAssertEqual(DailyAdherence.longestStreak(doseDates: [], calendar: cal), 0)
    }

    // MARK: - Hands-free logging

    func testAlreadyLoggedBlocksASecondPillTheSameDayOnly() throws {
        let context = try makeContext()
        let plan = dailyPlan()
        context.insert(plan)
        context.insert(ShotEvent(timestamp: date(10, 7)))
        try context.save()
        XCTAssertEqual(DoseRoutineService.alreadyLogged(at: date(10, 21), in: context), date(10, 7))
        XCTAssertNil(DoseRoutineService.alreadyLogged(at: date(11, 6), in: context))
    }

    func testAlreadyLoggedForShotsUsesATwelveHourWindow() throws {
        let context = try makeContext()
        context.insert(weeklyPlan())
        context.insert(ShotEvent(timestamp: date(12, 8)))
        try context.save()
        XCTAssertNotNil(DoseRoutineService.alreadyLogged(at: date(12, 19), in: context))
        XCTAssertNil(DoseRoutineService.alreadyLogged(at: date(12, 21), in: context))
    }

    // MARK: - Siri

    func testSpeechAfterLoggingAPillWithAWait() {
        let glance = GLPGlance(isPill: true, medicationName: "Wegovy pill", waitMinutes: 30, lastDoseAt: date(10, 7), nextDoseAt: date(11, 7))
        let line = DoseSpeech.afterLog(glance: glance, noun: "pill", now: date(10, 7))
        XCTAssertTrue(line.hasPrefix("Logged your Wegovy pill. Your 30-minute wait ends at "), line)
    }

    func testStatusSpeechNamesTheNextShotWithoutDoublingTheNoun() {
        let shot = GLPGlance(isPill: false, medicationName: "Mounjaro", lastDoseAt: date(5, 8), nextDoseAt: date(12, 8, 30))
        let line = DoseSpeech.status(glance: shot, noun: "shot", now: date(11, 9))
        XCTAssertTrue(line.hasPrefix("Your next Mounjaro shot is tomorrow at "), line)
        let pill = GLPGlance(isPill: true, medicationName: "Wegovy pill", waitMinutes: 30, lastDoseAt: date(9, 7), nextDoseAt: date(10, 7))
        let late = DoseSpeech.status(glance: pill, noun: "pill", now: date(10, 9))
        XCTAssertTrue(late.hasPrefix("Your Wegovy pill was planned for today at "), late)
    }

    // MARK: - Details sheet

    func testUnratedFeelingsAreNotStoredAsZero() {
        XCTAssertNil(FeelingRow.stored(FeelingRow.unrated))
        XCTAssertEqual(FeelingRow.stored(0), 0)
        XCTAssertEqual(FeelingRow.stored(4), 4)
    }
}
