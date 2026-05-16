import Foundation
import SwiftData

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

    static func nextExpectedDate(after date: Date = .now, plan: MedicationPlan?, calendar: Calendar = .current) -> Date? {
        guard let plan else { return nil }
        let seed = scheduledDate(onOrBefore: max(date, plan.scheduleStartDate), plan: plan, calendar: calendar) ?? plan.scheduleStartDate
        var candidate = seed
        while candidate <= date {
            guard let next = calendar.date(byAdding: .day, value: 7, to: candidate) else { return nil }
            candidate = next
        }
        return candidate
    }

    static func dose(on date: Date, plan: MedicationPlan) -> Double {
        let steps = plan.doseSteps.sorted { $0.startDate < $1.startDate }
        return steps.last(where: { $0.startDate <= date })?.doseMg ?? plan.doseMg
    }

    static func expectedDates(around date: Date, plan: MedicationPlan, calendar: Calendar = .current) -> [Date] {
        guard let anchor = scheduledDate(onOrBefore: date, plan: plan, calendar: calendar) else {
            return [plan.scheduleStartDate]
        }
        return (-2...2).compactMap { calendar.date(byAdding: .day, value: $0 * 7, to: anchor) }
    }

    static func scheduledDate(onOrBefore date: Date, plan: MedicationPlan, calendar: Calendar = .current) -> Date? {
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: max(plan.scheduleStartDate, date))
        components.weekday = plan.preferredWeekday
        components.hour = plan.preferredHour
        components.minute = plan.preferredMinute
        components.second = 0

        var candidate = calendar.date(from: components)
        if let c = candidate, c > date {
            candidate = calendar.date(byAdding: .day, value: -7, to: c)
        }
        while let c = candidate, c < plan.scheduleStartDate {
            candidate = calendar.date(byAdding: .day, value: 7, to: c)
        }
        return candidate
    }
}
