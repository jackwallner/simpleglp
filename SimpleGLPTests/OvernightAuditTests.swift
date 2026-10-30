import SwiftData
import XCTest
@testable import SimpleGLP

/// Guards for the 2026-10-30 overnight bug-hunt findings.
@MainActor
final class OvernightAuditTests: XCTestCase {
    private let cal = Calendar.current

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 10, calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Weekly on Sundays at 9:00, starting Sunday Oct 4.
    private func weeklySundayPlan() -> MedicationPlan {
        MedicationPlan(medication: .mounjaro, doseMg: 2.5, scheduleStartDate: date(4, 0), preferredHour: 9, preferredMinute: 0, intervalDays: 7)
    }

    private func dailyPlan(hour: Int = 7, month: Int = 3) -> MedicationPlan {
        MedicationPlan(medication: .wegovyPill, doseMg: 4, scheduleStartDate: date(1, 0, month: month), preferredHour: hour, preferredMinute: 0, intervalDays: 1, waitMinutes: 30)
    }

    private func event(at timestamp: Date, plan: MedicationPlan, existing: [ShotEvent] = []) -> ShotEvent {
        let match = ScheduleEngine.match(timestamp: timestamp, plan: plan, existingEvents: existing)
        return ShotEvent(timestamp: timestamp, scheduledDate: match.scheduledDate, scheduleStatus: match.status, minutesFromSchedule: match.minutesFromSchedule)
    }

    // MARK: - F1 onboarding validation

    func testMedicationStepNeedsANameForCustomAndADoseAboveZero() {
        XCTAssertNotNil(OnboardingView.medicationProblem(medication: .other, customName: "  ", doseMg: 1))
        XCTAssertNotNil(OnboardingView.medicationProblem(medication: .otherPill, customName: "", doseMg: 1))
        XCTAssertNotNil(OnboardingView.medicationProblem(medication: .ozempic, customName: "", doseMg: 0))
        XCTAssertNil(OnboardingView.medicationProblem(medication: .other, customName: "Trulicity", doseMg: 0.75))
        XCTAssertNil(OnboardingView.medicationProblem(medication: .ozempic, customName: "", doseMg: 0.25))
    }

    // MARK: - F2 Pro alerts after Pro ends

    func testProAlertsStopOnceEntitlementsResolveWithoutPro() {
        XCTAssertFalse(ProactiveAlertsEngine.isActive(alertsEnabled: true, entitlementsResolved: true, isPro: false))
        XCTAssertTrue(ProactiveAlertsEngine.isActive(alertsEnabled: true, entitlementsResolved: true, isPro: true))
        // Unresolved: a Pro user reads as free for a moment; leave their alerts alone.
        XCTAssertTrue(ProactiveAlertsEngine.isActive(alertsEnabled: true, entitlementsResolved: false, isPro: false))
        XCTAssertFalse(ProactiveAlertsEngine.isActive(alertsEnabled: false, entitlementsResolved: true, isPro: true))
    }

    // MARK: - F3 refill heads-up

    func testRefillHeadsUpSurvivesAnEarlyOpenAndAnEarlyLog() {
        let plan = dailyPlan(hour: 7)
        let yesterday = event(at: date(11, 7, month: 3), plan: plan)
        // 8 pills left after yesterday's dose: today's 7:00 dose brings it to a week.
        let queued = SupplyMath.reminderDate(remaining: 8, plan: plan, events: [yesterday], now: date(11, 20, month: 3))
        XCTAssertEqual(queued, date(12, 7, month: 3))
        // Opening the app at 6:40 must not slide it a day.
        XCTAssertEqual(SupplyMath.reminderDate(remaining: 8, plan: plan, events: [yesterday], now: date(12, 6, 40, month: 3)), queued)
        // Logging at 6:45 leaves 7: the queued 7:00 heads-up stays.
        let early = event(at: date(12, 6, 45, month: 3), plan: plan, existing: [yesterday])
        XCTAssertEqual(SupplyMath.reminderDate(remaining: 7, plan: plan, events: [yesterday, early], previousFire: queued, now: date(12, 6, 46, month: 3)), queued)
        // Once it has gone out, it is not sent again this refill.
        XCTAssertNil(SupplyMath.reminderDate(remaining: 6, plan: plan, events: [yesterday, early], previousFire: queued, now: date(13, 8, month: 3)))
    }

    func testWeeklyRefillHeadsUpSurvivesAMidweekOpenAndTheShot() {
        let plan = weeklySundayPlan()
        let lastShot = event(at: date(4, 9), plan: plan)
        let queued = SupplyMath.reminderDate(remaining: 2, plan: plan, events: [lastShot], now: date(4, 10))
        XCTAssertEqual(queued, date(11, 9))
        XCTAssertEqual(SupplyMath.reminderDate(remaining: 2, plan: plan, events: [lastShot], previousFire: queued, now: date(7, 12)), queued)
        let sunday = event(at: date(11, 8, 50), plan: plan, existing: [lastShot])
        XCTAssertEqual(SupplyMath.reminderDate(remaining: 1, plan: plan, events: [lastShot, sunday], previousFire: queued, now: date(11, 8, 51)), queued)
    }

    func testRefillHeadsUpGoesOutAtTheNextDoseWhenSupplyStartsLow() {
        let plan = dailyPlan(hour: 7)
        XCTAssertEqual(SupplyMath.reminderDate(remaining: 5, plan: plan, now: date(10, 12, month: 3)), date(11, 7, month: 3))
        XCTAssertNil(SupplyMath.reminderDate(remaining: 0, plan: plan, now: date(10, 12, month: 3)))
    }

    // MARK: - F4 dose step start day

    func testDoseStepAppliesToTheMorningDoseOnItsStartDay() {
        let plan = weeklySundayPlan()
        // Added Wednesday evening, so the stored time of day is 8:15 PM.
        plan.doseSteps = [DoseStep(startDate: date(25, 20, 15), doseMg: 5)]
        XCTAssertEqual(ScheduleEngine.dose(on: date(25, 9), plan: plan), 5)
        XCTAssertEqual(ScheduleEngine.match(timestamp: date(25, 9, 5), plan: plan).doseMg, 5)
    }

    // MARK: - F5 late weekly shot

    func testFourDayLateWeeklyShotBelongsToTheMissedWeek() {
        let plan = weeklySundayPlan()
        let first = event(at: date(4, 9), plan: plan)
        let second = event(at: date(11, 9), plan: plan, existing: [first])
        // Oct 18 missed; taken Thursday Oct 22.
        let late = event(at: date(22, 9), plan: plan, existing: [first, second])
        XCTAssertEqual(late.scheduleStatus, .late)
        XCTAssertEqual(late.scheduledDate, date(18, 9))
        let events = [first, second, late]
        XCTAssertEqual(ScheduleEngine.nextDue(plan: plan, events: events, now: date(22, 10), calendar: cal), date(25, 9))
        XCTAssertEqual(ReminderService.upcomingReminderSlots(plan: plan, events: events, now: date(22, 10)).first, date(25, 9))
    }

    func testEarlyWeeklyShotStillMovesForwardWhenLastWeekIsLogged() {
        let plan = weeklySundayPlan()
        let first = event(at: date(4, 9), plan: plan)
        let second = event(at: date(11, 9), plan: plan, existing: [first])
        // Thursday Oct 15 is 3 days before Oct 18 and 4 days after the claimed Oct 11.
        let early = event(at: date(15, 9), plan: plan, existing: [first, second])
        XCTAssertEqual(early.scheduleStatus, .early)
        XCTAssertEqual(early.scheduledDate, date(18, 9))
    }

    // MARK: - F7 DST midnight

    func testStreakAndMonthSummarySurviveAMidnightDSTStart() throws {
        var santiago = Calendar(identifier: .gregorian)
        santiago.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Santiago"))
        var doses: [Date] = []
        var day = date(20, 9, month: 8, calendar: santiago)
        let last = date(20, 9, month: 9, calendar: santiago)
        while day <= last {
            doses.append(day)
            day = santiago.date(byAdding: .day, value: 1, to: day)!
        }
        let now = date(20, 10, month: 9, calendar: santiago)
        XCTAssertEqual(DailyAdherence.streak(doseDates: doses, now: now, calendar: santiago), 32)
        let takenDays = Set(doses.map { santiago.startOfDay(for: $0) })
        let summary = DailyAdherence.monthSummary(takenDays: takenDays, month: now, planStart: date(20, 0, month: 8, calendar: santiago), now: now, calendar: santiago)
        XCTAssertEqual(summary.taken, 20)
        XCTAssertEqual(summary.planned, 20)
    }

    // MARK: - F6 Pro pitch

    func testShotProPitchOnlySellsFeaturesThatShip() {
        let titles = ProFeatures.bullets(isPill: false).map(\.title) + ProFeatures.bullets(isPill: true).map(\.title)
        XCTAssertFalse(titles.contains { $0.localizedCaseInsensitiveContains("drift") })
    }

    // MARK: - F21 weekly reminder horizon

    func testWeeklyPlanQueuesTwoMonthsOfReminders() {
        let slots = ReminderService.upcomingReminderSlots(plan: weeklySundayPlan(), events: [], now: date(5, 12))
        XCTAssertEqual(slots.count, ReminderService.longReminderSlots)
        XCTAssertEqual(slots.first, date(11, 9))
    }

    // MARK: - F10 pattern alert after a logged dose

    func testPatternAlertSkipsADayAlreadyLogged() {
        // Sunday Oct 25, shot logged at 8:00: the 9:00 alert moves to next Sunday.
        XCTAssertEqual(ProactiveAlertsEngine.patternFireDate(weekday: 1, doseDates: [date(25, 8)], now: date(25, 8, 5)), date(1, 9, month: 11))
        XCTAssertEqual(ProactiveAlertsEngine.patternFireDate(weekday: 1, doseDates: [date(18, 9)], now: date(25, 8, 5)), date(25, 9))
    }

    // MARK: - F8 Watch double tap

    func testWatchDoubleTapIsSeenAsTheSameDose() throws {
        let schema = Schema([ShotEvent.self, MedicationPlan.self, DoseStep.self])
        let context = ModelContext(try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]))
        context.insert(ShotEvent(timestamp: date(25, 9)))
        try context.save()
        XCTAssertTrue(DoseRoutineService.hasDose(near: date(25, 9).addingTimeInterval(1), in: context))
        XCTAssertFalse(DoseRoutineService.hasDose(near: date(25, 9, 5), in: context))
    }

    // MARK: - F12 re-import

    func testReimportingTheSameExportDoesNotDuplicateDoses() throws {
        let schema = Schema([ShotEvent.self, MedicationPlan.self, DoseStep.self])
        let context = ModelContext(try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]))
        let rows = ["2026-10-04T09:00:00Z", "2026-10-11T09:00:00Z", "2026-10-18T09:00:00Z"].map { stamp -> String in
            var row = Array(repeating: "", count: ExportService.columns.count)
            row[0] = stamp
            row[1] = "Mounjaro"
            row[2] = "2.5"
            return row.joined(separator: ",")
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".csv")
        defer { try? FileManager.default.removeItem(at: url) }
        try ([ExportService.header] + rows).joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        XCTAssertEqual(try ImportService.importEvents(from: url, into: context), 3)
        XCTAssertEqual(try ImportService.importEvents(from: url, into: context), 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ShotEvent>()).count, 3)
    }
}
