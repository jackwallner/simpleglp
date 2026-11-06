import ObjectiveC
import SwiftData
import UserNotifications
import XCTest
@testable import SimpleGLP

// State machine audit repro suite (2026-11-06). Failing tests are expected: each one
// asserts the behaviour the app promises, after asserting its own preconditions.
// Tests named *Control* must pass.

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

@MainActor
final class StateMachineAuditRepro: XCTestCase {
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

    // MARK: Fake self-check

    func testControlFakeCenterSeesTheNudgeScheduler() async throws {
        let (_, slot) = try makeDailyPlan(minutesAgo: 30)
        await ProactiveAlertsEngine.schedulePatternAlertsIfEnabled(in: context)
        let fire = try XCTUnwrap(nudgeFire(), "fake did not capture the late-dose nudge")
        XCTAssertEqual(fire.timeIntervalSince(slot), 4 * 3600, accuracy: 120)
    }

    // MARK: A1 undo / delete / edit do not restore the late-dose nudge

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

    // MARK: A2 plan save does not retime the nudge

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

    // MARK: A3 permission granted later

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

    // MARK: A4 quiet hours

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
        // Control: a slot whose +4h lands in quiet hours is pushed out of them.
        let pushed = ProactiveAlertsEngine.lateDoseFireDate(for: now.addingTimeInterval(-(3 * 3600 + 50 * 60)), prefs: prefs)
        XCTAssertFalse(prefs.isQuietHour(at: pushed), "control: lateDoseFireDate respects quiet hours")

        let (plan, _) = try makeDailyPlan(minutesAgo: 6 * 60, requireSameDay: false)
        let occurrence = try XCTUnwrap(ProactiveAlertsEngine.nextUnclaimedOccurrence(now: now, plan: plan, events: []))
        XCTAssertLessThan(occurrence, now.addingTimeInterval(-4 * 3600), "precondition: dose is overdue by more than the grace")

        await ProactiveAlertsEngine.rescheduleLateDoseNudge(plan: plan, events: [], prefs: prefs)
        let fire = try XCTUnwrap(nudgeFire())
        XCTAssertFalse(prefs.isQuietHour(at: fire), "nudge scheduled for \(fire), inside quiet hours \(hour):00-\((hour + 2) % 24):00")
    }

    // MARK: A5 a backdated log clears an unrelated snooze

    func testBackdatedLogKeepsTodaysSnoozedReminder() async throws {
        _ = try makeDailyPlan(minutesAgo: 30)
        let content = UNMutableNotificationContent()
        content.title = "Pill time"
        fake.seed(UNNotificationRequest(
            identifier: ReminderService.snoozeIdentifier, content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 900, repeats: false)
        ))
        XCTAssertNotNil(fake.pending[ReminderService.snoozeIdentifier], "precondition: snooze pending")
        XCTAssertNil(ScheduleEngineProbe.todayDose(in: try events()), "precondition: today's pill is not logged")

        // HistoryView > Log a past dose, two days ago.
        let coordinator = ShotCaptureCoordinator()
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        XCTAssertTrue(coordinator.captureShot(in: context, tapDate: twoDaysAgo, deferHealthContext: true))
        XCTAssertNil(ScheduleEngineProbe.todayDose(in: try events()), "precondition: still nothing logged today")
        XCTAssertNotNil(fake.pending[ReminderService.snoozeIdentifier], "today's snoozed reminder was cancelled by a log for another day")
    }

    // MARK: A6 changing the wait does not retime the ping

    func testChangingTheWaitMidCountdownRetimesThePing() async throws {
        StoreService.shared.setLocalOverride(isPro: false) // keep Live Activities out of the test
        await settle(0.8)
        let (plan, _) = try makeDailyPlan(minutesAgo: 5, wait: 30)
        let coordinator = ShotCaptureCoordinator()
        XCTAssertTrue(coordinator.captureShot(in: context, deferHealthContext: true))
        await settle()
        let firstPing = try XCTUnwrap(fake.fireDate(of: ReminderService.waitEndIdentifier), "precondition: ping scheduled")
        let glance1 = GLPGlanceStore.load()
        XCTAssertEqual(try XCTUnwrap(glance1.waitEndsAt()).timeIntervalSince(firstPing), 0, accuracy: 60, "precondition: Home and ping agree")

        // PlanEditorView.save with the wait changed to 10 minutes.
        plan.waitMinutes = 10
        plan.updatedAt = .now
        try context.save()
        DoseRoutineService.refresh(in: context)
        await settle()

        let glance2 = GLPGlanceStore.load()
        let homeEnds = try XCTUnwrap(glance2.waitEndsAt(), "precondition: countdown still running")
        XCTAssertGreaterThan(firstPing.timeIntervalSince(homeEnds), 15 * 60, "precondition: new end is 20 minutes earlier")
        let ping = try XCTUnwrap(fake.fireDate(of: ReminderService.waitEndIdentifier))
        XCTAssertEqual(ping.timeIntervalSince(homeEnds), 0, accuracy: 60, "Home says the wait ends \(homeEnds), the ping fires \(ping)")
    }

    // MARK: B1 time zone: a logged shot reads overdue after travelling west

    func testLoggedShotStaysClaimedAfterTravellingWest() throws {
        var ny = Calendar(identifier: .gregorian)
        ny.timeZone = TimeZone(identifier: "America/New_York")!
        var la = Calendar(identifier: .gregorian)
        la.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        // Thursday 9:00 weekly. Both zones are on daylight time for every date used.
        let start = ny.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 9))!
        let plan = MedicationPlan(medication: .ozempic, doseMg: 0.5, scheduleStartDate: start,
                                  preferredWeekday: 5, preferredHour: 9, preferredMinute: 0, intervalDays: 7)
        let taken = ny.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 9, minute: 5))!
        let match = ScheduleEngine.match(timestamp: taken, plan: plan, existingEvents: [], calendar: ny)
        XCTAssertEqual(match.status, .onSchedule, "precondition: logged on time in New York")
        let event = ShotEvent(timestamp: taken, medicationName: "Ozempic", doseMg: 0.5,
                              scheduledDate: match.scheduledDate, scheduleStatus: match.status,
                              minutesFromSchedule: match.minutesFromSchedule)

        let now = la.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 10))! // Friday morning, Los Angeles
        let nextNY = try XCTUnwrap(ScheduleEngine.nextDue(plan: plan, events: [event], now: now, calendar: ny))
        XCTAssertEqual(nextNY, ny.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 9)),
                       "control: same instant read in New York, next dose is next Thursday")

        let nextLA = try XCTUnwrap(ScheduleEngine.nextDue(plan: plan, events: [event], now: now, calendar: la))
        let headline = HomeView.headline(for: nextLA, now: now, calendar: la)
        XCTAssertEqual(nextLA, la.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 9)),
                       "after flying to Los Angeles the logged shot is not claimed: nextDue = \(nextLA), Home reads \"\(headline)\"")
    }

    func testControlEastwardTravelKeepsTheClaim() throws {
        var la = Calendar(identifier: .gregorian)
        la.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        var ny = Calendar(identifier: .gregorian)
        ny.timeZone = TimeZone(identifier: "America/New_York")!
        let start = la.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 9))!
        let plan = MedicationPlan(medication: .ozempic, doseMg: 0.5, scheduleStartDate: start,
                                  preferredWeekday: 5, preferredHour: 9, preferredMinute: 0, intervalDays: 7)
        let taken = la.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 9, minute: 5))!
        let match = ScheduleEngine.match(timestamp: taken, plan: plan, existingEvents: [], calendar: la)
        let event = ShotEvent(timestamp: taken, medicationName: "Ozempic", doseMg: 0.5,
                              scheduledDate: match.scheduledDate, scheduleStatus: match.status,
                              minutesFromSchedule: match.minutesFromSchedule)
        let now = ny.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 13))!
        let next = try XCTUnwrap(ScheduleEngine.nextDue(plan: plan, events: [event], now: now, calendar: ny))
        XCTAssertEqual(next, ny.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 9)))
    }
}

/// Small helper so tests do not re-implement the daily rule inline.
enum ScheduleEngineProbe {
    static func todayDose(in events: [ShotEvent]) -> Date? {
        events.map(\.timestamp).filter { Calendar.current.isDateInToday($0) && $0 <= Date() }.max()
    }
}
