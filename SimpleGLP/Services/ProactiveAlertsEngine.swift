import Foundation
import SwiftData
import UserNotifications

enum ProactiveAlertsEngine {
    enum AlertKind: String, Sendable {
        case pattern
        case lateDose
    }

    struct PatternCluster: Sendable {
        let weekdayIndex: Int
        let weekdayName: String
        let shotCount: Int
        let totalShots: Int
        var share: Double { totalShots > 0 ? Double(shotCount) / Double(totalShots) : 0 }
    }

    static let minimumSampleSize = 5
    static let patternMinimumEvents = 6
    static let lateDoseIdentifier = "glp-late-dose"
    /// How long after the planned dose time the "dose slipping" nudge fires when no shot
    /// has been logged for that occurrence.
    static let lateDoseGraceHours = 4

    static func analyzeTimingPatterns(events: [ShotEvent], sensitivity: Double) -> [PatternCluster] {
        guard events.count >= patternMinimumEvents else { return [] }
        let minShare = 0.45 - (0.20 * sensitivity)
        let counts = Dictionary(grouping: events, by: \.weekdayIndex).mapValues(\.count)
        let symbols = Calendar.current.weekdaySymbols
        return counts.compactMap { weekday, count in
            let share = Double(count) / Double(events.count)
            guard share >= minShare else { return nil }
            let name = symbols[max(0, min(symbols.count - 1, weekday - 1))]
            return PatternCluster(weekdayIndex: weekday, weekdayName: name, shotCount: count, totalShots: events.count)
        }
        .sorted { $0.share > $1.share }
    }

    /// Alerts are Pro. Before entitlements resolve a Pro user reads as free, so only a
    /// resolved non-Pro state turns them off; the user's setting is kept for a return.
    static func isActive(alertsEnabled: Bool, entitlementsResolved: Bool, isPro: Bool) -> Bool {
        alertsEnabled && (isPro || !entitlementsResolved)
    }

    @MainActor
    static func schedulePatternAlertsIfEnabled(in context: ModelContext) async {
        let prefs = ProAlertPreferenceValues.current()
        let store = StoreService.shared
        guard isActive(alertsEnabled: prefs.alertsEnabled, entitlementsResolved: store.hasResolvedEntitlements, isPro: store.isProUnlocked) else {
            await cancelPatternNotifications()
            cancelLateDoseNudge()
            return
        }
        let events = allShotEvents(in: context)
        if prefs.patternAlertsEnabled {
            let clusters = analyzeTimingPatterns(events: events, sensitivity: prefs.patternAlertSensitivity)
            await reschedulePatternNotifications(clusters: clusters, prefs: prefs, isPill: PlanStore.currentPlan(in: context)?.form == .pill, doseDates: events.map(\.timestamp))
        } else {
            await cancelPatternNotifications()
        }
        await rescheduleLateDoseNudge(plan: PlanStore.currentPlan(in: context), events: events, prefs: prefs)
    }

    /// The "never miss a dose" Pro nudge: if the next planned dose hasn't been logged a few
    /// hours after its time, remind the user before the day fully slips. Rescheduled on every
    /// capture (logging a shot claims the occurrence and pushes the nudge to the next one).
    @MainActor
    static func rescheduleLateDoseNudge(
        plan: MedicationPlan?,
        events: [ShotEvent],
        prefs: ProAlertPreferenceValues,
        calendar: Calendar = .current
    ) async {
        cancelLateDoseNudge()
        guard prefs.alertsEnabled,
              let plan,
              let next = nextUnclaimedOccurrence(
                  now: .now,
                  plan: plan,
                  events: events,
                  calendar: calendar
              )
        else { return }

        let granted = await ReminderService.ensureAuthorization(mayPrompt: false)
        guard granted else { return }

        let now = Date()
        let requestedFireDate = lateDoseFireDate(for: next, prefs: prefs, calendar: calendar)
        let fireDate = max(requestedFireDate, now.addingTimeInterval(60))
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Dose slipping?")
        let time = next.formatted(.dateTime.hour().minute())
        if calendar.isDate(next, inSameDayAs: fireDate) {
            content.body = String(localized: "Your \(plan.displayMedicationName) dose was planned for today at \(time). Log it after you take it.")
        } else {
            content.body = String(localized: "Your \(plan.displayMedicationName) dose was planned for \(next.formatted(.dateTime.weekday(.wide).hour().minute())). Log it after you take it.")
        }
        content.sound = .default
        content.threadIdentifier = "pro-alerts"
        content.categoryIdentifier = ReminderService.doseCategory
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: lateDoseIdentifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancelLateDoseNudge() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [lateDoseIdentifier])
    }

    @MainActor
    static func isOccurrenceClaimed(_ occurrence: Date, by events: [ShotEvent]) -> Bool {
        ScheduleEngine.isOccurrenceClaimed(occurrence, by: events)
    }

    @MainActor
    static func nextUnclaimedOccurrence(now: Date, plan: MedicationPlan, events: [ShotEvent], calendar: Calendar = .current) -> Date? {
        ScheduleEngine.nextUnclaimedOccurrence(now: now, plan: plan, events: events, calendar: calendar)
    }

    /// Planned time + grace, shifted forward out of quiet hours if needed.
    static func lateDoseFireDate(for occurrence: Date, prefs: ProAlertPreferenceValues, calendar: Calendar = .current) -> Date {
        var fire = occurrence.addingTimeInterval(TimeInterval(lateDoseGraceHours) * 3600)
        var guardrail = 0
        while prefs.isQuietHour(at: fire, calendar: calendar), guardrail < 24 {
            fire = fire.addingTimeInterval(3600)
            guardrail += 1
        }
        return fire
    }

    /// The next 9:00 on the cluster's weekday, skipping a day that already has a logged
    /// dose so the alert never asks for one the user just logged.
    static func patternFireDate(weekday: Int, doseDates: [Date], now: Date = .now, calendar: Calendar = .current) -> Date? {
        let components = DateComponents(hour: 9, minute: 0, weekday: weekday)
        guard var fire = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) else { return nil }
        while doseDates.contains(where: { calendar.isDate($0, inSameDayAs: fire) }) {
            guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: fire) else { return nil }
            fire = nextWeek
        }
        return fire
    }

    static func reschedulePatternNotifications(clusters: [PatternCluster], prefs: ProAlertPreferenceValues, isPill: Bool = false, doseDates: [Date] = []) async {
        let center = UNUserNotificationCenter.current()
        await cancelPatternNotifications()
        let granted = await ReminderService.ensureAuthorization(mayPrompt: false)
        guard granted else { return }

        for cluster in clusters.prefix(3) {
            guard let nextDate = patternFireDate(weekday: cluster.weekdayIndex, doseDates: doseDates) else { continue }
            if prefs.isQuietHour(at: nextDate) { continue }
            let fireComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Simple GLP pattern")
            content.body = isPill
                ? String(localized: "Most of your logged pills happen on \(cluster.weekdayName). Want to log today’s dose?")
                : String(localized: "Most of your logged shots happen on \(cluster.weekdayName). Want to log today’s dose?")
            content.sound = .default
            content.threadIdentifier = "pro-alerts"
            let trigger = UNCalendarNotificationTrigger(dateMatching: fireComponents, repeats: false)
            let request = UNNotificationRequest(identifier: "glp-pattern-\(cluster.weekdayIndex)", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    static func cancelPatternNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("glp-pattern-") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    @MainActor
    private static func allShotEvents(in context: ModelContext) -> [ShotEvent] {
        let descriptor = FetchDescriptor<ShotEvent>(sortBy: [SortDescriptor(\.timestamp, order: .forward)])
        return (try? context.fetch(descriptor)) ?? []
    }
}
