import ObjectiveC
import SwiftData
import UserNotifications
import XCTest
@testable import SimpleGLP

// MARK: - Notification center fake (test suite only)

/// Replaces the instance methods of `UNUserNotificationCenter` for the duration of a test,
/// so every scheduler call site in the app talks to an in-memory request table.
final class FakeNotificationCenter: @unchecked Sendable {
    static let shared = FakeNotificationCenter()

    private let lock = NSLock()
    private var requests: [String: UNNotificationRequest] = [:]
    private var addedAt: [String: Date] = [:]
    private var status: UNAuthorizationStatus = .authorized
    private var saved: [(Method, IMP)] = []

    var pending: [String: UNNotificationRequest] { lock.withLock { requests } }
    func added(_ id: String) -> Date? { lock.withLock { addedAt[id] } }
    var authorizationStatus: UNAuthorizationStatus {
        get { lock.withLock { status } }
        set { lock.withLock { status = newValue } }
    }

    /// When a request would fire, from its trigger.
    func fireDate(of id: String) -> Date? {
        guard let request = pending[id] else { return nil }
        if let calendar = request.trigger as? UNCalendarNotificationTrigger {
            return calendar.nextTriggerDate()
        }
        if let interval = request.trigger as? UNTimeIntervalNotificationTrigger, let at = added(id) {
            return at.addingTimeInterval(interval.timeInterval)
        }
        return nil
    }

    func clear() {
        lock.withLock {
            requests = [:]
            addedAt = [:]
        }
    }

    func seed(_ request: UNNotificationRequest) {
        lock.withLock {
            requests[request.identifier] = request
            addedAt[request.identifier] = Date()
        }
    }

    func install(status: UNAuthorizationStatus) {
        lock.withLock {
            requests = [:]
            addedAt = [:]
            self.status = status
        }
        guard saved.isEmpty else { return }
        let cls: AnyClass = UNUserNotificationCenter.self
        func swap(_ name: String, _ block: Any) {
            guard let method = class_getInstanceMethod(cls, NSSelectorFromString(name)) else { return }
            let previous = method_getImplementation(method)
            saved.append((method, previous))
            _ = method_setImplementation(method, imp_implementationWithBlock(block))
        }
        let center = self

        let add: @convention(block) (AnyObject, UNNotificationRequest, (@convention(block) (NSError?) -> Void)?) -> Void = { _, request, done in
            center.lock.withLock {
                center.requests[request.identifier] = request
                center.addedAt[request.identifier] = Date()
            }
            done?(nil)
        }
        swap("addNotificationRequest:withCompletionHandler:", unsafeBitCast(add, to: AnyObject.self))

        let removePending: @convention(block) (AnyObject, NSArray) -> Void = { _, ids in
            center.lock.withLock {
                for case let id as String in ids { center.requests[id] = nil }
            }
        }
        swap("removePendingNotificationRequestsWithIdentifiers:", unsafeBitCast(removePending, to: AnyObject.self))

        let removeDelivered: @convention(block) (AnyObject, NSArray) -> Void = { _, _ in }
        swap("removeDeliveredNotificationsWithIdentifiers:", unsafeBitCast(removeDelivered, to: AnyObject.self))

        let getPending: @convention(block) (AnyObject, @convention(block) (NSArray) -> Void) -> Void = { _, done in
            done(center.lock.withLock { Array(center.requests.values) } as NSArray)
        }
        swap("getPendingNotificationRequestsWithCompletionHandler:", unsafeBitCast(getPending, to: AnyObject.self))

        let getSettings: @convention(block) (AnyObject, @convention(block) (UNNotificationSettings) -> Void) -> Void = { _, done in
            done(FakeSettings.make(status: center.authorizationStatus))
        }
        swap("getNotificationSettingsWithCompletionHandler:", unsafeBitCast(getSettings, to: AnyObject.self))

        let requestAuth: @convention(block) (AnyObject, UInt, @convention(block) (Bool, NSError?) -> Void) -> Void = { _, _, done in
            done(center.authorizationStatus == .authorized, nil)
        }
        swap("requestAuthorizationWithOptions:completionHandler:", unsafeBitCast(requestAuth, to: AnyObject.self))
    }

    func uninstall() {
        for (method, imp) in saved { _ = method_setImplementation(method, imp) }
        saved = []
    }
}

final class FakeSettings: UNNotificationSettings {
    nonisolated(unsafe) static var current: UNAuthorizationStatus = .authorized
    override var authorizationStatus: UNAuthorizationStatus { Self.current }

    static func make(status: UNAuthorizationStatus) -> UNNotificationSettings {
        current = status
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.finishEncoding()
        let unarchiver = try! NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
        unarchiver.requiresSecureCoding = false
        return FakeSettings(coder: unarchiver)!
    }
}

// MARK: - Suite

/// Regression guards for the notification fixes of the 2026-11-06 state machine audit
/// (`project-docs/audits/state-machines-2026-11-06-fixes.md`). The fake swaps the
/// `UNUserNotificationCenter` methods the app uses inside this test process only.

@MainActor
final class StateMachineNotificationFixTests: XCTestCase {
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
        // The host app reacts to the Pro flip with its own scheduler pass; let it finish,
        // then start every test from an empty request table.
        await settle(0.8)
        fake.clear()
    }

    override func tearDown() async throws {
        fake.uninstall()
        for (key, value) in savedDefaults { GLPAppGroup.userDefaults.set(value, forKey: key) }
        for key in absentDefaults { GLPAppGroup.userDefaults.removeObject(forKey: key) }
        savedDefaults = [:]
        absentDefaults = []
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

    /// A daily pill plan whose slot was `minutesAgo` minutes ago today.
    private func makeDailyPlan(minutesAgo: Int, wait: Int = 0, reminders: Bool = true, requireSameDay: Bool = true) throws -> (MedicationPlan, Date) {
        let calendar = Calendar.current
        let now = Date()
        let slot = now.addingTimeInterval(-TimeInterval(minutesAgo * 60))
        if requireSameDay, !calendar.isDate(slot, inSameDayAs: now) { throw XCTSkip("run is within \(minutesAgo) minutes after midnight") }
        let plan = MedicationPlan(
            medication: .wegovyPill,
            doseMg: 4,
            scheduleStartDate: calendar.date(byAdding: .day, value: -10, to: now)!,
            preferredHour: calendar.component(.hour, from: slot),
            preferredMinute: calendar.component(.minute, from: slot),
            intervalDays: 1,
            waitMinutes: wait,
            reminderEnabled: reminders
        )
        context.insert(plan)
        try context.save()
        return (plan, slot)
    }

    private func nudgeFire() -> Date? { fake.fireDate(of: ProactiveAlertsEngine.lateDoseIdentifier) }

    private func events() throws -> [ShotEvent] { try context.fetch(FetchDescriptor<ShotEvent>()) }

    // MARK: S3 undo and delete restore the late-dose nudge

    func testUndoRestoresTheLateDoseNudgeForTheUnloggedDose() async throws {
        let (_, _) = try makeDailyPlan(minutesAgo: 30)
        await ProactiveAlertsEngine.schedulePatternAlertsIfEnabled(in: context)
        let beforeLog = try XCTUnwrap(nudgeFire(), "precondition: nudge scheduled for today's pill")

        let coordinator = ShotCaptureCoordinator()
        XCTAssertTrue(coordinator.captureShot(in: context, deferHealthContext: true))
        await DoseRoutineService.settleBackgroundLog(in: context)
        let afterLog = try XCTUnwrap(nudgeFire(), "precondition: nudge exists after the log")
        XCTAssertGreaterThan(afterLog.timeIntervalSince(beforeLog), 20 * 3600, "precondition: log moves the nudge to tomorrow")

        coordinator.undoLastCapture(in: context)
        await settle()
        XCTAssertEqual(try events().count, 0, "precondition: undo removed the dose")

        let afterUndo = try XCTUnwrap(nudgeFire(), "nudge vanished after undo")
        XCTAssertEqual(
            afterUndo.timeIntervalSince(beforeLog), 0, accuracy: 120,
            "today's pill is unlogged again, nudge should fire at \(beforeLog) but is at \(afterUndo) (log had moved it to \(afterLog))"
        )
    }

    func testControlSchedulerRunningAgainRestoresTheNudgeAfterUndo() async throws {
        _ = try makeDailyPlan(minutesAgo: 30)
        await ProactiveAlertsEngine.schedulePatternAlertsIfEnabled(in: context)
        let beforeLog = try XCTUnwrap(nudgeFire())
        let coordinator = ShotCaptureCoordinator()
        XCTAssertTrue(coordinator.captureShot(in: context, deferHealthContext: true))
        await DoseRoutineService.settleBackgroundLog(in: context)
        coordinator.undoLastCapture(in: context)
        await settle()
        await ProactiveAlertsEngine.schedulePatternAlertsIfEnabled(in: context)
        let restored = try XCTUnwrap(nudgeFire())
        XCTAssertEqual(restored.timeIntervalSince(beforeLog), 0, accuracy: 120)
    }

    func testDeletingTodaysDoseRestoresTheLateDoseNudge() async throws {
        _ = try makeDailyPlan(minutesAgo: 30)
        await ProactiveAlertsEngine.schedulePatternAlertsIfEnabled(in: context)
        let beforeLog = try XCTUnwrap(nudgeFire())
        let coordinator = ShotCaptureCoordinator()
        XCTAssertTrue(coordinator.captureShot(in: context, deferHealthContext: true))
        await DoseRoutineService.settleBackgroundLog(in: context)
        let afterLog = try XCTUnwrap(nudgeFire())
        XCTAssertGreaterThan(afterLog.timeIntervalSince(beforeLog), 20 * 3600, "precondition")

        // HistoryView.performPendingDeletion: delete, save, historyDidChange.
        for event in try events() { context.delete(event) }
        try context.save()
        DoseRoutineService.historyDidChange(in: context)
        await settle()
        XCTAssertEqual(try events().count, 0, "precondition")
        let afterDelete = try XCTUnwrap(nudgeFire())
        XCTAssertEqual(afterDelete.timeIntervalSince(beforeLog), 0, accuracy: 120,
                       "nudge stays at \(afterDelete), should be \(beforeLog)")
    }

    // MARK: S5 a plan save retimes the nudge

    func testPlanSaveRetimesTheLateDoseNudge() async throws {
        let (plan, slot1) = try makeDailyPlan(minutesAgo: 30)
        await ProactiveAlertsEngine.schedulePatternAlertsIfEnabled(in: context)
        let first = try XCTUnwrap(nudgeFire())
        XCTAssertEqual(first.timeIntervalSince(slot1), 4 * 3600, accuracy: 120, "precondition")

        // PlanEditorView.save, with the pill time moved 90 minutes earlier.
        let calendar = Calendar.current
        let slot2 = Date().addingTimeInterval(-120 * 60)
        guard calendar.isDate(slot2, inSameDayAs: Date()) else { throw XCTSkip("within two hours after midnight") }
        plan.preferredHour = calendar.component(.hour, from: slot2)
        plan.preferredMinute = calendar.component(.minute, from: slot2)
        plan.updatedAt = .now
        PlanStore.recalculateScheduleMatches(for: plan, in: context)
        try context.save()
        DoseRoutineService.refresh(in: context)
        await settle()

        let expected = ProactiveAlertsEngine.lateDoseFireDate(
            for: try XCTUnwrap(ScheduleEngine.scheduledDate(onOrBefore: Date(), plan: plan)),
            prefs: ProAlertPreferenceValues.current()
        )
        XCTAssertGreaterThan(abs(expected.timeIntervalSince(first)), 20 * 60, "precondition: edit changes the right answer")
        let after = try XCTUnwrap(nudgeFire())
        XCTAssertEqual(after.timeIntervalSince(expected), 0, accuracy: 120,
                       "nudge still at \(after) (old slot), plan now says \(expected)")
    }

    // MARK: S4 permission granted later reaches the nudge

    func testControlDoseReminderReconcilesWhenPermissionIsGrantedLater() async throws {
        fake.authorizationStatus = .denied
        _ = try makeDailyPlan(minutesAgo: 30)
        DoseRoutineService.refresh(in: context, mayPrompt: false)
        await settle()
        XCTAssertTrue(fake.pending.isEmpty, "precondition: nothing scheduled while denied")
        fake.authorizationStatus = .authorized
        DoseRoutineService.refresh(in: context, mayPrompt: false) // scenePhase == .active
        await settle()
        XCTAssertNotNil(fake.pending[ReminderService.shotReminderIdentifier], "dose reminder should reconcile")
    }

    func testLateDoseNudgeReconcilesWhenPermissionIsGrantedLater() async throws {
        fake.authorizationStatus = .denied
        _ = try makeDailyPlan(minutesAgo: 30)
        DoseRoutineService.refresh(in: context, mayPrompt: false)
        await ProactiveAlertsEngine.schedulePatternAlertsIfEnabled(in: context)
        await settle()
        XCTAssertTrue(fake.pending.isEmpty, "precondition: nothing scheduled while denied")
        XCTAssertTrue(GLPAppGroup.userDefaults.bool(forKey: GLPStorageKey.proAlertsEnabled.rawValue), "precondition: toggle on")

        fake.authorizationStatus = .authorized
        DoseRoutineService.refresh(in: context, mayPrompt: false) // what scenePhase == .active runs
        await settle()
        XCTAssertNotNil(fake.pending[ReminderService.shotReminderIdentifier], "precondition: dose reminder reconciled")
        XCTAssertNotNil(nudgeFire(), "enabled Proactive Alerts nudge never scheduled after permission was granted")
    }

    /// The Home route: "I took my pill", the Health read settles, then "Undo".
    func testHomeUndoAfterHealthSettlesRestoresTodaysNudge() async throws {
        _ = try makeDailyPlan(minutesAgo: 30)
        await ProactiveAlertsEngine.schedulePatternAlertsIfEnabled(in: context)
        let beforeLog = try XCTUnwrap(nudgeFire(), "precondition: nudge scheduled for today's pill")

        let coordinator = ShotCaptureCoordinator()
        XCTAssertTrue(coordinator.captureShot(in: context))
        for _ in 0..<50 where coordinator.isCapturing { await settle(0.2) }
        XCTAssertFalse(coordinator.isCapturing, "precondition: the Health read settled")
        await settle()
        let afterLog = try XCTUnwrap(nudgeFire(), "precondition: nudge exists after the log")
        XCTAssertGreaterThan(afterLog.timeIntervalSince(beforeLog), 20 * 3600, "precondition: log moves the nudge to tomorrow")

        coordinator.undoLastCapture(in: context)
        await settle()
        let afterUndo = try XCTUnwrap(nudgeFire())
        XCTAssertEqual(afterUndo.timeIntervalSince(beforeLog), 0, accuracy: 120,
                       "after Home Undo the nudge stays at \(afterUndo), today's would be \(beforeLog)")
    }

    /// A resume or history change while the dose is long overdue does not repeat the nudge
    /// a minute later (product call 9 stays with the cold-launch pass).
    func testControlResumeDoesNotRearmAPastDueNudge() async throws {
        _ = try makeDailyPlan(minutesAgo: 6 * 60, requireSameDay: false)
        DoseRoutineService.refresh(in: context, mayPrompt: false)
        await settle()
        XCTAssertNotNil(fake.pending[ReminderService.shotReminderIdentifier], "precondition: the resume pass ran")
        XCTAssertNil(nudgeFire(), "a resume re-armed the overdue nudge at now + 60 s")
    }

    // MARK: S2 the late-dose nudge respects quiet hours when re-armed

    func testLateDoseNudgeNeverFiresInsideQuietHours() async throws {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let prefs = ProAlertPreferenceValues(
            alertsEnabled: true, quietHoursEnabled: true,
            quietHoursStart: hour, quietHoursEnd: (hour + 2) % 24,
            patternAlertsEnabled: false, patternAlertSensitivity: 0
        )
        XCTAssertTrue(prefs.isQuietHour(at: now), "precondition: now is inside quiet hours")
        let pushed = ProactiveAlertsEngine.lateDoseFireDate(for: now.addingTimeInterval(-(3 * 3600 + 50 * 60)), prefs: prefs)
        XCTAssertFalse(prefs.isQuietHour(at: pushed), "control: lateDoseFireDate respects quiet hours")

        let (plan, _) = try makeDailyPlan(minutesAgo: 6 * 60, requireSameDay: false)
        let occurrence = try XCTUnwrap(ProactiveAlertsEngine.nextUnclaimedOccurrence(now: now, plan: plan, events: []))
        XCTAssertLessThan(occurrence, now.addingTimeInterval(-4 * 3600), "precondition: dose is overdue by more than the grace")

        await ProactiveAlertsEngine.rescheduleLateDoseNudge(plan: plan, events: [], prefs: prefs)
        let fire = try XCTUnwrap(nudgeFire())
        XCTAssertFalse(prefs.isQuietHour(at: fire), "nudge scheduled for \(fire), inside quiet hours \(hour):00-\((hour + 2) % 24):00")
        XCTAssertGreaterThan(fire, now, "the nudge is still ahead")
    }

    /// The cold-launch pass (`SimpleGLPApp` on resolved entitlements) with quiet hours read
    /// from the stored preferences.
    func testColdLaunchPassKeepsTheNudgeOutOfQuietHours() async throws {
        let hour = Calendar.current.component(.hour, from: Date())
        setDefault(.proAlertQuietHoursEnabled, true)
        setDefault(.proAlertQuietStartHour, hour)
        setDefault(.proAlertQuietEndHour, (hour + 2) % 24)
        _ = try makeDailyPlan(minutesAgo: 6 * 60, requireSameDay: false)
        await ProactiveAlertsEngine.schedulePatternAlertsIfEnabled(in: context)
        let prefs = ProAlertPreferenceValues.current()
        XCTAssertTrue(prefs.isQuietHour(at: Date()), "precondition: now is inside quiet hours")
        let fire = try XCTUnwrap(nudgeFire(), "precondition: the overdue dose gets a nudge")
        XCTAssertFalse(prefs.isQuietHour(at: fire), "scheduled the nudge at \(fire), inside quiet hours")
    }

    // MARK: S9 removing the claiming dose hands its slot to the same-week duplicate

    /// Weekly, with this week's slot `hoursAgo` hours ago, and two logs for it.
    private func weeklyWithDuplicate(hoursAgo: Int) throws -> (first: ShotEvent, second: ShotEvent, coordinator: ShotCaptureCoordinator) {
        let calendar = Calendar.current
        let slot = Date().addingTimeInterval(-TimeInterval(hoursAgo * 3600))
        let plan = MedicationPlan(
            medication: .ozempic, doseMg: 0.5,
            scheduleStartDate: calendar.date(byAdding: .day, value: -21, to: slot)!,
            preferredHour: calendar.component(.hour, from: slot),
            preferredMinute: calendar.component(.minute, from: slot),
            intervalDays: 7
        )
        context.insert(plan)
        try context.save()
        let coordinator = ShotCaptureCoordinator()
        XCTAssertTrue(coordinator.captureShot(in: context, tapDate: slot.addingTimeInterval(5 * 60), deferHealthContext: true))
        XCTAssertTrue(coordinator.captureShot(in: context, tapDate: slot.addingTimeInterval(2 * 3600), deferHealthContext: true))
        let all = try events().sorted { $0.timestamp < $1.timestamp }
        XCTAssertEqual(all.count, 2, "precondition")
        XCTAssertEqual(all[0].scheduleStatus, .onSchedule, "precondition: the first log claims the slot")
        XCTAssertEqual(all[1].scheduleStatus, .extra, "precondition: the second reads Manual")
        return (all[0], all[1], coordinator)
    }

    func testDeletingClaimingShotHandsTheSlotToTheSameWeekSibling() async throws {
        let (first, second, _) = try weeklyWithDuplicate(hoursAgo: 3)
        // HistoryView.performPendingDeletion
        context.delete(first)
        try context.save()
        DoseRoutineService.historyDidChange(in: context)
        await settle()
        XCTAssertEqual(second.scheduleStatus, .onSchedule, "the surviving dose still reads Manual")
        XCTAssertNotNil(second.scheduledDate)
    }

    func testUndoOfTheClaimingShotHandsTheSlotToTheSibling() async throws {
        let (first, second, coordinator) = try weeklyWithDuplicate(hoursAgo: 3)
        // Undo targets the last capture; point it at the claiming one as a later ingest would not.
        coordinator.lastCapturedEventID = first.id
        coordinator.undoLastCapture(in: context)
        await settle()
        XCTAssertEqual(second.scheduleStatus, .onSchedule)
    }

    func testControlExistingClaimsAreLeftAlone() async throws {
        let (first, second, _) = try weeklyWithDuplicate(hoursAgo: 3)
        DoseRoutineService.historyDidChange(in: context)
        await settle()
        XCTAssertEqual(first.scheduleStatus, .onSchedule)
        XCTAssertEqual(second.scheduleStatus, .extra, "the slot is still claimed")
    }

    // MARK: S7 a backdated log keeps today's snoozed reminder

    /// "Remind me in 15 min" on today's pill reminder, through the real handler.
    private func snoozeTodaysReminder(plan: MedicationPlan) async throws {
        let content = UNMutableNotificationContent()
        (content.title, content.body) = ReminderService.doseReminderText(for: plan)
        await ReminderService.snooze(content)
        XCTAssertNotNil(fake.pending[ReminderService.snoozeIdentifier], "precondition: snooze pending")
        XCTAssertNil(ScheduleEngineProbe.todayDose(in: try events()), "precondition: today's pill is not logged")
    }

    func testBackdatedLogKeepsTodaysSnoozedReminder() async throws {
        let (plan, _) = try makeDailyPlan(minutesAgo: 30)
        try await snoozeTodaysReminder(plan: plan)
        // History > Log a past dose, two days ago.
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        XCTAssertTrue(ShotCaptureCoordinator().captureShot(in: context, tapDate: twoDaysAgo, deferHealthContext: true))
        XCTAssertNil(ScheduleEngineProbe.todayDose(in: try events()), "precondition: still nothing logged today")
        XCTAssertNotNil(fake.pending[ReminderService.snoozeIdentifier], "today's snoozed reminder was cancelled by a log for another day")
    }

    func testControlLoggingTodaysDoseClearsTheSnooze() async throws {
        let (plan, _) = try makeDailyPlan(minutesAgo: 30)
        try await snoozeTodaysReminder(plan: plan)
        XCTAssertTrue(ShotCaptureCoordinator().captureShot(in: context, deferHealthContext: true))
        XCTAssertNil(fake.pending[ReminderService.snoozeIdentifier], "the snooze for the dose just logged is stale")
    }

    // MARK: S8 changing the wait mid-countdown retimes the ping

    private func changeWaitMidCountdown(from old: Int, to new: Int) async throws -> (homeEnds: Date, ping: Date) {
        StoreService.shared.setLocalOverride(isPro: false) // keep Live Activities out of the test
        await settle(0.8)
        let (plan, _) = try makeDailyPlan(minutesAgo: 5, wait: old)
        let coordinator = ShotCaptureCoordinator()
        XCTAssertTrue(coordinator.captureShot(in: context, deferHealthContext: true))
        await settle()
        let firstPing = try XCTUnwrap(fake.fireDate(of: ReminderService.waitEndIdentifier), "precondition: ping scheduled")
        XCTAssertEqual(try XCTUnwrap(GLPGlanceStore.load().waitEndsAt()).timeIntervalSince(firstPing), 0, accuracy: 60, "precondition: Home and ping agree")

        // PlanEditorView.save with the new wait.
        plan.waitMinutes = new
        plan.updatedAt = .now
        try context.save()
        DoseRoutineService.refresh(in: context)
        await settle()

        let homeEnds = try XCTUnwrap(GLPGlanceStore.load().waitEndsAt(), "precondition: countdown still running")
        XCTAssertGreaterThan(abs(firstPing.timeIntervalSince(homeEnds)), 15 * 60, "precondition: the edit moves the end")
        let ping = try XCTUnwrap(fake.fireDate(of: ReminderService.waitEndIdentifier))
        return (homeEnds, ping)
    }

    func testShorteningTheWaitMidCountdownRetimesThePing() async throws {
        let (homeEnds, ping) = try await changeWaitMidCountdown(from: 30, to: 10)
        XCTAssertEqual(ping.timeIntervalSince(homeEnds), 0, accuracy: 60, "Home says the wait ends \(homeEnds), the ping fires \(ping)")
    }

    func testLengtheningTheWaitMidCountdownRetimesThePing() async throws {
        let (homeEnds, ping) = try await changeWaitMidCountdown(from: 30, to: 60)
        XCTAssertEqual(ping.timeIntervalSince(homeEnds), 0, accuracy: 60, "the wait-over ping fires at \(ping), before Home's end \(homeEnds)")
    }

    func testSwitchingThePlanToAShotDropsThePing() async throws {
        StoreService.shared.setLocalOverride(isPro: false)
        await settle(0.8)
        let (plan, _) = try makeDailyPlan(minutesAgo: 5, wait: 30)
        XCTAssertTrue(ShotCaptureCoordinator().captureShot(in: context, deferHealthContext: true))
        await settle()
        XCTAssertNotNil(fake.pending[ReminderService.waitEndIdentifier], "precondition: ping scheduled")
        plan.medication = .ozempic
        plan.intervalDays = 7
        plan.updatedAt = .now
        try context.save()
        DoseRoutineService.refresh(in: context)
        await settle()
        XCTAssertNil(fake.pending[ReminderService.waitEndIdentifier], "a shot plan has no wait, the pill's ping is stale")
    }
}

/// Small helper so tests do not re-implement the daily rule inline.
enum ScheduleEngineProbe {
    static func todayDose(in events: [ShotEvent]) -> Date? {
        events.map(\.timestamp).filter { Calendar.current.isDateInToday($0) && $0 <= Date() }.max()
    }
}
