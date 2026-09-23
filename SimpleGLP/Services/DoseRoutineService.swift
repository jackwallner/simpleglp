import ActivityKit
import Foundation
import SwiftData
import WidgetKit

/// Everything that follows a logged or removed dose outside the database: the wait
/// countdown (notification + Live Activity), dose and refill reminders, and the glance
/// state the widget and Watch render.
@MainActor
enum DoseRoutineService {
    /// Called right after a dose is saved, before Health context, so the countdown starts
    /// the moment the button is tapped.
    static func didLogDose(at timestamp: Date, plan: MedicationPlan?, in context: ModelContext) {
        publishGlance(in: context)
        guard let plan, plan.effectiveWaitMinutes > 0 else { return }
        let endsAt = timestamp.addingTimeInterval(TimeInterval(plan.effectiveWaitMinutes * 60))
        guard endsAt > .now else { return }
        let name = plan.displayMedicationName
        let minutes = plan.effectiveWaitMinutes
        Task { await ReminderService.scheduleWaitEnd(medicationName: name, waitMinutes: minutes, endsAt: endsAt) }
        if StoreService.shared.isProUnlocked {
            LiveActivityService.startWait(medicationName: name, takenAt: timestamp, endsAt: endsAt)
        }
    }

    /// Called after an undo, delete or edit: drops a countdown that no longer has a dose
    /// behind it and refreshes everything derived from history.
    static func historyDidChange(in context: ModelContext) {
        let glance = publishGlance(in: context)
        if glance.waitEndsAt() == nil {
            ReminderService.cancelWaitEnd()
            LiveActivityService.endAll()
        }
        Task { await rescheduleReminders(in: context) }
    }

    /// Foreground refresh: roll the reminder window forward and clear finished countdowns.
    static func refresh(in context: ModelContext) {
        publishGlance(in: context)
        LiveActivityService.endFinished()
        Task { await rescheduleReminders(in: context) }
    }

    /// After an upgrade mid-countdown, put the running wait on the Lock Screen right away.
    static func startLiveActivityIfWaiting(in context: ModelContext) {
        guard StoreService.shared.isProUnlocked,
              Activity<GLPWaitActivityAttributes>.activities.isEmpty
        else { return }
        let glance = publishGlance(in: context)
        guard let endsAt = glance.waitEndsAt(), let takenAt = glance.lastDoseAt else { return }
        LiveActivityService.startWait(medicationName: glance.medicationName, takenAt: takenAt, endsAt: endsAt)
    }

    static func rescheduleReminders(in context: ModelContext) async {
        guard let plan = PlanStore.currentPlan(in: context) else { return }
        let events = (try? context.fetch(FetchDescriptor<ShotEvent>())) ?? []
        await ReminderService.scheduleNextShotReminder(for: plan, events: events)
        // Before entitlements resolve a Pro user reads as free; leave their refill alert alone.
        guard StoreService.shared.hasResolvedEntitlements else { return }
        await ReminderService.scheduleRefillReminder(for: plan, events: events, isPro: StoreService.shared.isProUnlocked)
    }

    @discardableResult
    static func publishGlance(in context: ModelContext) -> GLPGlance {
        let plan = PlanStore.currentPlan(in: context)
        var descriptor = FetchDescriptor<ShotEvent>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        descriptor.fetchLimit = 1
        let last = (try? context.fetch(descriptor))?.first
        let glance = GLPGlance(
            isPill: plan?.form == .pill,
            medicationName: plan?.displayMedicationName ?? "GLP-1",
            waitMinutes: plan?.effectiveWaitMinutes ?? 0,
            lastDoseAt: last?.timestamp
        )
        GLPGlanceStore.save(glance)
        WidgetCenter.shared.reloadAllTimelines()
        PhoneWatchSession.shared.syncRecentShots()
        return glance
    }
}
