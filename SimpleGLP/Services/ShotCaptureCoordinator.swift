import SwiftData
import SwiftUI
import WidgetKit

@MainActor
final class ShotCaptureCoordinator: ObservableObject {
    @Published var bannerMessage: String?
    @Published var isCapturing = false
    @Published var lastCapturedEventID: UUID?
    @Published var showUndoOption = false

    private var isEnrichingPendingLogs = false

    /// Pulls a shot logged from the Home Screen widget into SwiftData. The widget only writes a
    /// timestamp into the app group (it has no database access), so the shot isn't real until the
    /// app ingests it here. Returns true if a pending widget shot was captured.
    @discardableResult
    func ingestPendingWidgetShot(in context: ModelContext) -> Bool {
        let defaults = GLPAppGroup.userDefaults
        let key = "pendingWidgetShotTimestamp"
        let raw = defaults.double(forKey: key)
        guard raw > 0 else { return false }
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: "pendingWidgetShotMessage")

        let captured = captureShot(in: context, tapDate: Date(timeIntervalSince1970: raw))
        if captured {
            rebuildRecentShots(in: context)
        }
        return captured
    }

    /// Rebuilds the shared recent-shots cache from SwiftData so widget/watch displays match the
    /// real history (and any placeholder entry the widget wrote gets replaced).
    func rebuildRecentShots(in context: ModelContext) {
        var descriptor = FetchDescriptor<ShotEvent>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        descriptor.fetchLimit = RecentShotsStore.maxEntries
        let events = (try? context.fetch(descriptor)) ?? []
        let shots = events.map {
            RecentShot(
                id: $0.id,
                timestamp: $0.timestamp,
                scheduleStatusRaw: $0.scheduleStatusRaw,
                medicationName: $0.medicationName,
                doseMg: $0.doseMg
            )
        }
        RecentShotsStore.replaceAll(shots)
        PhoneWatchSession.shared.syncRecentShots()
    }

    func enrichPendingCapturesIfNeeded(in context: ModelContext) {
        guard !isCapturing, !isEnrichingPendingLogs else { return }
        let pending = fetchPendingEvents(in: context)
        guard !pending.isEmpty else { return }

        isEnrichingPendingLogs = true
        Task { @MainActor in
            defer { isEnrichingPendingLogs = false }
            var updated = 0
            for event in pending {
                let health = await HealthKitService.shared.captureSnapshot(at: event.timestamp)
                event.apply(health)
                event.finalizeCapture()
                do {
                    try context.save()
                    updated += 1
                } catch {
                    bannerMessage = "Saved, but Health context could not be updated."
                }
            }
            if updated > 0 {
                bannerMessage = updated == 1 ? "Updated context for a pending shot." : "Updated context for \(updated) pending shots."
                WidgetCenter.shared.reloadAllTimelines()
                await ProactiveAlertsEngine.schedulePatternAlertsIfEnabled(in: context)
            }
        }
    }

    nonisolated static func pendingCaptureFetchDescriptor() -> FetchDescriptor<ShotEvent> {
        let healthPending = GLPWidgetQuickLog.healthMessagePending
        let pendingRaw = CaptureSourceStatus.pending.rawValue
        return FetchDescriptor<ShotEvent>(
            predicate: #Predicate { event in
                event.healthStatusRaw == pendingRaw || event.healthStatusMessage == healthPending
            },
            sortBy: [SortDescriptor(\ShotEvent.timestamp, order: .forward)]
        )
    }

    @discardableResult
    func captureShot(in context: ModelContext, tapDate: Date? = nil) -> Bool {
        let timestamp = tapDate ?? .now
        let plan = PlanStore.currentPlan(in: context)
        let events = (try? context.fetch(FetchDescriptor<ShotEvent>())) ?? []
        let isFirstShot = events.isEmpty
        let match = ScheduleEngine.match(timestamp: timestamp, plan: plan, existingEvents: events)
        let event = ShotEvent(
            timestamp: timestamp,
            medicationName: plan?.displayMedicationName ?? "GLP-1",
            doseMg: match.doseMg,
            scheduledDate: match.scheduledDate,
            scheduleStatus: match.status,
            minutesFromSchedule: match.minutesFromSchedule
        )
        context.insert(event)
        lastCapturedEventID = event.id

        do {
            try context.save()
        } catch {
            lastCapturedEventID = nil
            bannerMessage = "Could not save your shot. Try again."
            return false
        }

        ReviewPromptTracker.recordPositiveMoment()
        NotificationCenter.default.post(name: .glpPositiveMomentForReview, object: nil)
        if isFirstShot {
            NotificationCenter.default.post(name: .glpFirstShotLogged, object: nil)
        }

        showUndoOption = true

        RecentShotsStore.record(
            RecentShot(
                id: event.id,
                timestamp: event.timestamp,
                scheduleStatusRaw: event.scheduleStatusRaw,
                medicationName: event.medicationName,
                doseMg: event.doseMg
            )
        )
        PhoneWatchSession.shared.syncRecentShots()

        isCapturing = true
        bannerMessage = "Saved. Adding Health context…"
        let eventID = event.id

        Task { @MainActor in
            let health = await HealthKitService.shared.captureSnapshot(at: timestamp)
            var descriptor = FetchDescriptor<ShotEvent>(predicate: #Predicate { $0.id == eventID })
            descriptor.fetchLimit = 1
            guard let found = try? context.fetch(descriptor).first else {
                isCapturing = false
                bannerMessage = "Saved, but could not update context."
                return
            }

            found.apply(health)
            found.finalizeCapture()
            do {
                try context.save()
            } catch {
                isCapturing = false
                bannerMessage = "Context captured but save failed. Reopen to retry."
                return
            }

            isCapturing = false
            switch found.captureStatus {
            case .complete:
                bannerMessage = "You took your shot. Nice. See you next week."
            case .partial:
                bannerMessage = "Shot logged. Some Health context was unavailable."
            case .failed:
                bannerMessage = "Shot logged. Health context was unavailable."
            case .pending:
                bannerMessage = nil
            }
            WidgetCenter.shared.reloadAllTimelines()
            if let plan {
                await ReminderService.scheduleNextShotReminder(for: plan)
            }
            await ProactiveAlertsEngine.schedulePatternAlertsIfEnabled(in: context)
        }

        return true
    }

    func undoLastCapture(in context: ModelContext) {
        guard let eventID = lastCapturedEventID else { return }
        var descriptor = FetchDescriptor<ShotEvent>(predicate: #Predicate { $0.id == eventID })
        descriptor.fetchLimit = 1
        if let event = try? context.fetch(descriptor).first {
            context.delete(event)
            try? context.save()
        }
        RecentShotsStore.remove(id: eventID)
        PhoneWatchSession.shared.syncRecentShots()
        lastCapturedEventID = nil
        showUndoOption = false
        bannerMessage = "Last shot undone."
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func fetchPendingEvents(in context: ModelContext) -> [ShotEvent] {
        (try? context.fetch(Self.pendingCaptureFetchDescriptor())) ?? []
    }
}
