import SwiftData
import XCTest
@testable import SimpleGLP

/// Regressions for the 2026-11-20 bug catalog's medium items.
@MainActor
final class BugCatalogFixTests: XCTestCase {
    // MARK: - A second widget tap must not write a second dose

    func testAShotPlanWidgetShowsDoneOnceTodaysDoseIsLogged() {
        let now = Date()
        var glance = GLPGlance(isPill: false, lastDoseAt: now.addingTimeInterval(-60))
        let entry = SimpleGLPWidgetEntry(date: now, lastShotDate: glance.lastDoseAt, recentShots: [], showConfirmation: false, glance: glance)
        XCTAssertTrue(entry.doneToday, "a weekly shot logged today hides the log button")
        glance.lastDoseAt = nil
        let fresh = SimpleGLPWidgetEntry(date: now, lastShotDate: nil, recentShots: [], showConfirmation: false, glance: glance)
        XCTAssertFalse(fresh.doneToday)
    }

    func testARepeatWidgetTapIsDroppedNotLogged() throws {
        let container = try ModelContainer(
            for: GLPModelStore.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let logged = Date().addingTimeInterval(-90)
        context.insert(ShotEvent(timestamp: logged, doseMg: 0.5))
        try context.save()

        let repeatTap = PendingWidgetShot(timestamp: Date())
        GLPAppGroup.enqueueWidgetShot(repeatTap)
        defer { GLPAppGroup.acknowledgeWidgetShot(id: repeatTap.id) }

        XCTAssertFalse(ShotCaptureCoordinator().ingestPendingWidgetShot(in: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ShotEvent>()), 1)
        XCTAssertFalse(GLPAppGroup.pendingWidgetShots().contains { $0.id == repeatTap.id }, "the repeat is acknowledged, not retried")
    }

    // MARK: - A Watch tap before activation reaches the phone

    func testAWatchDoseThePhoneHasNotSeenSurvivesThePhonesList() {
        var outbox = WatchShotOutbox()
        let tap = Date()
        let id = UUID()
        outbox.add(id: id, timestamp: tap)
        XCTAssertEqual(outbox.unsent.map(\.id), [id], "a tap before activation is held, not dropped")

        let older = RecentShot(timestamp: tap.addingTimeInterval(-7 * 86_400))
        let merged = outbox.merge(phone: [older], now: tap)
        XCTAssertEqual(merged.first?.id, id, "the phone's list does not wipe the unsent dose")
        XCTAssertEqual(merged.count, 2)

        outbox.markSent(id)
        XCTAssertTrue(outbox.unsent.isEmpty)
        let acknowledged = outbox.merge(phone: [RecentShot(id: id, timestamp: tap), older], now: tap)
        XCTAssertEqual(acknowledged.count, 2, "once the phone lists it, no duplicate")
        XCTAssertTrue(outbox.entries.isEmpty)
    }

    func testASentDoseThePhoneUndidStopsBeingKeptAfterADay() {
        var outbox = WatchShotOutbox()
        let tap = Date(timeIntervalSince1970: 1_700_000_000)
        outbox.add(id: UUID(), timestamp: tap)
        outbox.markSent(outbox.entries[0].id)
        XCTAssertEqual(outbox.merge(phone: [], now: tap.addingTimeInterval(3600)).count, 1)
        XCTAssertTrue(outbox.merge(phone: [], now: tap.addingTimeInterval(25 * 3600)).isEmpty)
    }

    func testTheOutboxSurvivesARelaunch() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        var outbox = WatchShotOutbox()
        outbox.add(id: UUID(), timestamp: .now)
        outbox.save(to: defaults)
        XCTAssertEqual(WatchShotOutbox.load(from: defaults), outbox)
    }
}

/// B11 and B15: the dose day and time of day across a zone change and a DST gap.
@MainActor
final class LowBugScheduleTests: XCTestCase {
    private func calendar(_ id: String) throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: id))
        return calendar
    }

    private func parts(_ date: Date?, _ calendar: Calendar) throws -> DateComponents {
        calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: try XCTUnwrap(date))
    }

    // MARK: B11 every-N-days doses keep their day when the phone changes time zone




    // MARK: B15 a daily dose inside the skipped spring-forward hour keeps its time

    func testB15_DailyDoseInsideTheSkippedHourKeepsItsTimeAfterSpringForward() throws {
        let la = try calendar("America/Los_Angeles")
        let start = try XCTUnwrap(la.date(from: DateComponents(year: 2026, month: 2, day: 2, hour: 2, minute: 30)))
        let plan = MedicationPlan(medication: .wegovyPill, doseMg: 4, scheduleStartDate: start, preferredHour: 2, preferredMinute: 30, intervalDays: 1)

        // The gap is Sunday 2026-03-08: 02:30 does not exist that day, the next day it does.
        let afterGap = try XCTUnwrap(la.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let next = try parts(ScheduleEngine.nextExpectedDate(after: afterGap, plan: plan, calendar: la), la)
        XCTAssertEqual([next.day, next.hour, next.minute], [9, 2, 30], "the slot after the change drifted an hour later")

        let latest = try parts(ScheduleEngine.scheduledDate(onOrBefore: try XCTUnwrap(la.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 12))), plan: plan, calendar: la), la)
        XCTAssertEqual([latest.day, latest.hour, latest.minute], [10, 2, 30])

        let slots = ReminderService.upcomingReminderSlots(plan: plan, events: [], now: try XCTUnwrap(la.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 12))), calendar: la)
        let later = try slots.dropFirst(2).map { try parts($0, la) }
        XCTAssertFalse(later.isEmpty)
        XCTAssertTrue(later.allSatisfy { $0.hour == 2 && $0.minute == 30 }, "every reminder after the change should stay at 02:30")

        let around = try ScheduleEngine.expectedDates(around: XCTUnwrap(la.date(from: DateComponents(year: 2026, month: 3, day: 11, hour: 12))), plan: plan, calendar: la).map { try parts($0, la) }
        XCTAssertTrue(around.allSatisfy { $0.hour == 2 && $0.minute == 30 })
    }

    func testB15_ControlEveryNDayCadenceStillCountsFromTheAnchorAcrossManyDays() throws {
        let la = try calendar("America/Los_Angeles")
        let start = try XCTUnwrap(la.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 9)))
        let plan = MedicationPlan(scheduleStartDate: start, preferredHour: 9, preferredMinute: 0, intervalDays: 7)
        let after = try XCTUnwrap(la.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 12)))
        let next = try parts(ScheduleEngine.nextExpectedDate(after: after, plan: plan, calendar: la), la)
        XCTAssertEqual([next.month, next.day, next.hour], [6, 4, 9]) // Thursdays: 1 Jan + 22 weeks
        let before = try XCTUnwrap(ScheduleEngine.nextExpectedDate(after: start.addingTimeInterval(-86_400), plan: plan, calendar: la))
        XCTAssertEqual(before, start, "a first dose still ahead is the next one")
        let exactly = try XCTUnwrap(ScheduleEngine.nextExpectedDate(after: start, plan: plan, calendar: la))
        XCTAssertEqual(try parts(exactly, la).day, 8, "a dose at exactly `after` is not after it")
    }
}

/// B13: long daily histories.
@MainActor
final class LowBugPerformanceTests: XCTestCase {
    private func dailyPlan(in context: ModelContext, days: Int) -> MedicationPlan {
        let plan = MedicationPlan(
            medication: .wegovyPill, doseMg: 4,
            scheduleStartDate: Calendar.current.date(byAdding: .day, value: -(days + 5), to: .now)!,
            preferredHour: 9, preferredMinute: 0, intervalDays: 1, waitMinutes: 30, reminderEnabled: false
        )
        context.insert(plan)
        return plan
    }

    func testB13_PlanSaveRecalculationWithAThousandDailyDosesIsFast() throws {
        let container = try ModelContainer(for: GLPModelStore.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let plan = dailyPlan(in: context, days: 1000)
        let calendar = Calendar.current
        let first = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1000, to: .now)!)
        for day in 0..<1000 {
            let at = calendar.date(byAdding: .day, value: day, to: first)!.addingTimeInterval(9 * 3600 + 120)
            context.insert(ShotEvent(timestamp: at, doseMg: 4))
        }
        // A second dose on one day stays a manual extra.
        context.insert(ShotEvent(timestamp: first.addingTimeInterval(9 * 3600 + 3600), doseMg: 4))
        try context.save()

        let started = Date()
        PlanStore.recalculateScheduleMatches(for: plan, in: context)
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertLessThan(elapsed, 2, "recalculation took \(elapsed) s on the main actor")

        let events = try context.fetch(FetchDescriptor<ShotEvent>(sortBy: [SortDescriptor(\.timestamp)]))
        XCTAssertEqual(events.count, 1001)
        XCTAssertEqual(events.filter { $0.scheduleStatus == .extra }.count, 1)
        XCTAssertEqual(events.filter { $0.scheduledDate != nil }.count, 1000)
    }

    func testB13_CSVImportOfAThousandDailyDosesIsFastAndSkipsDuplicates() throws {
        let container = try ModelContainer(for: GLPModelStore.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        _ = dailyPlan(in: context, days: 1000)
        try context.save()
        let calendar = Calendar.current
        let first = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1000, to: .now)!)
        let formatter = ISO8601DateFormatter()
        var csv = "timestamp,medication,dose_mg\n"
        for day in 0..<1000 {
            let at = calendar.date(byAdding: .day, value: day, to: first)!.addingTimeInterval(9 * 3600 + 120)
            csv += "\(formatter.string(from: at)),Wegovy pill,4\n"
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("b13-\(UUID().uuidString).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let started = Date()
        let imported = try ImportService.importEvents(from: url, into: context)
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertEqual(imported, 1000)
        XCTAssertLessThan(elapsed, 2, "import took \(elapsed) s on the main actor")
        XCTAssertEqual(try ImportService.importEvents(from: url, into: context), 0, "rows already stored are skipped")
        let events = try context.fetch(FetchDescriptor<ShotEvent>())
        XCTAssertEqual(events.filter { $0.scheduledDate != nil }.count, 1000)
    }

}

/// B10: the pill wait across midnight.
@MainActor
final class LowBugWaitTests: XCTestCase {
    func testB10_PillWaitSurvivesMidnightOnTheGlanceButNotOnHome() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let taken = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 12, hour: 23, minute: 50)))
        let now = taken.addingTimeInterval(15 * 60)
        let glance = GLPGlance(isPill: true, waitMinutes: 30, lastDoseAt: taken)
        XCTAssertNotNil(glance.waitEndsAt(now: now), "widget and Watch still count down")
        XCTAssertNotNil(DailyAdherence.todaysDose(doseDates: [taken], now: now, calendar: calendar), "Home has lost the dose Home's countdown is built from")
    }
}

/// B7 and B14: the late-dose nudge against the fake notification center.
@MainActor
final class LowBugNudgeTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private let fake = FakeNotificationCenter.shared
    private var savedDefaults: [String: Any] = [:]
    private var absentDefaults: Set<String> = []

    override func setUp() async throws {
        try await super.setUp()
        container = try ModelContainer(
            for: ShotEvent.self, MedicationPlan.self, DoseStep.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        fake.install(status: .authorized)
        StoreService.shared.setLocalOverride(isPro: true)
        setDefault(.proAlertsEnabled, true)
        setDefault(.proAlertQuietHoursEnabled, false)
        setDefault(.patternAlertsEnabled, false)
        await settle(0.8)
        fake.clear()
    }

    override func tearDown() async throws {
        fake.uninstall()
        for (key, value) in savedDefaults { GLPAppGroup.userDefaults.set(value, forKey: key) }
        for key in absentDefaults { GLPAppGroup.userDefaults.removeObject(forKey: key) }
        StoreService.shared.setLocalOverride(isPro: false)
        try await super.tearDown()
    }

    private func setDefault(_ key: GLPStorageKey, _ value: Any?) {
        let defaults = GLPAppGroup.userDefaults
        if savedDefaults[key.rawValue] == nil, !absentDefaults.contains(key.rawValue) {
            if let old = defaults.object(forKey: key.rawValue) { savedDefaults[key.rawValue] = old } else { absentDefaults.insert(key.rawValue) }
        }
        if let value { defaults.set(value, forKey: key.rawValue) } else { defaults.removeObject(forKey: key.rawValue) }
    }

    private func settle(_ seconds: Double = 1.5) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    /// A daily pill plan whose slot was `minutesAgo` minutes ago (today, or yesterday just after midnight).
    private func makeDailyPlan(minutesAgo: Int) throws -> MedicationPlan {
        let calendar = Calendar.current
        let now = Date()
        let slot = now.addingTimeInterval(-TimeInterval(minutesAgo * 60))
        let plan = MedicationPlan(
            medication: .wegovyPill,
            doseMg: 4,
            scheduleStartDate: calendar.date(byAdding: .day, value: -10, to: now)!,
            preferredHour: calendar.component(.hour, from: slot),
            preferredMinute: calendar.component(.minute, from: slot),
            intervalDays: 1,
            waitMinutes: 0,
            reminderEnabled: true
        )
        plan.createdAt = plan.scheduleStartDate
        context.insert(plan)
        try context.save()
        return plan
    }

    private func nudgeFire() -> Date? { fake.fireDate(of: ProactiveAlertsEngine.lateDoseIdentifier) }

    // MARK: B7 a plan save that moves today's dose earlier drops the old nudge

    func testB7_PlanSaveMovingTheDoseFarEarlierCancelsTheOldNudge() async throws {
        let plan = try makeDailyPlan(minutesAgo: 30)
        await ProactiveAlertsEngine.schedulePatternAlertsIfEnabled(in: context)
        XCTAssertNotNil(nudgeFire(), "precondition: a nudge is pending for the first planned time")

        // PlanEditorView.save, with the pill time moved to 5 hours ago: its nudge time has passed.
        let moved = Date().addingTimeInterval(-5 * 3600)
        plan.preferredHour = Calendar.current.component(.hour, from: moved)
        plan.preferredMinute = Calendar.current.component(.minute, from: moved)
        plan.updatedAt = .now
        PlanStore.recalculateScheduleMatches(for: plan, in: context)
        try context.save()
        DoseRoutineService.refresh(in: context)
        await settle()

        XCTAssertNil(nudgeFire(), "the old nudge still names the planned time the customer moved")
    }

    func testB7_ControlAColdLaunchRearmSurvivesTheResumePassThatFollows() async throws {
        _ = try makeDailyPlan(minutesAgo: 6 * 60)
        await ProactiveAlertsEngine.schedulePatternAlertsIfEnabled(in: context)
        XCTAssertNotNil(nudgeFire(), "precondition: the cold-launch pass re-armed the overdue nudge")

        DoseRoutineService.refresh(in: context, mayPrompt: false)
        await settle()
        XCTAssertNotNil(nudgeFire(), "a resume pass must not cancel the re-armed nudge for the same dose")
    }

    // MARK: B14 a pass suspended on the permission check does not add a nudge after the customer lapsed

    func testB14_LateDoseNudgeIsNotAddedAfterTheCustomerResolvesToFree() async throws {
        let plan = try makeDailyPlan(minutesAgo: 30)
        // Launch: entitlements unresolved, so alerts read as on for a Pro-looking customer.
        StoreService.shared.setLocalOverride(isPro: false, resolved: false)
        await settle(0.8)
        fake.clear()
        fake.settingsAnswerDelay = 0.6

        let prefs = ProAlertPreferenceValues.current()
        let pass = Task { @MainActor in
            await ProactiveAlertsEngine.rescheduleLateDoseNudge(plan: plan, events: [], prefs: prefs)
        }
        await settle(0.2)
        // RevenueCat resolves free while the launch pass waits on the permission answer.
        StoreService.shared.setLocalOverride(isPro: false, resolved: true)
        await pass.value
        await settle(1.5)

        XCTAssertNil(nudgeFire(), "a lapsed customer got the Pro nudge back")
    }
}
