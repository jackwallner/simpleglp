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

// MARK: - Proof pass: time, data and state (scratch, never committed)

@MainActor
final class TimeStateProofTests: XCTestCase {
    private func cal(_ zone: String, _ id: Calendar.Identifier = .gregorian) -> Calendar {
        var c = Calendar(identifier: id)
        c.timeZone = TimeZone(identifier: zone)!
        return c
    }

    private func note(_ text: String) {
        let a = XCTAttachment(string: text)
        a.lifetime = .keepAlways
        add(a)
        print("PROOF \(text)")
    }

    private func memoryContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: ShotEvent.self, MedicationPlan.self, DoseStep.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    // MARK: P1 every-N-days plans change dose day with the time zone

    /// Tuesday 22:00 in Los Angeles, every 14 days.
    private func fortnightlyPlan(_ la: Calendar, interval: Int = 14) -> MedicationPlan {
        MedicationPlan(medication: .ozempic, doseMg: 0.5,
                       scheduleStartDate: la.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 22))!,
                       preferredWeekday: 3, preferredHour: 22, preferredMinute: 0, intervalDays: interval)
    }

    func testP1_FortnightlyDoseDayMovesWhenTheDeviceZoneMovesEast() throws {
        let la = cal("America/Los_Angeles")
        let ny = cal("America/New_York")
        let plan = fortnightlyPlan(la)
        let now = la.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 12))!
        let home = try XCTUnwrap(ScheduleEngine.nextExpectedDate(after: now, plan: plan, calendar: la))
        XCTAssertEqual(la.component(.weekday, from: home), 3, "precondition: Tuesday at home")
        let away = try XCTUnwrap(ScheduleEngine.nextExpectedDate(after: now, plan: plan, calendar: ny))
        note("P1 fortnightly home=\(home) weekdayHome=\(la.component(.weekday, from: home)) away=\(away) weekdayAway=\(ny.component(.weekday, from: away)) hourAway=\(ny.component(.hour, from: away))")
        XCTAssertEqual(ny.component(.weekday, from: away), 3,
                       "after a 3 hour trip east the every-14-days dose moved to weekday \(ny.component(.weekday, from: away)) (Tuesday is 3)")
    }

    func testP1_ControlWeeklyKeepsItsWeekdayBecauseOfNormalizeScheduleAnchor() throws {
        let la = cal("America/Los_Angeles")
        let ny = cal("America/New_York")
        let plan = fortnightlyPlan(la, interval: 7)
        XCTAssertTrue(plan.normalizeScheduleAnchor(calendar: ny), "weekly anchor is rewritten in the new zone")
        let now = la.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 12))!
        let away = try XCTUnwrap(ScheduleEngine.nextExpectedDate(after: now, plan: plan, calendar: ny))
        XCTAssertEqual(ny.component(.weekday, from: away), 3)
        // The same plan with a 3 day interval is never normalized.
        let threeDay = fortnightlyPlan(la, interval: 3)
        XCTAssertFalse(threeDay.normalizeScheduleAnchor(calendar: ny), "only isWeekly plans are normalized")
    }

    // MARK: B2 (first pass) setup on shot day after the planned time

    func testB2_SetupAfterTodaysPlannedTimeReadsNextWeek() throws {
        let la = cal("America/Los_Angeles")
        let now = la.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 14))!
        let plan = MedicationPlan(medication: .ozempic, doseMg: 0.25,
                                  scheduleStartDate: la.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 9))!,
                                  preferredWeekday: 4, preferredHour: 9, preferredMinute: 0, intervalDays: 7)
        plan.createdAt = now
        let due = try XCTUnwrap(ScheduleEngine.nextDue(plan: plan, events: [], now: now, calendar: la))
        let headline = HomeView.headline(for: due, now: now, calendar: la)
        let nudge = ScheduleEngine.nextUnclaimedOccurrence(now: now, plan: plan, events: [], calendar: la)
        note("B2 due=\(due) headline=\(headline) nudgeTarget=\(String(describing: nudge))")
        XCTAssertEqual(due, la.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 9)),
                       "set up on shot day at 14:00 with a 9:00 first dose, Home reads \"\(headline)\"")
    }

    // MARK: DST gap drift for a dose time inside the skipped hour

    func testP3_DailyDoseInsideTheSkippedHourKeepsItsTimeAfterSpringForward() throws {
        let la = cal("America/Los_Angeles")
        let plan = MedicationPlan(medication: .wegovyPill, doseMg: 4,
                                  scheduleStartDate: la.date(from: DateComponents(year: 2026, month: 2, day: 20))!,
                                  preferredHour: 2, preferredMinute: 30, intervalDays: 1)
        let now = la.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 12))!
        let slots = ReminderService.upcomingReminderSlots(plan: plan, events: [], now: now, calendar: la)
        let text = slots.map { slot -> String in
            let p = la.dateComponents([.month, .day, .hour, .minute], from: slot)
            return "\(p.month!)/\(p.day!) \(p.hour!):\(String(format: "%02d", p.minute!))"
        }.joined(separator: ", ")
        note("P3 reminder slots: \(text)")
        let afterGap = slots.filter { $0 > la.date(from: DateComponents(year: 2026, month: 3, day: 9))! }
        XCTAssertFalse(afterGap.isEmpty, "precondition")
        for slot in afterGap {
            let p = la.dateComponents([.hour, .minute], from: slot)
            XCTAssertEqual(p.hour, 2, "reminder slot \(slot) drifted to \(p.hour!):\(p.minute!)")
        }
        let homeNow = la.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 1))!
        let home = try XCTUnwrap(ScheduleEngine.nextDue(plan: plan, events: [], now: homeNow, calendar: la))
        let reminder = try XCTUnwrap(ScheduleEngine.nextExpectedDate(after: homeNow, plan: plan, calendar: la))
        XCTAssertEqual(reminder, home, "Home says \(home), the reminder schedule says \(reminder)")
    }

    // MARK: streak and day math across odd calendars and midnight DST gaps

    func testStreakAndDayMathAcrossCalendarsAndMidnightDST() throws {
        let cases: [(Calendar.Identifier, String, DateComponents)] = [
            (.gregorian, "America/Havana", DateComponents(year: 2026, month: 3, day: 10, hour: 15)),
            (.gregorian, "America/Havana", DateComponents(year: 2026, month: 11, day: 5, hour: 15)),
            (.gregorian, "America/Santiago", DateComponents(year: 2026, month: 9, day: 10, hour: 15)),
            (.buddhist, "Asia/Bangkok", DateComponents(year: 2026, month: 3, day: 10, hour: 15)),
            (.japanese, "Asia/Tokyo", DateComponents(year: 2026, month: 3, day: 10, hour: 15)),
            (.hebrew, "Asia/Jerusalem", DateComponents(year: 2026, month: 3, day: 28, hour: 15)),
            (.islamicUmmAlQura, "Asia/Riyadh", DateComponents(year: 2026, month: 3, day: 10, hour: 15)),
            (.persian, "Asia/Tehran", DateComponents(year: 2026, month: 3, day: 10, hour: 15)),
        ]
        for (id, zone, nowParts) in cases {
            let greg = cal(zone)
            let target = cal(zone, id)
            let now = greg.date(from: nowParts)!
            let doses = (0..<9).map { offset -> Date in
                let day = greg.date(byAdding: .day, value: -offset, to: now)!
                return greg.date(bySettingHour: 12, minute: 0, second: 0, of: day)!
            }
            let label = "\(id)/\(zone)/\(nowParts.month!)-\(nowParts.day!)"
            XCTAssertEqual(DailyAdherence.streak(doseDates: doses, now: now, calendar: target), 9, "streak \(label)")
            XCTAssertEqual(DailyAdherence.longestStreak(doseDates: doses, calendar: target), 9, "longest \(label)")
            let recent = DailyAdherence.recentDays(doseDates: doses, count: 7, now: now, calendar: target)
            XCTAssertEqual(recent.count, 7, "recentDays count \(label)")
            XCTAssertTrue(recent.allSatisfy(\.taken), "recentDays taken \(label)")
            let summary = DailyAdherence.recentSummary(doseDates: doses, days: 9, planStart: nil, now: now, calendar: target)
            XCTAssertEqual(summary.taken, 9, "recentSummary \(label)")
        }
    }

    func testWeeklyMatchAndNextDueAcrossBothDSTChangesAndOddCalendars() throws {
        for (id, zone) in [(Calendar.Identifier.gregorian, "America/Los_Angeles"), (.gregorian, "Europe/London"),
                           (.gregorian, "Australia/Lord_Howe"), (.buddhist, "Asia/Bangkok"), (.hebrew, "Asia/Jerusalem")] {
            let greg = cal(zone)
            let target = cal(zone, id)
            // Sunday 01:30 weekly, started 2026-02-01 (a Sunday).
            let plan = MedicationPlan(medication: .ozempic, doseMg: 0.5,
                                      scheduleStartDate: greg.date(from: DateComponents(year: 2026, month: 2, day: 1, hour: 1, minute: 30))!,
                                      preferredWeekday: 1, preferredHour: 1, preferredMinute: 30, intervalDays: 7)
            var events: [ShotEvent] = []
            var week = greg.date(from: DateComponents(year: 2026, month: 2, day: 1, hour: 1, minute: 35))!
            while week < greg.date(from: DateComponents(year: 2026, month: 12, day: 1))! {
                let m = ScheduleEngine.match(timestamp: week, plan: plan, existingEvents: events, calendar: target)
                XCTAssertEqual(m.status, .onSchedule, "\(id)/\(zone) \(week)")
                events.append(ShotEvent(timestamp: week, scheduledDate: m.scheduledDate, scheduleStatus: m.status, minutesFromSchedule: m.minutesFromSchedule))
                week = greg.date(byAdding: .day, value: 7, to: week)!
            }
            let now = greg.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 12))!
            let next = try XCTUnwrap(ScheduleEngine.nextDue(plan: plan, events: events, now: now, calendar: target))
            let p = greg.dateComponents([.weekday, .hour, .minute], from: next)
            XCTAssertEqual(p.weekday, 1, "\(id)/\(zone) next due weekday")
            XCTAssertEqual(p.hour, 1, "\(id)/\(zone) next due hour \(next)")
        }
    }

    // MARK: very large data

    func testPerf_PlanSaveRecalculationWithAThousandDailyDoses() throws {
        let context = try memoryContext()
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2023, month: 1, day: 1))!
        let plan = MedicationPlan(medication: .wegovyPill, doseMg: 4, scheduleStartDate: start,
                                  preferredHour: 7, preferredMinute: 0, intervalDays: 1)
        context.insert(plan)
        for day in 0..<1000 {
            let when = calendar.date(byAdding: .day, value: day, to: calendar.date(bySettingHour: 7, minute: 5, second: 0, of: start)!)!
            context.insert(ShotEvent(timestamp: when))
        }
        try context.save()
        let began = Date()
        PlanStore.recalculateScheduleMatches(for: plan, in: context)
        let elapsed = Date().timeIntervalSince(began)
        note("PERF recalc 1000 daily doses: \(elapsed) s")
        XCTAssertLessThan(elapsed, 2.0, "plan save recalculation of 1000 daily doses blocked the main thread for \(elapsed) s")
    }

    func testPerf_CSVImportOfAThousandDailyDoses() throws {
        let context = try memoryContext()
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2023, month: 1, day: 1))!
        context.insert(MedicationPlan(medication: .wegovyPill, doseMg: 4, scheduleStartDate: start,
                                      preferredHour: 7, preferredMinute: 0, intervalDays: 1))
        try context.save()
        let formatter = ISO8601DateFormatter()
        let rows = (0..<1000).map { day -> String in
            var row = Array(repeating: "", count: ExportService.columns.count)
            row[0] = formatter.string(from: calendar.date(byAdding: .day, value: day, to: calendar.date(bySettingHour: 7, minute: 5, second: 0, of: start)!)!)
            row[1] = "Wegovy pill"
            row[2] = "4.0"
            return row.joined(separator: ",")
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".csv")
        defer { try? FileManager.default.removeItem(at: url) }
        try ([ExportService.header] + rows).joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        let began = Date()
        let count = try ImportService.importEvents(from: url, into: context)
        let elapsed = Date().timeIntervalSince(began)
        note("PERF import 1000 rows: \(elapsed) s, imported \(count)")
        XCTAssertEqual(count, 1000)
        XCTAssertLessThan(elapsed, 2.0, "import of 1000 rows ran on the main actor for \(elapsed) s")
    }

    // MARK: B4 (first pass) backdated log refused while a capture runs

    func testB4_BackdatedLogIsRefusedWhileAHealthCaptureRuns() throws {
        let context = try memoryContext()
        context.insert(MedicationPlan(medication: .ozempic, doseMg: 0.5, intervalDays: 7))
        try context.save()
        let coordinator = ShotCaptureCoordinator()
        coordinator.isCapturing = true
        let saved = coordinator.captureShot(in: context, tapDate: Date().addingTimeInterval(-3 * 3600))
        let count = try context.fetch(FetchDescriptor<ShotEvent>()).count
        note("B4 captureShot returned \(saved), stored \(count), banner=\(coordinator.bannerMessage ?? "nil")")
        XCTAssertTrue(saved, "LogEarlierSheet dismisses itself after onLog; HistoryView ignores this result")
        XCTAssertEqual(count, 1)
    }

    // MARK: B10 (first pass) pill wait on Home vs glance at midnight

    func testB10_PillWaitSurvivesMidnightOnTheGlanceButNotOnHome() throws {
        let la = cal("America/Los_Angeles")
        let taken = la.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 23, minute: 50))!
        let now = la.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 0, minute: 5))!
        let glance = GLPGlance(isPill: true, medicationName: "Wegovy pill", waitMinutes: 30, lastDoseAt: taken, nextDoseAt: nil)
        let glanceEnd = glance.waitEndsAt(now: now)
        let homeDose = DailyAdherence.todaysDose(doseDates: [taken], now: now, calendar: la)
        note("B10 glanceEnd=\(String(describing: glanceEnd)) homeTodaysDose=\(String(describing: homeDose))")
        XCTAssertNotNil(glanceEnd, "precondition: widget and Watch still count down")
        XCTAssertNotNil(homeDose, "Home finds no dose today at 00:05, so PillRoutineView.waitEnd is nil while the wait runs")
    }

    // MARK: B6 (first pass) plan save leaves the old late-dose nudge

    func testB6_PlanSaveThatMovesTodaysDoseFarEarlierLeavesTheOldNudgePending() async throws {
        let context = try memoryContext()
        let fake = FakeNotificationCenter.shared
        fake.install(status: .authorized)
        let defaults = GLPAppGroup.userDefaults
        let keys: [GLPStorageKey] = [.proAlertsEnabled, .proAlertQuietHoursEnabled, .patternAlertsEnabled]
        let saved = keys.map { defaults.object(forKey: $0.rawValue) }
        StoreService.shared.setLocalOverride(isPro: true)
        defaults.set(true, forKey: GLPStorageKey.proAlertsEnabled.rawValue)
        defaults.set(false, forKey: GLPStorageKey.proAlertQuietHoursEnabled.rawValue)
        defaults.set(false, forKey: GLPStorageKey.patternAlertsEnabled.rawValue)
        defer {
            fake.uninstall()
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key.rawValue) } else { defaults.removeObject(forKey: key.rawValue) }
            }
            StoreService.shared.setLocalOverride(isPro: false)
        }
        try await Task.sleep(nanoseconds: 800_000_000)
        fake.clear()

        let calendar = Calendar.current
        let now = Date()
        let slot1 = now.addingTimeInterval(-30 * 60)
        let slot2 = now.addingTimeInterval(-6 * 3600)
        guard calendar.isDate(slot2, inSameDayAs: now) else { throw XCTSkip("within six hours after midnight") }
        let plan = MedicationPlan(medication: .wegovyPill, doseMg: 4,
                                  scheduleStartDate: calendar.date(byAdding: .day, value: -10, to: now)!,
                                  preferredHour: calendar.component(.hour, from: slot1),
                                  preferredMinute: calendar.component(.minute, from: slot1), intervalDays: 1, reminderEnabled: true)
        plan.createdAt = plan.scheduleStartDate
        context.insert(plan)
        try context.save()
        await ProactiveAlertsEngine.schedulePatternAlertsIfEnabled(in: context)
        let first = try XCTUnwrap(fake.fireDate(of: ProactiveAlertsEngine.lateDoseIdentifier), "precondition: nudge armed")

        plan.preferredHour = calendar.component(.hour, from: slot2)
        plan.preferredMinute = calendar.component(.minute, from: slot2)
        plan.updatedAt = .now
        PlanStore.recalculateScheduleMatches(for: plan, in: context)
        try context.save()
        DoseRoutineService.refresh(in: context)
        try await Task.sleep(nanoseconds: 1_500_000_000)
        let after = fake.fireDate(of: ProactiveAlertsEngine.lateDoseIdentifier)
        note("B6 first=\(first) after=\(String(describing: after)) now=\(Date())")
        XCTAssertNotNil(after)
        if let after {
            XCTAssertGreaterThan(abs(after.timeIntervalSince(first)), 120,
                                 "plan now says the dose was due 6 hours ago, but the nudge is still at the old time \(after)")
        }
    }
}
