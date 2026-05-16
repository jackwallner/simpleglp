import SwiftData
import SwiftUI
import WidgetKit

@MainActor
final class ShotCaptureCoordinator: ObservableObject {
    @Published var bannerMessage: String?
    @Published var isCapturing = false
    @Published var lastCapturedEventID: UUID?

    private var isEnrichingPendingLogs = false

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
        lastCapturedEventID = nil
        bannerMessage = "Last shot undone."
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func fetchPendingEvents(in context: ModelContext) -> [ShotEvent] {
        (try? context.fetch(Self.pendingCaptureFetchDescriptor())) ?? []
    }
}
