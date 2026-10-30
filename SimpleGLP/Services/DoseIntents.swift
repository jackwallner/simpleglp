import AppIntents
import Foundation
import SwiftData

/// Hands-free logging for Siri, the Action Button, Spotlight and Shortcuts automations
/// (an NFC tag on the pill bottle, say). Runs in the background without opening the app.
/// `LiveActivityIntent` lets it start the Pro Lock Screen countdown from there.
struct LogDoseIntent: AppIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Log My Dose"
    static let description = IntentDescription("Logs your GLP-1 shot or pill as taken now. On a pill with a wait, it starts the countdown.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = GLPModelStore.sharedModelContainer.mainContext
        guard GLPOnboardingStore.hasCompletedOnboarding, PlanStore.currentPlan(in: context) != nil else {
            return .result(dialog: "Open Simple GLP to set up your medication first.")
        }
        if let existing = DoseRoutineService.alreadyLogged(in: context) {
            let when = existing.formatted(date: .omitted, time: .shortened)
            return .result(dialog: "Your dose is already logged, at \(when). Nothing new was added.")
        }
        guard ShotCaptureCoordinator().captureShot(in: context, deferHealthContext: true) else {
            return .result(dialog: "That didn’t save. Open Simple GLP and try again.")
        }
        await DoseRoutineService.settleBackgroundLog(in: context)
        if !StoreService.shared.hasResolvedEntitlements {
            await StoreService.shared.updateCustomerProductStatus(fetchPolicy: .cachedOrFetched)
        }
        DoseRoutineService.startLiveActivityIfWaiting(in: context)
        return .result(dialog: "\(DoseSpeech.afterLog(glance: GLPGlanceStore.load()))")
    }
}

/// "When's my next dose?" / "How long is my wait?"
struct DoseStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Check My Dose"
    static let description = IntentDescription("Tells you when your wait ends or when your next dose is planned.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = GLPModelStore.sharedModelContainer.mainContext
        guard PlanStore.currentPlan(in: context) != nil, GLPOnboardingStore.hasCompletedOnboarding else {
            return .result(dialog: "Open Simple GLP to set up your medication first.")
        }
        let glance = DoseRoutineService.publishGlance(in: context)
        return .result(dialog: "\(DoseSpeech.status(glance: glance))")
    }
}

struct SimpleGLPShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogDoseIntent(),
            phrases: [
                "Log my dose in \(.applicationName)",
                "I took my pill in \(.applicationName)",
                "I took my shot in \(.applicationName)",
                "Log my \(.applicationName) dose"
            ],
            shortTitle: "Log Dose",
            systemImageName: "checkmark.circle.fill"
        )
        AppShortcut(
            intent: DoseStatusIntent(),
            phrases: [
                "When is my next dose in \(.applicationName)",
                "Check my wait in \(.applicationName)",
                "Check \(.applicationName)"
            ],
            shortTitle: "Next Dose",
            systemImageName: "clock"
        )
    }
}

/// What Siri says back. Plain facts about what the user logged and planned, never advice.
enum DoseSpeech {
    static func afterLog(glance: GLPGlance, now: Date = .now) -> String {
        let fullName = glance.localizedMedicationName
        if let end = glance.waitEndsAt(now: now) {
            return String(localized: "Logged your \(fullName). Your \(glance.waitMinutes)-minute wait ends at \(time(end)).")
        }
        guard let next = glance.upcomingDose(now: now) else { return String(localized: "Logged your \(fullName).") }
        let name = medicationName(for: glance)
        if glance.isPill {
            return String(localized: "Logged your \(name). Next pill is \(day(next, now: now)) at \(time(next)).")
        }
        return String(localized: "Logged your \(name). Next shot is \(day(next, now: now)) at \(time(next)).")
    }

    static func afterLog(glance: GLPGlance, noun: String, now: Date = .now) -> String {
        afterLog(glance: glance, now: now)
    }

    static func status(glance: GLPGlance, now: Date = .now, calendar: Calendar = .current) -> String {
        let fullName = glance.localizedMedicationName
        if let end = glance.waitEndsAt(now: now) {
            let minutes = max(1, Int((end.timeIntervalSince(now) / 60).rounded(.up)))
            let remainingText = GLPDurationText.format(seconds: TimeInterval(minutes * 60), units: [.minute], style: .abbreviated)
            return String(localized: "Your wait ends at \(time(end)), \(remainingText) from now.")
        }
        if glance.isPill, glance.takenToday(now: now, calendar: calendar), let last = glance.lastDoseAt {
            return String(localized: "You logged your \(fullName) today at \(time(last)).")
        }
        guard let next = glance.upcomingDose(now: now, calendar: calendar) else {
            return String(localized: "Nothing is planned yet. Set your schedule in Simple GLP.")
        }
        if next < now {
            let name = medicationName(for: glance)
            if glance.isPill {
                return String(localized: "Your \(name) pill was planned for \(day(next, now: now)) at \(time(next)) and isn’t logged yet.")
            }
            return String(localized: "Your \(name) shot was planned for \(day(next, now: now)) at \(time(next)) and isn’t logged yet.")
        }
        let name = medicationName(for: glance)
        if glance.isPill {
            return String(localized: "Your next \(name) pill is \(day(next, now: now)) at \(time(next)).")
        }
        return String(localized: "Your next \(name) shot is \(day(next, now: now)) at \(time(next)).")
    }

    static func status(glance: GLPGlance, noun: String, now: Date = .now, calendar: Calendar = .current) -> String {
        status(glance: glance, now: now, calendar: calendar)
    }

    private static func medicationName(for glance: GLPGlance) -> String {
        let storedName = glance.medicationName
        let form = glance.isPill ? " pill" : " shot"
        guard storedName.localizedCaseInsensitiveHasSuffix(form) else {
            return glance.localizedMedicationName
        }
        let baseName = String(storedName.dropLast(form.count))
        return GLPGlance.localizedMedicationName(forStoredValue: baseName)
    }

    private static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private static func day(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return String(localized: "today") }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return String(localized: "tomorrow")
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return String(localized: "yesterday")
        }
        let days = abs(calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0)
        return days < 7 ? date.formatted(.dateTime.weekday(.wide)) : date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}

private extension String {
    func localizedCaseInsensitiveHasSuffix(_ suffix: String) -> Bool {
        guard count >= suffix.count else { return false }
        return lowercased().hasSuffix(suffix.lowercased())
    }
}
