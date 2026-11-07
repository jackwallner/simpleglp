import Foundation
import XCTest
@testable import SimpleGLP

/// Regression guards for the 2026-11-06 state machine audit fixes
/// (`project-docs/audits/state-machines-2026-11-06-fixes.md`).
@MainActor
final class StateMachineFixTests: XCTestCase {
    private func calendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private func logged(at taken: Date, plan: MedicationPlan, calendar: Calendar, existing: [ShotEvent] = []) -> ShotEvent {
        let match = ScheduleEngine.match(timestamp: taken, plan: plan, existingEvents: existing, calendar: calendar)
        return ShotEvent(timestamp: taken, medicationName: plan.storedMedicationName, doseMg: match.doseMg,
                         scheduledDate: match.scheduledDate, scheduleStatus: match.status,
                         minutesFromSchedule: match.minutesFromSchedule)
    }

    // MARK: S1 a logged dose stays claimed after a time zone change

    /// Thursday 9:00 weekly, started in New York.
    private func weeklyThursdayPlan(_ calendar: Calendar) -> MedicationPlan {
        MedicationPlan(medication: .ozempic, doseMg: 0.5,
                       scheduleStartDate: calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 9))!,
                       preferredWeekday: 5, preferredHour: 9, preferredMinute: 0, intervalDays: 7)
    }

    func testLoggedShotStaysClaimedAfterTravellingWest() throws {
        let ny = calendar("America/New_York")
        let la = calendar("America/Los_Angeles")
        let plan = weeklyThursdayPlan(ny)
        let event = logged(at: ny.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 9, minute: 5))!, plan: plan, calendar: ny)
        XCTAssertEqual(event.scheduleStatus, .onSchedule, "precondition: logged on time in New York")

        let now = la.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 10))!
        let next = try XCTUnwrap(ScheduleEngine.nextDue(plan: plan, events: [event], now: now, calendar: la))
        XCTAssertEqual(next, la.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 9)),
                       "Home reads \"\(HomeView.headline(for: next, now: now, calendar: la))\" for a shot already taken")
        let nudge = try XCTUnwrap(ScheduleEngine.nextUnclaimedOccurrence(now: now, plan: plan, events: [event], calendar: la))
        XCTAssertEqual(nudge, next, "late-dose nudge targets the logged shot")
    }

    func testLoggedShotStaysClaimedAcrossALargeWestwardShift() throws {
        let tokyo = calendar("Asia/Tokyo")
        let la = calendar("America/Los_Angeles")
        // Thursday 21:00 in Tokyo is still Thursday morning in Los Angeles, so the plan keeps its day.
        let plan = MedicationPlan(medication: .ozempic, doseMg: 0.5,
                                  scheduleStartDate: tokyo.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 21))!,
                                  preferredWeekday: 5, preferredHour: 21, preferredMinute: 0, intervalDays: 7)
        let event = logged(at: tokyo.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 21, minute: 5))!, plan: plan, calendar: tokyo)
        XCTAssertEqual(event.scheduleStatus, .onSchedule, "precondition")
        let now = la.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 22))!
        let next = try XCTUnwrap(ScheduleEngine.nextDue(plan: plan, events: [event], now: now, calendar: la))
        XCTAssertEqual(next, la.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 21)))
    }

    func testSecondShotInTheNewZoneStaysExtra() {
        let ny = calendar("America/New_York")
        let la = calendar("America/Los_Angeles")
        let plan = weeklyThursdayPlan(ny)
        let first = logged(at: ny.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 9, minute: 5))!, plan: plan, calendar: ny)
        let second = logged(at: la.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 9))!, plan: plan, calendar: la, existing: [first])
        XCTAssertEqual(second.scheduleStatus, .extra, "the week's slot was already claimed in New York")
    }

    func testDailyPillLoggedInNewYorkIsClaimedInLosAngeles() throws {
        let ny = calendar("America/New_York")
        let la = calendar("America/Los_Angeles")
        let plan = MedicationPlan(medication: .wegovyPill, doseMg: 4,
                                  scheduleStartDate: ny.date(from: DateComponents(year: 2026, month: 10, day: 1))!,
                                  preferredHour: 9, preferredMinute: 0, intervalDays: 1)
        let event = logged(at: ny.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 9, minute: 5))!, plan: plan, calendar: ny)
        let now = la.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 11))!
        let target = try XCTUnwrap(ScheduleEngine.nextUnclaimedOccurrence(now: now, plan: plan, events: [event], calendar: la))
        XCTAssertEqual(target, la.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 9)),
                       "late-dose nudge targets today's pill, already logged")
        let reminders = ReminderService.upcomingReminderSlots(plan: plan, events: [event], now: now, calendar: la)
        XCTAssertEqual(reminders.first, target)
    }

    /// Daily 9:00 pill, started in the given zone.
    private func dailyPillPlan(_ calendar: Calendar) -> MedicationPlan {
        MedicationPlan(medication: .wegovyPill, doseMg: 4,
                       scheduleStartDate: calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!,
                       preferredHour: 9, preferredMinute: 0, intervalDays: 1)
    }

    func testDailyPillOwedInTokyoKeepsItsReminderAndMatch() throws {
        let ny = calendar("America/New_York")
        let tokyo = calendar("Asia/Tokyo")
        let plan = dailyPillPlan(ny)
        let event = logged(at: ny.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 9, minute: 5))!, plan: plan, calendar: ny)
        let now = tokyo.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 7))!
        let today = tokyo.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 9))!
        XCTAssertEqual(ScheduleEngine.nextDue(plan: plan, events: [event], now: now, calendar: tokyo), today,
                       "precondition: Home says today's pill is due")

        let reminders = ReminderService.upcomingReminderSlots(plan: plan, events: [event], now: now, calendar: tokyo)
        XCTAssertEqual(reminders.first, today, "today's reminder was dropped as already claimed")
        let taken = logged(at: today.addingTimeInterval(5 * 60), plan: plan, calendar: tokyo, existing: [event])
        XCTAssertNotEqual(taken.scheduleStatus, .extra, "today's pill logged in Tokyo reads Manual")
        XCTAssertEqual(ScheduleEngine.nextUnclaimedOccurrence(now: now, plan: plan, events: [event], calendar: tokyo), today,
                       "the late-dose nudge skips today's unlogged pill")
    }

    func testDailyPillOwedAfterFlyingDelhiToNewYorkKeepsItsReminder() throws {
        let delhi = calendar("Asia/Kolkata")
        let ny = calendar("America/New_York")
        let plan = dailyPillPlan(delhi)
        let event = logged(at: delhi.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 9, minute: 5))!, plan: plan, calendar: delhi)
        let now = ny.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 7))!
        let today = ny.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 9))!
        XCTAssertEqual(ScheduleEngine.nextDue(plan: plan, events: [event], now: now, calendar: ny), today,
                       "precondition: Home says today's pill is due")
        let reminders = ReminderService.upcomingReminderSlots(plan: plan, events: [event], now: now, calendar: ny)
        XCTAssertEqual(reminders.first, today, "today's reminder was dropped as already claimed")
    }

    /// Existing same-zone daily data reads as before: a pill claims its own day only, and a
    /// second pill that day stays a manual extra.
    func testControlSameZoneDailyClaimNamesOnlyItsDay() {
        let ny = calendar("America/New_York")
        let plan = dailyPillPlan(ny)
        let event = logged(at: ny.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 9, minute: 5))!, plan: plan, calendar: ny)
        let slot = ny.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 9))!
        XCTAssertEqual(event.scheduledDate, slot)
        XCTAssertTrue(ScheduleEngine.isOccurrenceClaimed(slot, by: [event], cadenceDays: 1, calendar: ny))
        for days in [-1, 1] {
            let other = ny.date(byAdding: .day, value: days, to: slot)!
            XCTAssertFalse(ScheduleEngine.isOccurrenceClaimed(other, by: [event], cadenceDays: 1, calendar: ny))
        }
        let second = logged(at: ny.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 20))!, plan: plan, calendar: ny, existing: [event])
        XCTAssertEqual(second.scheduleStatus, .extra)
        let lateNight = logged(at: ny.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 23, minute: 30))!, plan: plan, calendar: ny)
        XCTAssertEqual(lateNight.scheduledDate, slot, "an 11:30 PM pill stays on its own day")
    }

    func testControlEastwardTravelKeepsTheClaim() throws {
        let la = calendar("America/Los_Angeles")
        let ny = calendar("America/New_York")
        let plan = weeklyThursdayPlan(la)
        let event = logged(at: la.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 9, minute: 5))!, plan: plan, calendar: la)
        let now = ny.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 13))!
        let next = try XCTUnwrap(ScheduleEngine.nextDue(plan: plan, events: [event], now: now, calendar: ny))
        XCTAssertEqual(next, ny.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 9)))
    }

    func testControlSameZoneClaimNamesOnlyItsOwnSlot() {
        let ny = calendar("America/New_York")
        let plan = weeklyThursdayPlan(ny)
        let event = logged(at: ny.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 9, minute: 5))!, plan: plan, calendar: ny)
        let slot = ny.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 9))!
        XCTAssertTrue(ScheduleEngine.isOccurrenceClaimed(slot, by: [event], cadenceDays: 7, calendar: ny))
        for weeks in [-1, 1] {
            let other = ny.date(byAdding: .day, value: 7 * weeks, to: slot)!
            XCTAssertFalse(ScheduleEngine.isOccurrenceClaimed(other, by: [event], cadenceDays: 7, calendar: ny))
        }
    }

    // MARK: S10 the weekly Home card follows the clock it is given

    /// A daily shot plan logged mid-minute: the card re-renders before the next minute tick
    /// and must already read tomorrow.
    func testDailyShotCardTurnsOverRightAfterAMidMinuteLog() throws {
        let calendar = Calendar.current
        let slot = calendar.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 9))!
        let plan = MedicationPlan(medication: .ozempic, doseMg: 0.5,
                                  scheduleStartDate: calendar.date(byAdding: .day, value: -10, to: slot)!,
                                  preferredHour: 9, preferredMinute: 0, intervalDays: 1)
        let tick = slot.addingTimeInterval(5 * 60)
        let taken = tick.addingTimeInterval(30)
        let event = logged(at: taken, plan: plan, calendar: calendar)
        let now = HomeView.cardClock(tick: tick, now: taken.addingTimeInterval(1))
        let shot = try XCTUnwrap(HomeView.nextShot(plan: plan, events: [event], now: now))
        XCTAssertEqual(shot.date, calendar.date(byAdding: .day, value: 1, to: slot),
                       "the card still reads \"\(HomeView.headline(for: shot.date, now: now))\" for today's logged dose")
        XCTAssertFalse(shot.isOverdue)
    }

    func testWeeklyHomeCardTurnsOverAtMidnightAndAtTheDoseTime() throws {
        let calendar = Calendar.current
        let slot = calendar.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 9))!
        let plan = MedicationPlan(medication: .ozempic, doseMg: 0.5,
                                  scheduleStartDate: slot, preferredHour: 9, preferredMinute: 0, intervalDays: 7)
        let lateEvening = calendar.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 23, minute: 59))!
        let afterMidnight = calendar.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 0, minute: 1))!
        let afterDoseTime = slot.addingTimeInterval(60)

        let evening = try XCTUnwrap(HomeView.nextShot(plan: plan, events: [], now: lateEvening))
        XCTAssertEqual(evening.date, slot)
        XCTAssertEqual(HomeView.headline(for: evening.date, now: lateEvening), String(localized: "Tomorrow"))
        let morning = try XCTUnwrap(HomeView.nextShot(plan: plan, events: [], now: afterMidnight))
        XCTAssertEqual(HomeView.headline(for: morning.date, now: afterMidnight), String(localized: "Due today"))
        XCTAssertFalse(morning.isOverdue)
        let late = try XCTUnwrap(HomeView.nextShot(plan: plan, events: [], now: afterDoseTime))
        XCTAssertEqual(late.date, slot)
        XCTAssertTrue(late.isOverdue, "the overdue mark appears once the dose time passes")
    }
}
