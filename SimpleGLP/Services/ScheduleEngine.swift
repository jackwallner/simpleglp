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

    /// One-line plain-language schedule, e.g. "Weekly on Thursdays · 9:00 AM" or
    /// "Every 3 days · 8:00 AM". Used to confirm the schedule back to the user.
    static func summary(firstDose: Date, intervalDays: Int) -> String {
        let n = max(1, intervalDays)
        let time = firstDose.formatted(.dateTime.hour().minute())
        let cadence: String
        if n == 7 {
            cadence = "Weekly on \(firstDose.formatted(.dateTime.weekday(.wide)))s"
        } else {
            cadence = "Every \(intervalLabel(n))"
        }
        return "\(cadence) · \(time)"
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
    /// A daily dose within this much of its planned time counts as on schedule.
    static let dailyOnScheduleWindow: TimeInterval = 3 * 60 * 60

    static func match(timestamp: Date, plan: MedicationPlan?, existingEvents: [ShotEvent] = [], calendar: Calendar = .current) -> Match {
        guard let plan else {
            return Match(scheduledDate: nil, doseMg: 0, status: .unknown, minutesFromSchedule: nil)
        }
        if plan.cadenceDays == 1 {
            return dailyMatch(timestamp: timestamp, plan: plan, existingEvents: existingEvents, calendar: calendar)
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

    /// Daily doses belong to their calendar day. Nearest-slot matching would hand a late
    /// 11 PM pill to tomorrow morning's slot and mark it "early".
    private static func dailyMatch(timestamp: Date, plan: MedicationPlan, existingEvents: [ShotEvent], calendar: Calendar) -> Match {
        let day = calendar.startOfDay(for: timestamp)
        guard let first = firstScheduledDate(plan: plan, calendar: calendar),
              day >= calendar.startOfDay(for: first),
              let slot = calendar.date(bySettingHour: plan.preferredHour, minute: plan.preferredMinute, second: 0, of: day)
        else {
            return Match(scheduledDate: nil, doseMg: dose(on: timestamp, plan: plan), status: .extra, minutesFromSchedule: nil)
        }
        let alreadyClaimed = existingEvents.contains { event in
            guard let scheduled = event.scheduledDate else { return false }
            return abs(scheduled.timeIntervalSince(slot)) < 60
        }
        if alreadyClaimed {
            return Match(scheduledDate: nil, doseMg: dose(on: timestamp, plan: plan), status: .extra, minutesFromSchedule: nil)
        }
        let delta = timestamp.timeIntervalSince(slot)
        let status: ScheduleMatchStatus
        if abs(delta) <= dailyOnScheduleWindow {
            status = .onSchedule
        } else {
            status = delta < 0 ? .early : .late
        }
        return Match(scheduledDate: slot, doseMg: dose(on: slot, plan: plan), status: status, minutesFromSchedule: Int((delta / 60).rounded()))
    }

    /// The first canonical scheduled dose: the start date at the preferred time of day.
    /// The whole schedule is just this anchor plus `cadenceDays` — the weekday is simply
    /// whatever day the start date falls on (weekly is `cadenceDays == 7`).
    static func firstScheduledDate(plan: MedicationPlan, calendar: Calendar = .current) -> Date? {
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

    /// The planned dose the user still owes. Daily: today's slot until a pill is logged
    /// today, then tomorrow's. Otherwise the overdue or next slot no logged shot has
    /// claimed, so a shot taken a day early doesn't leave that week reading "due".
    /// Home, the widgets and Siri all read this.
    @MainActor
    static func nextDue(plan: MedicationPlan, events: [ShotEvent], now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard plan.cadenceDays == 1 else {
            return nextUnclaimedOccurrence(now: now, plan: plan, events: events, calendar: calendar)
        }
        let takenToday = events.contains { calendar.isDate($0.timestamp, inSameDayAs: now) && $0.timestamp <= now }
        let today = calendar.startOfDay(for: now)
        guard let day = takenToday ? calendar.date(byAdding: .day, value: 1, to: today) : today,
              let slot = calendar.date(bySettingHour: plan.preferredHour, minute: plan.preferredMinute, second: 0, of: day)
        else { return nil }
        return max(slot, firstScheduledDate(plan: plan, calendar: calendar) ?? slot)
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

    /// Returns the current unclaimed occurrence when a dose is overdue, otherwise the next
    /// future occurrence. The previous implementation always used the next future occurrence,
    /// so a missed dose never generated a late-dose nudge.
    @MainActor
    static func nextUnclaimedOccurrence(
        now: Date,
        plan: MedicationPlan,
        events: [ShotEvent],
        calendar: Calendar = .current
    ) -> Date? {
        if let overdue = ScheduleEngine.scheduledDate(onOrBefore: now, plan: plan, calendar: calendar),
           let first = ScheduleEngine.firstScheduledDate(plan: plan, calendar: calendar),
           overdue >= first,
           !isOccurrenceClaimed(overdue, by: events),
           // A dose logged since then (say today's pill, taken early after a missed day)
           // means the user has moved on; nudging about the missed one would fire right
           // after they log.
           !events.contains(where: { $0.timestamp >= overdue }) {
            return overdue
        }

        guard var next = ScheduleEngine.nextExpectedDate(after: now, plan: plan, calendar: calendar) else {
            return nil
        }
        while isOccurrenceClaimed(next, by: events) {
            guard let following = calendar.date(byAdding: .day, value: plan.cadenceDays, to: next) else {
                return nil
            }
            next = following
        }
        return next
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

/// Day-level adherence for daily plans: the week strip and the running streak on Home.
enum DailyAdherence {
    struct Day: Identifiable, Equatable {
        let date: Date
        let taken: Bool
        var id: Date { date }
    }

    /// The last `count` calendar days ending today, oldest first.
    static func recentDays(doseDates: [Date], count: Int = 7, now: Date = .now, calendar: Calendar = .current) -> [Day] {
        let takenDays = Set(doseDates.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: now)
        return (0..<count).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return Day(date: day, taken: takenDays.contains(day))
        }
    }

    /// Consecutive days with a logged dose. Today only breaks the streak once it's over, so
    /// a morning before the pill still shows yesterday's run.
    static func streak(doseDates: [Date], now: Date = .now, calendar: Calendar = .current) -> Int {
        let takenDays = Set(doseDates.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: now)
        if !takenDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while takenDays.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// Logged days against planned days in one month, counting only days from the plan's
    /// start through today so a new user isn't marked down for days before they began.
    static func monthSummary(takenDays: Set<Date>, month: Date, planStart: Date?, now: Date = .now, calendar: Calendar = .current) -> (taken: Int, planned: Int) {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return (0, 0) }
        let today = calendar.startOfDay(for: now)
        let start = max(interval.start, planStart.map { calendar.startOfDay(for: $0) } ?? interval.start)
        var day = start
        var planned = 0
        var taken = 0
        while day < interval.end, day <= today {
            planned += 1
            if takenDays.contains(day) { taken += 1 }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return (taken, planned)
    }

    /// Days with a logged dose among the last `days` days (today included), and how many of
    /// those days the plan was running.
    static func recentSummary(doseDates: [Date], days: Int, planStart: Date?, now: Date = .now, calendar: Calendar = .current) -> (taken: Int, planned: Int) {
        let takenDays = Set(doseDates.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: now)
        let floor = planStart.map { calendar.startOfDay(for: $0) } ?? .distantPast
        var taken = 0
        var planned = 0
        for offset in 0..<max(0, days) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today), day >= floor else { break }
            planned += 1
            if takenDays.contains(day) { taken += 1 }
        }
        return (taken, planned)
    }

    /// The longest run of consecutive logged days in the history.
    static func longestStreak(doseDates: [Date], calendar: Calendar = .current) -> Int {
        let days = Set(doseDates.map { calendar.startOfDay(for: $0) }).sorted()
        var best = 0
        var run = 0
        var previous: Date?
        for day in days {
            if let previous, let expected = calendar.date(byAdding: .day, value: 1, to: previous), calendar.isDate(day, inSameDayAs: expected) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }

    /// The most recent dose logged today, if any.
    static func todaysDose(doseDates: [Date], now: Date = .now, calendar: Calendar = .current) -> Date? {
        doseDates.filter { calendar.isDate($0, inSameDayAs: now) && $0 <= now }.max()
    }
}

/// Doses on hand, derived from the last refill count and what's been logged since.
enum SupplyMath {
    /// Refill reminders fire this many days before the supply is used up.
    static let reminderLeadDays = 7

    static func remaining(plan: MedicationPlan, doseDates: [Date]) -> Int? {
        guard let since = plan.supplyUpdatedAt else { return nil }
        let used = doseDates.filter { $0 >= since }.count
        return max(0, plan.supplyCount - used)
    }

    static func daysLeft(remaining: Int, plan: MedicationPlan) -> Int {
        remaining * plan.cadenceDays
    }

    static func isLow(remaining: Int, plan: MedicationPlan) -> Bool {
        daysLeft(remaining: remaining, plan: plan) <= reminderLeadDays
    }

    /// When to send the refill heads-up: `reminderLeadDays` before the supply runs out, at
    /// the plan's dose time. Nil when that moment has already passed.
    static func reminderDate(remaining: Int, plan: MedicationPlan, now: Date = .now, calendar: Calendar = .current) -> Date? {
        let offset = daysLeft(remaining: remaining, plan: plan) - reminderLeadDays
        guard offset > 0,
              let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)),
              let fire = calendar.date(bySettingHour: plan.preferredHour, minute: plan.preferredMinute, second: 0, of: day),
              fire > now
        else { return nil }
        return fire
    }
}
