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

    @MainActor
    static func schedulePatternAlertsIfEnabled(in context: ModelContext) async {
        let prefs = ProAlertPreferenceValues.current()
        guard prefs.alertsEnabled else {
            await cancelPatternNotifications()
            cancelLateDoseNudge()
            return
        }
        let events = allShotEvents(in: context)
        if prefs.patternAlertsEnabled {
            let clusters = analyzeTimingPatterns(events: events, sensitivity: prefs.patternAlertSensitivity)
            await reschedulePatternNotifications(clusters: clusters, prefs: prefs)
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
              let next = ScheduleEngine.nextExpectedDate(plan: plan, calendar: calendar),
              !isOccurrenceClaimed(next, by: events)
        else { return }

        let granted = await ReminderService.ensureAuthorization()
        guard granted else { return }

        let fireDate = lateDoseFireDate(for: next, prefs: prefs, calendar: calendar)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let content = UNMutableNotificationContent()
        content.title = "Dose slipping?"
        content.body = "Your \(plan.displayMedicationName) dose was planned for \(next.formatted(.dateTime.hour().minute())) today. One tap to log it and stay on track."
        content.sound = .default
        content.threadIdentifier = "pro-alerts"
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: lateDoseIdentifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancelLateDoseNudge() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [lateDoseIdentifier])
    }

    /// True when a logged shot already claimed this scheduled occurrence (same matching
    /// tolerance ScheduleEngine uses), so the late-dose nudge shouldn't fire for it.
    @MainActor
    static func isOccurrenceClaimed(_ occurrence: Date, by events: [ShotEvent]) -> Bool {
        events.contains { event in
            guard let scheduled = event.scheduledDate else { return false }
            return abs(scheduled.timeIntervalSince(occurrence)) < 60
        }
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

    static func reschedulePatternNotifications(clusters: [PatternCluster], prefs: ProAlertPreferenceValues) async {
        let center = UNUserNotificationCenter.current()
        await cancelPatternNotifications()
        let granted = await ReminderService.ensureAuthorization()
        guard granted else { return }

        for cluster in clusters.prefix(3) {
            var components = DateComponents()
            components.weekday = cluster.weekdayIndex
            components.hour = 9
            components.minute = 0
            guard let nextDate = Calendar.current.nextDate(after: .now, matching: components, matchingPolicy: .nextTime) else { continue }
            if prefs.isQuietHour(at: nextDate) { continue }
            let fireComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)
            let content = UNMutableNotificationContent()
            content.title = "Simple GLP pattern"
            content.body = "Most of your logged shots happen on \(cluster.weekdayName). Want to log today’s dose?"
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
