import Foundation
import UserNotifications

enum ReminderService {
    static let shotReminderIdentifier = "simpleglp.next-shot"

    // `@MainActor`: `MedicationPlan` is a non-Sendable SwiftData model bound to the
    // main actor. Pinning this method to the main actor keeps `plan` from being
    // "sent" across an actor boundary (Swift 6 data-race diagnostic) at the three
    // call sites (onboarding finish, settings save, shot capture).
    @MainActor
    static func scheduleNextShotReminder(for plan: MedicationPlan) async {
        let center = UNUserNotificationCenter.current()
        guard plan.reminderEnabled, let next = ScheduleEngine.nextExpectedDate(plan: plan) else {
            center.removePendingNotificationRequests(withIdentifiers: [shotReminderIdentifier])
            return
        }

        let granted = await ensureAuthorization()
        guard granted else { return }

        center.removePendingNotificationRequests(withIdentifiers: [shotReminderIdentifier])
        let fireDate = next.addingTimeInterval(TimeInterval(-plan.reminderLeadMinutes * 60))
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let content = UNMutableNotificationContent()
        content.title = "Shot day"
        content.body = "Your \(plan.displayMedicationName) dose is planned for today. One tap when it’s done."
        content.sound = .default
        content.threadIdentifier = "shot-reminders"
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: shotReminderIdentifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// True when the user has explicitly denied notifications — used to warn that
    /// reminders won't fire. Does not prompt (unlike `ensureAuthorization`).
    static func isDenied() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .denied
    }

    static func ensureAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        @unknown default:
            return false
        }
    }
}
