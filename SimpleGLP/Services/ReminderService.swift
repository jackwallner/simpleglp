import Foundation
import SwiftData
import UserNotifications

enum ReminderService {
    static let shotReminderIdentifier = "simpleglp.next-shot"
    static let waitEndIdentifier = "simpleglp.wait-end"
    static let refillIdentifier = "simpleglp.refill"
    static let snoozeIdentifier = "simpleglp.snooze"
    /// Dose reminders and the late-dose nudge carry "Took it" and "Snooze" so the dose can
    /// be logged straight from the Lock Screen.
    static let doseCategory = "simpleglp.dose"
    static let tookItAction = "simpleglp.took-it"
    static let snoozeAction = "simpleglp.snooze"
    static let snoozeMinutes = 15
    /// Daily plans queue two weeks of reminders so they keep firing if the app isn't opened.
    static let dailyReminderSlots = 14

    static var doseReminderIdentifiers: [String] {
        [shotReminderIdentifier] + (1..<dailyReminderSlots).map { "\(shotReminderIdentifier)-\($0)" }
    }

    static func cancelDoseReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: doseReminderIdentifiers)
    }

    static func registerCategories() {
        let tookIt = UNNotificationAction(identifier: tookItAction, title: "Took it", options: [], icon: UNNotificationActionIcon(systemImageName: "checkmark.circle"))
        let snooze = UNNotificationAction(identifier: snoozeAction, title: "Remind me in \(snoozeMinutes) min", options: [], icon: UNNotificationActionIcon(systemImageName: "clock"))
        let category = UNNotificationCategory(identifier: doseCategory, actions: [tookIt, snooze], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Once a dose is logged, its reminders are stale: drop them from Notification Center
    /// along with any snoozed repeat.
    static func clearDoseNudges() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [snoozeIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: doseReminderIdentifiers + [snoozeIdentifier, ProactiveAlertsEngine.lateDoseIdentifier])
    }

    /// Re-sends a dose reminder `snoozeMinutes` from now.
    static func snooze(_ content: UNNotificationContent) async {
        guard let copy = content.mutableCopy() as? UNMutableNotificationContent else { return }
        copy.categoryIdentifier = doseCategory
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(snoozeMinutes * 60), repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: snoozeIdentifier, content: copy, trigger: trigger))
    }

    // `@MainActor`: `MedicationPlan` is a non-Sendable SwiftData model bound to the
    // main actor. Pinning this method to the main actor keeps `plan` from being
    // "sent" across an actor boundary (Swift 6 data-race diagnostic).
    @MainActor
    static func scheduleNextShotReminder(for plan: MedicationPlan, in context: ModelContext) async {
        let events = (try? context.fetch(FetchDescriptor<ShotEvent>())) ?? []
        await scheduleNextShotReminder(for: plan, events: events)
    }

    @MainActor
    static func scheduleNextShotReminder(for plan: MedicationPlan, events: [ShotEvent], mayPrompt: Bool = true) async {
        cancelDoseReminders()
        let now = Date()
        let lead = TimeInterval(plan.reminderLeadMinutes * 60)
        let fireDates = upcomingReminderSlots(plan: plan, events: events, now: now)
            .map { $0.addingTimeInterval(-lead) }
            .filter { $0 > now }
        guard plan.reminderEnabled, !fireDates.isEmpty else { return }

        let granted = await ensureAuthorization(mayPrompt: mayPrompt)
        guard granted else { return }

        let center = UNUserNotificationCenter.current()
        for (index, fireDate) in fireDates.enumerated() {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let content = UNMutableNotificationContent()
            if plan.form == .pill {
                content.title = "Pill time"
                content.body = "Time for your \(plan.displayMedicationName). One tap when it’s done."
            } else {
                content.title = "Shot day"
                content.body = "Your \(plan.displayMedicationName) dose is planned for today. One tap when it’s done."
            }
            content.sound = .default
            content.threadIdentifier = "shot-reminders"
            content.categoryIdentifier = doseCategory
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: doseReminderIdentifiers[index], content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    /// Upcoming scheduled doses nobody has logged yet. A pill taken before its reminder
    /// time claims that day's slot, so the reminder for it is skipped.
    @MainActor
    static func upcomingReminderSlots(plan: MedicationPlan, events: [ShotEvent], now: Date = .now, calendar: Calendar = .current) -> [Date] {
        let limit = plan.cadenceDays == 1 ? dailyReminderSlots : 2
        var slots: [Date] = []
        var cursor = ScheduleEngine.nextExpectedDate(after: now, plan: plan, calendar: calendar)
        while let slot = cursor, slots.count < limit {
            if !ProactiveAlertsEngine.isOccurrenceClaimed(slot, by: events) {
                slots.append(slot)
            }
            cursor = calendar.date(byAdding: .day, value: plan.cadenceDays, to: slot)
        }
        return slots
    }

    /// "Wait's over" alert at the end of the countdown a pill starts.
    static func scheduleWaitEnd(medicationName: String, waitMinutes: Int, endsAt: Date, takenAt: Date, mayPrompt: Bool = true) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [waitEndIdentifier])
        guard waitMinutes > 0, endsAt > .now else { return }
        let granted = await ensureAuthorization(mayPrompt: mayPrompt)
        guard granted else { return }
        let content = UNMutableNotificationContent()
        content.title = "Your \(waitMinutes)-minute wait is over"
        content.body = "\(medicationName) taken at \(takenAt.formatted(date: .omitted, time: .shortened))."
        content.sound = .default
        content.threadIdentifier = "wait-timer"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, endsAt.timeIntervalSinceNow), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: waitEndIdentifier, content: content, trigger: trigger))
    }

    static func cancelWaitEnd() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [waitEndIdentifier])
    }

    /// Pro: a heads-up `SupplyMath.reminderLeadDays` before logged doses use up the supply.
    @MainActor
    static func scheduleRefillReminder(for plan: MedicationPlan, events: [ShotEvent], isPro: Bool, mayPrompt: Bool = true) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [refillIdentifier])
        guard isPro,
              let remaining = SupplyMath.remaining(plan: plan, doseDates: events.map(\.timestamp)),
              let fireDate = SupplyMath.reminderDate(remaining: remaining, plan: plan)
        else { return }
        let granted = await ensureAuthorization(mayPrompt: mayPrompt)
        guard granted else { return }
        let content = UNMutableNotificationContent()
        content.title = "Refill soon"
        content.body = "About \(SupplyMath.reminderLeadDays) days of \(plan.displayMedicationName) left, based on what you’ve logged."
        content.sound = .default
        content.threadIdentifier = "refill"
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: refillIdentifier, content: content, trigger: trigger))
    }

    /// True when the user has explicitly denied notifications — used to warn that
    /// reminders won't fire. Does not prompt (unlike `ensureAuthorization`).
    static func isDenied() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .denied
    }

    /// `mayPrompt: false` is for background refreshes (launch, foreground, entitlement
    /// changes): they schedule only when already allowed, so the system prompt only ever
    /// follows something the user did.
    static func ensureAuthorization(mayPrompt: Bool = true) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            guard mayPrompt else { return false }
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        @unknown default:
            return false
        }
    }
}
