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
                    Text(minutes < 60 ? "\(minutes)m ago" : "1h ago")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(selected ? .white : AppTheme.text)
                        .background(selected ? AppTheme.brand : AppTheme.brandSoft, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(minutes) minutes ago")
            }
        }
        .listRowSeparator(.hidden)
    }

    /// What logging at `when` will do, in plain terms.
    private var footnote: String {
        let calendar = Calendar.current
        if form == .pill, doseDates.contains(where: { calendar.isDate($0, inSameDayAs: when) }) {
            return "You already logged a pill that day. This adds a second one."
        }
        guard calendar.isDate(when, inSameDayAs: openedAt) else {
            return "Logged for \(when.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())). Nothing else changes."
        }
        guard form == .pill, waitMinutes > 0 else {
            return "Your \(form.noun) is logged at this time."
        }
        let end = when.addingTimeInterval(TimeInterval(waitMinutes * 60))
        if end > openedAt {
            let left = Int((end.timeIntervalSince(openedAt) / 60).rounded(.up))
            return "Your wait counts from then, so it ends at \(end.formatted(date: .omitted, time: .shortened)), \(left) min from now."
        }
        return "Counting from then, your \(waitMinutes)-minute wait is already over."
    }
}
