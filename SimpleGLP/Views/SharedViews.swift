import SwiftUI

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(AppTheme.surfaceStroke.opacity(0.6), lineWidth: 1)
        )
    }
}

/// The recurring-dose schedule editor — one anchor (first dose date + time) plus a repeat
/// interval, the standard reminder primitive. Shared by onboarding and Settings so the two
/// never drift. Renders as plain rows; the caller supplies the container (Form section or card).
struct ScheduleFields: View {
    @Binding var firstDose: Date
    @Binding var intervalDays: Int

    var body: some View {
        DatePicker("First dose", selection: $firstDose, displayedComponents: .date)
        DatePicker("Time", selection: $firstDose, displayedComponents: .hourAndMinute)
        CadenceField(intervalDays: $intervalDays)
        Text(GLPScheduleFormat.summary(firstDose: firstDose, intervalDays: intervalDays))
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

/// "Repeat every [N] [days/weeks]" — a count menu plus a unit menu, the way medication
/// reminders are usually expressed. The underlying model is a fixed day-interval, so the
/// unit is just a multiplier (day ×1, week ×7); GLP-1s are only ever dosed daily or weekly.
struct CadenceField: View {
    @Binding var intervalDays: Int
    @State private var count = 1
    @State private var unit: Unit = .week

    private enum Unit: Hashable {
        case day, week
        var perStep: Int { self == .week ? 7 : 1 }
        /// Caps cover the prior custom range (1–90 days): 90 days, or 12 weeks (84 days).
        var maxCount: Int { self == .week ? 12 : 90 }

        /// Largest natural unit that divides the interval cleanly, e.g. 14 → (2, .week).
        static func decode(_ days: Int) -> (count: Int, unit: Unit) {
            let n = max(1, days)
            return n % 7 == 0 ? (n / 7, .week) : (n, .day)
        }
    }

    var body: some View {
        HStack {
            Text("Repeat every")
            Spacer()
            Picker("Count", selection: countBinding) {
                ForEach(1...unit.maxCount, id: \.self) { Text("\($0)").tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            Picker("Unit", selection: unitBinding) {
                Text("day").tag(Unit.day)
                Text("week").tag(Unit.week)
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
        .onAppear {
            let decoded = Unit.decode(intervalDays)
            count = decoded.count
            unit = decoded.unit
        }
    }

    private var countBinding: Binding<Int> {
        Binding(
            get: { count },
            set: { count = $0; intervalDays = $0 * unit.perStep }
        )
    }

    private var unitBinding: Binding<Unit> {
        Binding(
            get: { unit },
            set: { newUnit in
                count = min(count, newUnit.maxCount)
                unit = newUnit
                intervalDays = count * newUnit.perStep
            }
        )
    }
}

struct StatusPill: View {
    let label: String
    let tint: Color

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
    }
}
