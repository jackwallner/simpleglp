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

/// "Repeat" as a menu of human presets (daily / weekly / 2 weeks / 4 weeks) with a Custom
/// escape hatch that reveals a stepper for any 1–90 day interval.
struct CadenceField: View {
    @Binding var intervalDays: Int
    @State private var isCustom = false

    private static let customTag = -1

    var body: some View {
        Picker("Repeat", selection: selection) {
            Text("Every day").tag(1)
            Text("Weekly").tag(7)
            Text("Every 2 weeks").tag(14)
            Text("Every 4 weeks").tag(28)
            Text("Custom…").tag(Self.customTag)
        }
        .pickerStyle(.menu)
        .onAppear { isCustom = !GLPScheduleFormat.presets.contains(intervalDays) }
        if isCustom {
            Stepper(value: $intervalDays, in: 1...90) {
                HStack {
                    Text("Every")
                    Spacer()
                    Text(GLPScheduleFormat.intervalLabel(intervalDays))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var selection: Binding<Int> {
        Binding(
            get: { isCustom ? Self.customTag : intervalDays },
            set: { newValue in
                if newValue == Self.customTag {
                    isCustom = true
                } else {
                    isCustom = false
                    intervalDays = newValue
                }
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
