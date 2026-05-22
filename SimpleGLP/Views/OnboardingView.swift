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
    @State private var hour = 9
    @State private var minute = 0
    @State private var reminderEnabled = true
    @State private var reminderLeadMinutes = 0
    @State private var enableHealth = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                Spacer().frame(height: 24)
                contentView
                Spacer()
                bottomBar
            }
            .padding(.horizontal, 24)
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle("Simple GLP")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= step ? AppTheme.brand : Color(.systemGray5))
                    .frame(height: 4)
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

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("One big button.")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.text)
            Text("Tap it when you take your shot. That’s it.")
                .font(.title3)
                .foregroundStyle(AppTheme.text)
            Text("Optional details, history, and reminders are there if you want them.")
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    private var medicationStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What are you taking?")
                .font(.title2.weight(.semibold))
            VStack(spacing: 12) {
                HStack {
                    Text("Medication")
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
            .padding(16)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Spacer()
        }
    }

    @ViewBuilder
    private var doseField: some View {
        let presets = medication.standardDoseStepsMg
        if !presets.isEmpty && !useCustomDose {
            HStack {
                Text("Current dose")
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
        VStack(alignment: .leading, spacing: 20) {
            Text("When is your shot day?")
                .font(.title2.weight(.semibold))
            VStack(alignment: .leading, spacing: 16) {
                DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                VStack(alignment: .leading, spacing: 8) {
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
                DatePicker(
                    "Time",
                    selection: timeOfDay,
                    displayedComponents: .hourAndMinute
                )
            }
            .padding(16)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Spacer()
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
        VStack(alignment: .leading, spacing: 20) {
            Text("Reminders")
                .font(.title2.weight(.semibold))
            VStack(spacing: 12) {
                Toggle("Remind me on shot day", isOn: $reminderEnabled)
                if reminderEnabled {
                    Divider()
                    Stepper(value: $reminderLeadMinutes, in: 0...180, step: 15) {
                        HStack {
                            Text("Lead time")
                            Spacer()
                            Text("\(reminderLeadMinutes) min before")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(16)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Spacer()
        }
    }

    private var healthStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Health context")
                .font(.title2.weight(.semibold))
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Auto-capture Health context", isOn: $enableHealth)
                Text("Simple GLP can read weight, glucose, activity, sleep, and more when you log a shot. You can change this later in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Spacer()
        }
    }

    private var bottomBar: some View {
        HStack {
            if step > 0 {
                Button("Back") { step -= 1 }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(step == 4 ? "Finish" : "Next") {
                if step == 4 {
                    finishOnboarding()
                } else {
                    step += 1
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.brand)
        }
        .padding(.vertical, 12)
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
