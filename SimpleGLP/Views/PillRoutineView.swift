import SwiftUI
import UIKit

/// Home for a daily pill: today's status and streak, one button that logs the pill and
/// turns into the wait-before-eating countdown, then a quiet "done for today".
struct PillRoutineView: View {
    let plan: MedicationPlan
    /// Logged dose times, newest first.
    let doseDates: [Date]
    let isLogging: Bool
    let isPro: Bool
    let onLog: () -> Void
    /// Opens the "when did you take it?" sheet, starting at the given time.
    let onLogEarlier: (Date) -> Void
    /// Opens the logged dose for that day to view or fix.
    let onEditDose: (Date) -> Void
    let onUpgrade: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var notificationsDenied = false

    var body: some View {
        let waiting = waitEnd(now: .now) != nil
        TimelineView(.periodic(from: .now, by: waiting ? 1 : 30)) { context in
            VStack(spacing: 20) {
                todayCard(now: context.date)
                    .padding(.horizontal)
                routineButton(now: context.date)
                if waitEnd(now: context.date) != nil, !isPro {
                    lockScreenUpsell
                        .padding(.horizontal)
                }
            }
        }
        .task(id: scenePhase) { notificationsDenied = await ReminderService.isDenied() }
    }

    // MARK: - State

    private func todaysDose(now: Date) -> Date? {
        DailyAdherence.todaysDose(doseDates: doseDates, now: now)
    }

    private func waitEnd(now: Date) -> Date? {
        guard plan.effectiveWaitMinutes > 0, let taken = todaysDose(now: now) else { return nil }
        let end = taken.addingTimeInterval(TimeInterval(plan.effectiveWaitMinutes * 60))
        return end > now ? end : nil
    }

    private var plannedTime: Date {
        plannedTime(on: .now)
    }

    private func plannedTime(on day: Date) -> Date {
        Calendar.current.date(bySettingHour: plan.preferredHour, minute: plan.preferredMinute, second: 0, of: day) ?? day
    }

    /// Tapping a day in the strip: open its dose, or log a missed one at its planned time.
    private func selectDay(_ day: DailyAdherence.Day, now: Date) {
        if day.taken {
            onEditDose(day.date)
        } else {
            onLogEarlier(min(plannedTime(on: day.date), now))
        }
    }

    // MARK: - Today card

    private func todayCard(now: Date) -> some View {
        let taken = todaysDose(now: now)
        let streak = DailyAdherence.streak(doseDates: doseDates, now: now)
        return Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                    if let taken {
                        Button {
                            onEditDose(taken)
                        } label: {
                            HStack(spacing: 6) {
                                Text("Taken at \(taken.formatted(date: .omitted, time: .shortened))")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.text)
                                Image(systemName: "pencil")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.muted)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Change the time or add details")
                    } else {
                        Text("Not taken yet")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                    }
                    Text("\(plan.displayMedicationName) · \(DoseScheduleView.format(ScheduleEngine.dose(on: now, plan: plan))) · planned \(plannedTime.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Streak")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                    Text(streak == 1 ? "1 day" : "\(streak) days")
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(streak > 0 ? AppTheme.brand : AppTheme.muted)
                }
            }
            WeekStrip(days: DailyAdherence.recentDays(doseDates: doseDates, now: now)) { day in
                selectDay(day, now: now)
            }
        }
    }

    // MARK: - Button

    @ViewBuilder
    private func routineButton(now: Date) -> some View {
        if let end = waitEnd(now: now), let taken = todaysDose(now: now) {
            countdown(taken: taken, end: end, now: now)
        } else if todaysDose(now: now) != nil {
            doneCircle
        } else {
            logButton
        }
    }

    private var logButton: some View {
        VStack(spacing: 10) {
            Button(action: onLog) {
                ZStack {
                    Circle()
                        .fill(AppTheme.brand)
                        .frame(width: 220, height: 220)
                        .shadow(color: AppTheme.brand.opacity(0.28), radius: 22, x: 0, y: 12)
                    VStack(spacing: 8) {
                        Image(systemName: "pills.fill")
                            .font(.system(size: 44, weight: .bold))
                        Text(plan.form.logButtonTitle)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .disabled(isLogging)
            if plan.effectiveWaitMinutes > 0 {
                Text("Starts your \(plan.effectiveWaitMinutes)-minute wait before food and drink.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Button("Took it earlier?") { onLogEarlier(.now) }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.brand)
                .disabled(isLogging)
        }
        .padding(.vertical, 8)
    }

    private func countdown(taken: Date, end: Date, now: Date) -> some View {
        let total = end.timeIntervalSince(taken)
        let progress = total > 0 ? min(1, max(0, now.timeIntervalSince(taken) / total)) : 1
        return VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(AppTheme.surface)
                    .frame(width: 220, height: 220)
                Circle()
                    .stroke(AppTheme.brandSoft, lineWidth: 12)
                    .frame(width: 196, height: 196)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(AppTheme.brand, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 196, height: 196)
                    .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)
                VStack(spacing: 4) {
                    Text("Wait")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                    Text(timerInterval: now...end, countsDown: true)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.text)
                        .multilineTextAlignment(.center)
                        .frame(width: 160)
                    Text("until \(end.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Waiting until \(end.formatted(date: .omitted, time: .shortened)) before food and drink")
            if notificationsDenied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Notifications are off, so there’s no ping when it’s over. ")
                        .foregroundStyle(AppTheme.muted)
                    + Text("Turn on")
                        .foregroundStyle(AppTheme.brand)
                        .fontWeight(.semibold)
                }
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            } else {
                Text("We’ll ping you when it’s over.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .padding(.vertical, 8)
    }

    private var doneCircle: some View {
        ZStack {
            Circle()
                .fill(AppTheme.brandSoft)
                .frame(width: 220, height: 220)
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(AppTheme.brand)
                Text("Done for today")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Text("Next one tomorrow, \(plannedTime.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .accessibilityElement(children: .combine)
        .padding(.vertical, 8)
    }

    // MARK: - Pro

    private var lockScreenUpsell: some View {
        Button(action: onUpgrade) {
            HStack(spacing: 12) {
                Image(systemName: "lock.iphone")
                    .font(.title3)
                    .foregroundStyle(AppTheme.brand)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Put this countdown on your Lock Screen")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                    Text("And in the Dynamic Island. Included with Pro.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(AppTheme.surfaceStroke.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Seven days, oldest to today: a filled dot for each day with a logged dose.
struct WeekStrip: View {
    let days: [DailyAdherence.Day]
    var onSelect: ((DailyAdherence.Day) -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days) { day in
                Button {
                    onSelect?(day)
                } label: {
                    dayCell(day)
                }
                .buttonStyle(.plain)
                .disabled(onSelect == nil)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.date.formatted(.dateTime.weekday(.wide))), \(day.taken ? "taken" : "not logged")")
                .accessibilityHint(day.taken ? "Opens this dose" : "Logs a dose for this day")
            }
        }
    }

    private func dayCell(_ day: DailyAdherence.Day) -> some View {
        let isToday = Calendar.current.isDateInToday(day.date)
        return VStack(spacing: 6) {
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2.weight(isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? AppTheme.text : AppTheme.muted)
                    ZStack {
                        Circle()
                            .fill(day.taken ? AppTheme.brand : Color.clear)
                        Circle()
                            .strokeBorder(day.taken ? AppTheme.brand : AppTheme.surfaceStroke, lineWidth: isToday ? 2 : 1.5)
                        if day.taken {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 24, height: 24)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}
