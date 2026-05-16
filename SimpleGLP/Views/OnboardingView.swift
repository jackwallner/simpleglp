import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(GLPStorageKey.hasCompletedOnboarding.rawValue, store: GLPAppGroup.userDefaults) private var hasCompletedOnboarding = false
    @State private var step = 0
    @State private var medication: GLPMedication = .ozempic
    @State private var customMedicationName = ""
    @State private var doseMg = 0.25
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
            Text("Tap it when you take your shot. That’s it. Optional logging available if you want it.")
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
            Spacer()
        }
    }

    private var medicationStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What are you taking?")
                .font(.title2.weight(.semibold))
            Picker("Medication", selection: $medication) {
                ForEach(GLPMedication.allCases) { med in
                    Text(med.rawValue).tag(med)
                }
            }
            .pickerStyle(.wheel)
            if medication == .other {
                TextField("Medication name", text: $customMedicationName)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("Current dose (mg)")
                Spacer()
                TextField("0.25", value: $doseMg, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
            .padding(.vertical, 8)
            Spacer()
        }
    }

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("When is your shot day?")
                .font(.title2.weight(.semibold))
            DatePicker("Start date", selection: $startDate, displayedComponents: .date)
            HStack {
                Text("Day of week")
                Spacer()
                Picker("Day", selection: $weekday) {
                    ForEach(1..<8, id: \.self) { d in
                        Text(Calendar.current.weekdaySymbols[d - 1]).tag(d)
                    }
                }
                .pickerStyle(.segmented)
            }
            HStack {
                Text("Time")
                Spacer()
                Picker("Hour", selection: $hour) {
                    ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                }
                Text(":")
                Picker("Minute", selection: $minute) {
                    ForEach([0, 15, 30, 45], id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                }
            }
            Spacer()
        }
    }

    private var reminderStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reminders")
                .font(.title2.weight(.semibold))
            Toggle("Remind me on shot day", isOn: $reminderEnabled)
            if reminderEnabled {
                Stepper(value: $reminderLeadMinutes, in: 0...180, step: 15) {
                    HStack {
                        Text("Lead time")
                        Spacer()
                        Text("\(reminderLeadMinutes) min before")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
    }

    private var healthStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Health context")
                .font(.title2.weight(.semibold))
            Toggle("Auto-capture Health context", isOn: $enableHealth)
            Text("Simple GLP can read weight, glucose, activity, sleep, and more when you log a shot. You can change this later in Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
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
