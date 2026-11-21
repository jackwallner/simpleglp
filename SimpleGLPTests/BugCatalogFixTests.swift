import HealthKit
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

/// Regressions for the 2026-11-20 bug catalog's low items.
@MainActor
final class LowBugFixTests: XCTestCase {
    private func memoryContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: GLPModelStore.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return container.mainContext
    }

    // MARK: - B5 a past dose the app could not save is reported, not dropped

    func testB5_BackdatedLogWhileACaptureRunsReportsWhyAndWritesNothing() throws {
        let context = try memoryContext()
        let coordinator = ShotCaptureCoordinator()
        coordinator.isCapturing = true
        let failure = coordinator.captureBackdatedShot(in: context, at: Date().addingTimeInterval(-3600))
        XCTAssertNotNil(failure, "the sheet needs a reason to stay open")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ShotEvent>()), 0)
    }

    func testB5_BackdatedLogThatSavesReportsNoFailure() throws {
        let context = try memoryContext()
        let coordinator = ShotCaptureCoordinator()
        let healthKey = GLPStorageKey.healthContextEnabled.rawValue
        let previous = GLPAppGroup.userDefaults.object(forKey: healthKey)
        GLPAppGroup.userDefaults.set(false, forKey: healthKey)
        addTeardownBlock { GLPAppGroup.userDefaults.set(previous, forKey: healthKey) }
        XCTAssertNil(coordinator.captureBackdatedShot(in: context, at: Date().addingTimeInterval(-3600)))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ShotEvent>()), 1)
    }

    // MARK: - B6 empty Health reads stay absent

    func testB6_EmptyHealthReadsAreNotStoredAsZero() throws {
        XCTAssertNil(HealthKitService.sleepHours(from: []), "no sleep samples is no data, not 0 hr")
        XCTAssertNil(HealthKitService.sleepHours(from: nil))
        XCTAssertNil(HealthKitService.workoutCount(from: []))
        XCTAssertNil(HealthKitService.workoutCount(from: nil))
        let snapshot = HealthSnapshot(
            sleepHoursLastNight: HealthKitService.sleepHours(from: []),
            workoutsLast24h: HealthKitService.workoutCount(from: [])
        )
        XCTAssertFalse(snapshot.hasMeaningfulValue, "an all-empty read must not count as captured")
    }

    func testB6_RealSleepAndWorkoutsAreStillCounted() throws {
        let type = try XCTUnwrap(HKObjectType.categoryType(forIdentifier: .sleepAnalysis))
        let end = Date()
        func sample(_ value: HKCategoryValueSleepAnalysis, hours: Double) -> HKCategorySample {
            HKCategorySample(type: type, value: value.rawValue, start: end.addingTimeInterval(-hours * 3600), end: end)
        }
        let samples = [sample(.asleepCore, hours: 4), sample(.asleepREM, hours: 2), sample(.inBed, hours: 9)]
        XCTAssertEqual(try XCTUnwrap(HealthKitService.sleepHours(from: samples)), 6, accuracy: 0.001)
        XCTAssertEqual(HealthKitService.workoutCount(from: samples), 3, "any returned sample counts")
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
