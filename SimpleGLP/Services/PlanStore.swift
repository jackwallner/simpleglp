import Foundation
import SwiftData

@MainActor
enum PlanStore {
    static func currentPlan(in context: ModelContext) -> MedicationPlan? {
        var descriptor = FetchDescriptor<MedicationPlan>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func ensurePlan(in context: ModelContext) -> MedicationPlan {
        if let plan = currentPlan(in: context) {
            return plan
        }
        let plan = MedicationPlan()
        context.insert(plan)
        try? context.save()
        return plan
    }

    /// Migrate any legacy plans to the unified anchor model. Idempotent and cheap — safe to
    /// run on every launch; only writes when a plan's anchor actually changes.
    static func migrateLegacySchedules(in context: ModelContext) {
        let plans = (try? context.fetch(FetchDescriptor<MedicationPlan>())) ?? []
        let changed = plans.reduce(false) { $0 || $1.normalizeScheduleAnchor() }
        if changed { try? context.save() }
    }

    /// After a delete or an edit frees a slot, a dose that was logged as a manual extra for
    /// it takes the slot. Only extras are re-matched, oldest first; existing claims stay.
    @discardableResult
    static func rematchExtraEvents(in context: ModelContext) -> Bool {
        guard let plan = currentPlan(in: context) else { return false }
        let descriptor = FetchDescriptor<ShotEvent>(sortBy: [SortDescriptor(\.timestamp, order: .forward)])
        let events = (try? context.fetch(descriptor)) ?? []
        var changed = false
        for event in events where event.scheduleStatus == .extra {
            let match = ScheduleEngine.match(timestamp: event.timestamp, plan: plan, existingEvents: events.filter { $0.id != event.id })
            guard match.scheduledDate != nil else { continue }
            event.scheduledDate = match.scheduledDate
            event.scheduleStatus = match.status
            event.minutesFromSchedule = match.minutesFromSchedule
            changed = true
        }
        if changed { try? context.save() }
        return changed
    }

    /// Recomputes stored schedule matches after a plan edit. Events are processed oldest
    /// first so only the first shot can claim a scheduled occurrence; later duplicates remain
    /// manual entries instead of inheriting stale status from the previous plan.
    static func recalculateScheduleMatches(for plan: MedicationPlan, in context: ModelContext) {
        let descriptor = FetchDescriptor<ShotEvent>(sortBy: [SortDescriptor(\.timestamp, order: .forward)])
        let events = (try? context.fetch(descriptor)) ?? []
        var processed: [ShotEvent] = []
        for event in events {
            let match = ScheduleEngine.match(
                timestamp: event.timestamp,
                plan: plan,
                existingEvents: processed
            )
            event.scheduledDate = match.scheduledDate
            event.scheduleStatus = match.status
            event.minutesFromSchedule = match.minutesFromSchedule
            processed.append(event)
        }
    }
}
