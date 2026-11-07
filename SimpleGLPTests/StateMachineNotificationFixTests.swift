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
