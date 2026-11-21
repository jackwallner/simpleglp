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
}
