import SwiftUI

/// Log a dose at the time it was really taken: a pill swallowed on waking and logged later,
/// or a day that never got logged. The pill countdown then runs from the real time.
struct LogEarlierSheet: View {
    @Environment(\.dismiss) private var dismiss
    let form: DoseForm
    let waitMinutes: Int
    /// Logged dose times, used to flag a day that already has one.
    let doseDates: [Date]
    let onLog: (Date) -> Void

    @State private var when: Date
    /// The picker's upper bound, fixed when the sheet opens so chips and the picker agree.
    private let openedAt: Date

    init(form: DoseForm, waitMinutes: Int, doseDates: [Date], initialDate: Date, now: Date = .now, onLog: @escaping (Date) -> Void) {
        self.form = form
        self.waitMinutes = waitMinutes
        self.doseDates = doseDates
        self.onLog = onLog
        self.openedAt = now
        _when = State(initialValue: min(initialDate, now))
    }

    private static let quickMinutes = [5, 15, 30, 60]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    quickPicks
                    DatePicker("Taken", selection: $when, in: earliest...openedAt)
                } footer: {
                    Text(footnote)
                }
            }
            .navigationTitle("When did you take it?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        onLog(when)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var earliest: Date {
        Calendar.current.date(byAdding: .day, value: -60, to: openedAt) ?? openedAt
    }

    private var quickPicks: some View {
        HStack(spacing: 8) {
            ForEach(Self.quickMinutes, id: \.self) { minutes in
                let date = openedAt.addingTimeInterval(TimeInterval(-minutes * 60))
                let selected = abs(when.timeIntervalSince(date)) < 30
                Button {
                    when = date
                } label: {
                    Text(quickPickLabel(minutes))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(selected ? .white : AppTheme.text)
                        .background(selected ? AppTheme.brand : AppTheme.brandSoft, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "\(quickPickDuration(minutes)) ago"))
            }
        }
        .listRowSeparator(.hidden)
    }

    private func quickPickLabel(_ minutes: Int) -> String {
        String(localized: "\(quickPickDuration(minutes)) ago")
    }

    private func quickPickDuration(_ minutes: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: TimeInterval(minutes * 60)) ?? String(localized: "\(minutes) min")
    }

    /// What logging at `when` will do, in plain terms.
    private var footnote: String {
        let calendar = Calendar.current
        if form == .pill, doseDates.contains(where: { calendar.isDate($0, inSameDayAs: when) }) {
            return String(localized: "You already logged a pill that day. This adds a second one.")
        }
        guard calendar.isDate(when, inSameDayAs: openedAt) else {
            return String(localized: "Logged for \(when.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())). Nothing else changes.")
        }
        guard form == .pill, waitMinutes > 0 else {
            return form == .pill
                ? String(localized: "Your pill is logged at this time.")
                : String(localized: "Your shot is logged at this time.")
        }
        let end = when.addingTimeInterval(TimeInterval(waitMinutes * 60))
        if end > openedAt {
            let left = Int((end.timeIntervalSince(openedAt) / 60).rounded(.up))
            let remainingText = GLPDurationText.format(seconds: TimeInterval(left * 60), units: [.minute], style: .abbreviated)
            return String(localized: "Your wait counts from then, so it ends at \(end.formatted(date: .omitted, time: .shortened)), \(remainingText) from now.")
        }
        return String(localized: "Counting from then, your \(waitMinutes)-minute wait is already over.")
    }
}
