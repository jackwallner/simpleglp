import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(GLPStorageKey.hasCompletedOnboarding.rawValue, store: GLPAppGroup.userDefaults) private var hasCompletedOnboarding = false
    @State private var step = 0
    @State private var medication: GLPMedication = .ozempic
    @State private var customMedicationName = ""
    @State private var doseMg = 0.25
    @State private var useCustomDose = false
    @State private var startDate = Date()
    @State private var weekday = Calendar.current.component(.weekday, from: Date())
    @State private var intervalDays = 7
    @State private var hour = 9
    @State private var minute = 0
    @State private var reminderEnabled = true
    @State private var reminderLeadMinutes = 0
    @State private var enableHealth = true

    private static let totalSteps = 5

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    contentView
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle("Simple GLP")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<Self.totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? AppTheme.brand : AppTheme.surfaceStroke.opacity(0.5))
                    .frame(height: 6)
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch step {
        case 0:
            welcomeStep
        case 1:
            medicationStep
        case 2:
            scheduleStep
        case 3:
            reminderStep
        default:
            healthStep
        }
    }

    private func stepHeader(icon: String, iconColor: Color, title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 76, height: 76)
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(iconColor)
            }
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(AppTheme.muted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader(
                icon: "syringe.fill",
                iconColor: AppTheme.brand,
                title: "One big button.",
                subtitle: "Tap it when you take your shot. That's it."
            )
            Text("Optional details, history, and reminders are there if you want them.")
                .font(.body)
                .foregroundStyle(AppTheme.muted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var medicationStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader(
                icon: "pills.fill",
                iconColor: AppTheme.brand,
                title: "What are you taking?",
                subtitle: "Pick your medication and current dose."
            )
            VStack(spacing: 14) {
                HStack {
                    Text("Medication")
                        .font(.body)
                    Spacer()
                    Picker("Medication", selection: $medication) {
                        ForEach(GLPMedication.allCases) { med in
                            Text(med.rawValue).tag(med)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .onChange(of: medication) { _, newValue in
                    let presets = newValue.standardDoseStepsMg
                    if presets.isEmpty {
                        useCustomDose = true
                    } else if !presets.contains(doseMg) {
                        doseMg = presets.first ?? doseMg
                        useCustomDose = false
                    }
                }
                if medication == .other {
                    TextField("Medication name", text: $customMedicationName)
                        .textFieldStyle(.roundedBorder)
                }
                doseField
            }
            .padding(18)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    @ViewBuilder
    private var doseField: some View {
        let presets = medication.standardDoseStepsMg
        if !presets.isEmpty && !useCustomDose {
            HStack {
                Text("Current dose")
                    .font(.body)
                Spacer()
                Picker("Current dose", selection: $doseMg) {
                    ForEach(presets, id: \.self) { value in
                        Text(Self.format(value)).tag(value)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            Button("Use custom dose") { useCustomDose = true }
                .font(.footnote)
        } else {
            HStack {
                Text("Current dose (mg)")
                    .font(.body)
                Spacer()
                TextField("0.25", value: $doseMg, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
            if !presets.isEmpty {
                Button("Use standard dose") {
                    useCustomDose = false
                    if !presets.contains(doseMg) {
                        doseMg = presets.first ?? doseMg
                    }
                }
                .font(.footnote)
            }
        }
    }

    private static func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return (formatter.string(from: value as NSNumber) ?? "\(value)") + " mg"
    }

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader(
                icon: "calendar",
                iconColor: AppTheme.calm,
                title: "How often do you dose?",
                subtitle: "We'll line up your dose rhythm from here."
            )
            VStack(alignment: .leading, spacing: 18) {
                Stepper(value: $intervalDays, in: 1...90) {
                    HStack {
                        Text("Repeat every")
                            .font(.body)
                        Spacer()
                        Text(GLPScheduleFormat.intervalLabel(intervalDays))
                            .foregroundStyle(.secondary)
                    }
                }
                DatePicker(
                    intervalDays == 7 ? "Start date" : "First dose",
                    selection: $startDate,
                    displayedComponents: .date
                )
                .font(.body)
                if intervalDays == 7 {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Day of week")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        Picker("Day", selection: $weekday) {
                            ForEach(1..<8, id: \.self) { d in
                                Text(Calendar.current.shortWeekdaySymbols[d - 1]).tag(d)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                DatePicker(
                    "Time",
                    selection: timeOfDay,
                    displayedComponents: .hourAndMinute
                )
                .font(.body)
            }
            .padding(18)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var timeOfDay: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                hour = comps.hour ?? hour
                minute = comps.minute ?? minute
            }
        )
    }

    private var reminderStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader(
                icon: "bell.fill",
                iconColor: AppTheme.warm,
                title: "Reminders",
                subtitle: "A gentle nudge so a busy week doesn't push your shot."
            )
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Remind me on shot day", isOn: $reminderEnabled)
                    .font(.body)
                if reminderEnabled {
                    Divider()
                    Stepper(value: $reminderLeadMinutes, in: 0...180, step: 15) {
                        HStack {
                            Text("Lead time")
                                .font(.body)
                            Spacer()
                            Text("\(reminderLeadMinutes) min before")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("We'll ask permission to send notifications. If you decline, reminders won't fire — you can enable them later in iOS Settings.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(18)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var healthStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader(
                icon: "heart.text.square.fill",
                iconColor: .pink,
                title: "Health context",
                subtitle: "See how each dose lands against your real data."
            )
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Auto-capture Health context", isOn: $enableHealth)
                    .font(.body)
                Text("Simple GLP can read weight, glucose, activity, sleep, and more when you log a shot. If you skip this or deny permission, you can turn it on later in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("This adds context to your log — it isn't medical advice.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            Button(action: handlePrimary) {
                Text(step == Self.totalSteps - 1 ? "Finish" : "Continue")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.brand, in: Capsule())
                    .shadow(color: AppTheme.brand.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)

            if step > 0 {
                Button("Back") { step -= 1 }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
                    .buttonStyle(.plain)
            }
        }
    }

    private func handlePrimary() {
        if step == Self.totalSteps - 1 {
            finishOnboarding()
        } else {
            step += 1
        }
    }

    private func finishOnboarding() {
        let plan = MedicationPlan(
            medication: medication,
            customMedicationName: medication == .other ? customMedicationName : nil,
            doseMg: doseMg,
            scheduleStartDate: startDate,
            preferredWeekday: weekday,
            preferredHour: hour,
            preferredMinute: minute,
            intervalDays: intervalDays,
            reminderEnabled: reminderEnabled,
            reminderLeadMinutes: reminderLeadMinutes
        )
        modelContext.insert(plan)
        try? modelContext.save()
        if enableHealth {
            Task {
                try? await HealthKitService.shared.prepareAuthorizationDuringOnboarding()
            }
        }
        if reminderEnabled {
            Task { await ReminderService.scheduleNextShotReminder(for: plan) }
        }
        hasCompletedOnboarding = true
    }
}
