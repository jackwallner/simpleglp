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
        ReminderService.clearDoseNudges()
        guard let plan, plan.effectiveWaitMinutes > 0 else { return }
        let endsAt = timestamp.addingTimeInterval(TimeInterval(plan.effectiveWaitMinutes * 60))
        guard endsAt > .now else { return }
        let name = plan.displayMedicationName
        let minutes = plan.effectiveWaitMinutes
        Task { await ReminderService.scheduleWaitEnd(medicationName: name, waitMinutes: minutes, endsAt: endsAt, takenAt: timestamp) }
        if StoreService.shared.isProUnlocked {
            LiveActivityService.startWait(medicationName: name, takenAt: timestamp, endsAt: endsAt)
        }
    }

    /// Called after an undo, delete or edit: drops a countdown that no longer has a dose
    /// behind it and refreshes everything derived from history.
    static func historyDidChange(in context: ModelContext) {
        rebuildRecentShots(in: context)
        let glance = publishGlance(in: context)
        if let endsAt = glance.waitEndsAt(), let takenAt = glance.lastDoseAt {
            // An edited time moves the countdown: the ping and the Lock Screen follow it.
            Task { await ReminderService.scheduleWaitEnd(medicationName: glance.medicationName, waitMinutes: glance.waitMinutes, endsAt: endsAt, takenAt: takenAt, mayPrompt: false) }
            if StoreService.shared.isProUnlocked {
                LiveActivityService.sync(medicationName: glance.medicationName, takenAt: takenAt, endsAt: endsAt)
            }
        } else {
            ReminderService.cancelWaitEnd()
            LiveActivityService.endAll()
        }
        Task { await rescheduleReminders(in: context, mayPrompt: false) }
    }

    /// Rebuilds the shared recent-doses cache from SwiftData so widget and Watch lists
    /// match the real history after an edit, delete or ingest.
    static func rebuildRecentShots(in context: ModelContext) {
        var descriptor = FetchDescriptor<ShotEvent>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        descriptor.fetchLimit = RecentShotsStore.maxEntries
        let events = (try? context.fetch(descriptor)) ?? []
        RecentShotsStore.replaceAll(events.map {
            RecentShot(
                id: $0.id,
                timestamp: $0.timestamp,
                scheduleStatusRaw: $0.scheduleStatusRaw,
                medicationName: $0.medicationName,
                doseMg: $0.doseMg
            )
        })
        PhoneWatchSession.shared.syncRecentShots()
    }

    /// Roll the reminder window forward and clear finished countdowns. Launch and
    /// foreground pass `mayPrompt: false` so an existing user never gets a cold
    /// notification prompt; onboarding and a plan save may ask.
    static func refresh(in context: ModelContext, mayPrompt: Bool = true) {
        publishGlance(in: context)
        LiveActivityService.endFinished()
        // A pill logged from the Watch, widget, Siri or a notification while the app was in
        // the background couldn't start its Lock Screen countdown; pick it up now.
        startLiveActivityIfWaiting(in: context)
        Task { await rescheduleReminders(in: context, mayPrompt: mayPrompt) }
    }

    /// A dose that already covers `date`: today's pill on a daily plan, or a shot within
    /// the last 12 hours. Hands-free logging (Siri, notification actions) checks this so a
    /// repeated request doesn't write a second dose.
    static func alreadyLogged(at date: Date = .now, in context: ModelContext, calendar: Calendar = .current) -> Date? {
        let isDaily = PlanStore.currentPlan(in: context)?.cadenceDays == 1
        let descriptor = FetchDescriptor<ShotEvent>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        let recent = ((try? context.fetch(descriptor)) ?? []).map(\.timestamp).filter { $0 <= date }
        return recent.first { dose in
            isDaily ? calendar.isDate(dose, inSameDayAs: date) : date.timeIntervalSince(dose) < 12 * 3600
        }
    }

    /// The tail of a log made with no UI in front (a notification action, Siri): the app may
    /// be suspended as soon as this returns, so the wait ping and reminders are awaited
    /// here instead of left to fire-and-forget tasks.
    static func settleBackgroundLog(in context: ModelContext) async {
        let glance = publishGlance(in: context)
        rebuildRecentShots(in: context)
        if let endsAt = glance.waitEndsAt(), let takenAt = glance.lastDoseAt {
            await ReminderService.scheduleWaitEnd(medicationName: glance.medicationName, waitMinutes: glance.waitMinutes, endsAt: endsAt, takenAt: takenAt, mayPrompt: false)
        }
        await rescheduleReminders(in: context, mayPrompt: false)
        await ProactiveAlertsEngine.schedulePatternAlertsIfEnabled(in: context)
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

    static func rescheduleReminders(in context: ModelContext, mayPrompt: Bool = true) async {
        guard let plan = PlanStore.currentPlan(in: context) else { return }
        let events = (try? context.fetch(FetchDescriptor<ShotEvent>())) ?? []
        await ReminderService.scheduleNextShotReminder(for: plan, events: events, mayPrompt: mayPrompt)
        // Before entitlements resolve a Pro user reads as free; leave their refill alert alone.
        guard StoreService.shared.hasResolvedEntitlements else { return }
        await ReminderService.scheduleRefillReminder(for: plan, events: events, isPro: StoreService.shared.isProUnlocked, mayPrompt: mayPrompt)
    }

    @discardableResult
    static func publishGlance(in context: ModelContext) -> GLPGlance {
        let plan = PlanStore.currentPlan(in: context)
        let descriptor = FetchDescriptor<ShotEvent>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        let events = (try? context.fetch(descriptor)) ?? []
        let now = Date()
        let glance = GLPGlance(
            isPill: plan?.form == .pill,
            medicationName: plan?.displayMedicationName ?? "GLP-1",
            waitMinutes: plan?.effectiveWaitMinutes ?? 0,
            lastDoseAt: events.first { $0.timestamp <= now }?.timestamp ?? events.first?.timestamp,
            nextDoseAt: plan.flatMap { ScheduleEngine.nextDue(plan: $0, events: events, now: now) }
        )
        GLPGlanceStore.save(glance)
        WidgetCenter.shared.reloadAllTimelines()
        PhoneWatchSession.shared.syncRecentShots()
        return glance
    }
}
