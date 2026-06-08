import Foundation
import SwiftData

/// User-facing strings for schedule cadence.
enum GLPScheduleFormat {
    /// A human label for an every-N-days cadence, e.g. "day", "week", "2 weeks", "10 days".
    /// Reads naturally after "Repeat every".
    static func intervalLabel(_ days: Int) -> String {
        let n = max(1, days)
        if n == 1 { return "day" }
        if n == 7 { return "week" }
        if n % 7 == 0 { return "\(n / 7) weeks" }
        return "\(n) days"
    }
}

enum ScheduleEngine {
    struct Match: Sendable {
        let scheduledDate: Date?
        let doseMg: Double
        let status: ScheduleMatchStatus
        let minutesFromSchedule: Int?
    }

    static let onScheduleWindow: TimeInterval = 18 * 60 * 60
    static let matchWindow: TimeInterval = 4 * 24 * 60 * 60

    static func match(timestamp: Date, plan: MedicationPlan?, existingEvents: [ShotEvent] = [], calendar: Calendar = .current) -> Match {
        guard let plan else {
            return Match(scheduledDate: nil, doseMg: 0, status: .unknown, minutesFromSchedule: nil)
        }

        let nearby = expectedDates(around: timestamp, plan: plan, calendar: calendar)
            .map { ($0, abs($0.timeIntervalSince(timestamp))) }
            .sorted { $0.1 < $1.1 }

        guard let closest = nearby.first, closest.1 <= matchWindow else {
            return Match(scheduledDate: nil, doseMg: dose(on: timestamp, plan: plan), status: .extra, minutesFromSchedule: nil)
        }

        let alreadyClaimed = existingEvents.contains { event in
            guard let scheduled = event.scheduledDate else { return false }
            return abs(scheduled.timeIntervalSince(closest.0)) < 60
        }
        if alreadyClaimed {
            return Match(scheduledDate: nil, doseMg: dose(on: timestamp, plan: plan), status: .extra, minutesFromSchedule: nil)
        }

        let delta = timestamp.timeIntervalSince(closest.0)
        let status: ScheduleMatchStatus
        if abs(delta) <= onScheduleWindow {
            status = .onSchedule
        } else if delta < 0 {
            status = .early
        } else {
            status = .late
        }

        return Match(
            scheduledDate: closest.0,
            doseMg: dose(on: closest.0, plan: plan),
            status: status,
            minutesFromSchedule: Int((delta / 60).rounded())
        )
    }

    /// The first canonical scheduled dose for this plan.
    /// - Weekly plans anchor on the preferred weekday/time within the start week, rolled forward
    ///   to on/after the start date (preserves the original weekday-based behavior).
    /// - Every-N-days plans anchor on the start date itself at the preferred time of day.
    static func firstScheduledDate(plan: MedicationPlan, calendar: Calendar = .current) -> Date? {
        if plan.isWeekly {
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: plan.scheduleStartDate)
            components.weekday = plan.preferredWeekday
            components.hour = plan.preferredHour
            components.minute = plan.preferredMinute
            components.second = 0
            guard var candidate = calendar.date(from: components) else { return nil }
            while candidate < plan.scheduleStartDate {
                guard let next = calendar.date(byAdding: .day, value: 7, to: candidate) else { return nil }
                candidate = next
            }
            return candidate
        }
        let startDay = calendar.startOfDay(for: plan.scheduleStartDate)
        return calendar.date(bySettingHour: plan.preferredHour, minute: plan.preferredMinute, second: 0, of: startDay)
    }

    static func nextExpectedDate(after date: Date = .now, plan: MedicationPlan?, calendar: Calendar = .current) -> Date? {
        guard let plan, var candidate = firstScheduledDate(plan: plan, calendar: calendar) else { return nil }
        let cadence = plan.cadenceDays
        while candidate <= date {
            guard let next = calendar.date(byAdding: .day, value: cadence, to: candidate) else { return nil }
            candidate = next
        }
        return candidate
    }

    static func dose(on date: Date, plan: MedicationPlan) -> Double {
        let steps = plan.doseSteps.sorted { $0.startDate < $1.startDate }
        return steps.last(where: { $0.startDate <= date })?.doseMg ?? plan.doseMg
    }

    static func expectedDates(around date: Date, plan: MedicationPlan, calendar: Calendar = .current) -> [Date] {
        let cadence = plan.cadenceDays
        guard let anchor = scheduledDate(onOrBefore: date, plan: plan, calendar: calendar) else {
            return [firstScheduledDate(plan: plan, calendar: calendar) ?? plan.scheduleStartDate]
        }
        return (-2...2).compactMap { calendar.date(byAdding: .day, value: $0 * cadence, to: anchor) }
    }

    /// The most recent scheduled dose on or before `date`, or nil if the first dose is still ahead.
    static func scheduledDate(onOrBefore date: Date, plan: MedicationPlan, calendar: Calendar = .current) -> Date? {
        guard let first = firstScheduledDate(plan: plan, calendar: calendar) else { return nil }
        if first > date { return nil }
        let cadence = plan.cadenceDays
        // Jump close arithmetically, then correct for any DST drift in both directions so the
        // result is the largest occurrence <= date.
        let secondsPerStep = Double(cadence) * 86_400
        let approxSteps = max(0, Int((date.timeIntervalSince(first) / secondsPerStep).rounded(.down)))
        var candidate = calendar.date(byAdding: .day, value: approxSteps * cadence, to: first) ?? first
        while let next = calendar.date(byAdding: .day, value: cadence, to: candidate), next <= date {
            candidate = next
        }
        while candidate > date {
            guard let prev = calendar.date(byAdding: .day, value: -cadence, to: candidate) else { break }
            candidate = prev
        }
        return candidate > date ? nil : candidate
    }
}
