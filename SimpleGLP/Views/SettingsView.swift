import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var store: StoreService
    @AppStorage(GLPStorageKey.appearance.rawValue, store: GLPAppGroup.userDefaults) private var appearanceRaw = AppAppearance.system.rawValue
    @AppStorage(GLPStorageKey.promptForDetails.rawValue, store: GLPAppGroup.userDefaults) private var promptForDetails = false
    @State private var showPaywall = false
    @State private var showProAlerts = false

    var body: some View {
        List {
            Section("Plan") {
                NavigationLink("Medication & schedule") {
                    PlanEditorView()
                }
            }

            Section("Display") {
                Picker("Appearance", selection: $appearanceRaw) {
                    ForEach(AppAppearance.allCases) { app in
                        Text(app.title).tag(app.rawValue)
                    }
                }
            }

            Section("Logging") {
                Toggle("Prompt for details after shot", isOn: $promptForDetails)
            }

            Section("Pro") {
                if store.isProUnlocked {
                    Button("Proactive Alerts") { showProAlerts = true }
                    Button("Restore purchases") {
                        Task { await store.restorePurchases() }
                    }
                } else {
                    Button("Upgrade to Pro") { showPaywall = true }
                    Button("Restore purchases") {
                        Task { await store.restorePurchases() }
                    }
                }
            }

            Section("Data") {
                NavigationLink("Export") {
                    ExportView()
                }
                NavigationLink("Import") {
                    ImportView()
                }
            }

            Section("About") {
                Text("Simple GLP does not provide medical advice. Always follow your prescriber’s instructions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("Settings")
        .sheet(isPresented: $showPaywall) {
            SimplePaywallView()
        }
        .sheet(isPresented: $showProAlerts) {
            ProAlertsConfigView()
        }
    }
}

struct PlanEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var plan: MedicationPlan?
    @State private var medication: GLPMedication = .ozempic
    @State private var customName = ""
    @State private var doseMg = 0.25
    @State private var weekday = Calendar.current.component(.weekday, from: Date())
    @State private var hour = 9
    @State private var minute = 0
    @State private var reminderEnabled = true
    @State private var reminderLeadMinutes = 0

    var body: some View {
        Form {
            Section("Medication") {
                Picker("Medication", selection: $medication) {
                    ForEach(GLPMedication.allCases) { Text($0.rawValue).tag($0) }
                }
                if medication == .other {
                    TextField("Custom name", text: $customName)
                }
                HStack {
                    Text("Dose (mg)")
                    Spacer()
                    TextField("0.25", value: $doseMg, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }
            Section("Schedule") {
                Picker("Day", selection: $weekday) {
                    ForEach(1..<8, id: \.self) { d in
                        Text(Calendar.current.weekdaySymbols[d - 1]).tag(d)
                    }
                }
                .pickerStyle(.segmented)
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
            }
            Section("Reminders") {
                Toggle("Enabled", isOn: $reminderEnabled)
                if reminderEnabled {
                    Stepper(value: $reminderLeadMinutes, in: 0...180, step: 15) {
                        HStack {
                            Text("Lead time")
                            Spacer()
                            Text("\(reminderLeadMinutes) min")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Medication plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
        .onAppear {
            let p = PlanStore.ensurePlan(in: modelContext)
            plan = p
            medication = p.medication
            customName = p.customMedicationName ?? ""
            doseMg = p.doseMg
            weekday = p.preferredWeekday
            hour = p.preferredHour
            minute = p.preferredMinute
            reminderEnabled = p.reminderEnabled
            reminderLeadMinutes = p.reminderLeadMinutes
        }
    }

    private func save() {
        guard let plan else { return }
        plan.medication = medication
        plan.customMedicationName = medication == .other ? customName : nil
        plan.doseMg = doseMg
        plan.preferredWeekday = weekday
        plan.preferredHour = hour
        plan.preferredMinute = minute
        plan.reminderEnabled = reminderEnabled
        plan.reminderLeadMinutes = reminderLeadMinutes
        plan.updatedAt = .now
        try? modelContext.save()
        if reminderEnabled {
            Task { await ReminderService.scheduleNextShotReminder(for: plan) }
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [ReminderService.shotReminderIdentifier])
        }
        dismiss()
    }
}

struct ExportView: View {
    var body: some View {
        Text("Export placeholder")
            .navigationTitle("Export")
    }
}

struct ImportView: View {
    var body: some View {
        Text("Import placeholder")
            .navigationTitle("Import")
    }
}
