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
        guard prefs.alertsEnabled, prefs.patternAlertsEnabled else {
            await cancelPatternNotifications()
            return
        }
        let events = allShotEvents(in: context)
        let clusters = analyzeTimingPatterns(events: events, sensitivity: prefs.patternAlertSensitivity)
        await reschedulePatternNotifications(clusters: clusters, prefs: prefs)
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
