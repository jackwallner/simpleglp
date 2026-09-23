import SwiftUI

/// A month of daily doses at a glance: filled for a logged day, outlined for a planned day
/// with nothing logged. Tapping a past day opens its dose or logs a missed one.
struct MonthAdherenceView: View {
    /// First instant of the month shown.
    @Binding var month: Date
    let doseDates: [Date]
    let planStart: Date?
    let onSelect: (Date) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let now = Date()
        let taken = Set(doseDates.map { calendar.startOfDay(for: $0) })
        VStack(spacing: 12) {
            header(now: now, taken: taken)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                        .accessibilityHidden(true)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day, now: now, taken: taken.contains(day))
                    } else {
                        Color.clear.frame(height: 34)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func header(now: Date, taken: Set<Date>) -> some View {
        let summary = DailyAdherence.monthSummary(takenDays: taken, month: month, planStart: planStart, now: now, calendar: calendar)
        return HStack {
            Button {
                shift(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Previous month")
            Spacer()
            VStack(spacing: 2) {
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                if summary.planned > 0 {
                    Text("\(summary.taken) of \(summary.planned) days logged")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .monospacedDigit()
                }
            }
            Spacer()
            Button {
                shift(1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 32, height: 32)
            }
            .disabled(isCurrentMonth(now: now))
            .foregroundStyle(isCurrentMonth(now: now) ? AppTheme.surfaceStroke : AppTheme.brand)
            .accessibilityLabel("Next month")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(AppTheme.brand)
    }

    private func dayCell(_ day: Date, now: Date, taken: Bool) -> some View {
        let isToday = calendar.isDate(day, inSameDayAs: now)
        let isFuture = day > now
        let isPlanned = !isFuture && planStart.map { day >= calendar.startOfDay(for: $0) } ?? true
        return Button {
            onSelect(day)
        } label: {
            ZStack {
                Circle()
                    .fill(taken ? AppTheme.brand : Color.clear)
                if !taken && isPlanned {
                    Circle()
                        .strokeBorder(isToday ? AppTheme.brand : AppTheme.surfaceStroke, lineWidth: isToday ? 2 : 1.5)
                }
                Text(day.formatted(.dateTime.day()))
                    .font(.footnote.weight(isToday ? .bold : .medium))
                    .monospacedDigit()
                    .foregroundStyle(taken ? .white : (isFuture ? AppTheme.muted.opacity(0.5) : AppTheme.text))
            }
            .frame(width: 34, height: 34)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide).month(.wide).day())), \(taken ? "taken" : (isPlanned ? "not logged" : "before your plan"))")
    }

    /// The month's days padded with leading blanks so the first lands under its weekday.
    private var cells: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: month)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let days = range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
        return Array(repeating: nil, count: leading) + days
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    private func isCurrentMonth(now: Date) -> Bool {
        calendar.isDate(month, equalTo: now, toGranularity: .month)
    }

    private func shift(_ months: Int) {
        guard let next = calendar.date(byAdding: .month, value: months, to: month) else { return }
        month = next
    }
}
