import StoreKit
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

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
                NavigationLink("Dose schedule") {
                    DoseScheduleView()
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
                    Button("Proactive alerts") { showProAlerts = true }
                } else {
                    Button("Upgrade to Pro") { showPaywall = true }
                }
                if store.isProUnlocked && store.hasSubscription {
                    Button("Manage subscription") {
                        Task { await openManageSubscriptions() }
                    }
                }
                Button("Restore purchases") {
                    Task { await store.restorePurchases() }
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

            Section("Help") {
                Button("Rate or Send Feedback") {
                    ReviewPromptCoordinator.shared.requestEnjoymentPrompt()
                }
                Link("Support", destination: PaywallLinks.support)
                Link("Privacy Policy", destination: PaywallLinks.privacyPolicy)
                Link("Terms of Use", destination: PaywallLinks.termsOfUse)
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
            SimplePaywallView(paywallImpressionId: "simpleglp_settings_sheet")
                .environmentObject(store)
        }
        .sheet(isPresented: $showProAlerts) {
            ProAlertsConfigView()
        }
    }

    private func openManageSubscriptions() async {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        try? await AppStore.showManageSubscriptions(in: scene)
    }
}

struct PlanEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var plan: MedicationPlan?
    @State private var medication: GLPMedication = .ozempic
    @State private var customName = ""
    @State private var doseMg = 0.25
    @State private var useCustomDose = false
    @State private var weekday = Calendar.current.component(.weekday, from: Date())
    @State private var hour = 9
    @State private var minute = 0
    @State private var reminderEnabled = true
    @State private var reminderLeadMinutes = 0
    @State private var notificationsDenied = false

    var body: some View {
        Form {
            Section("Medication") {
                Picker("Medication", selection: $medication) {
                    ForEach(GLPMedication.allCases) { Text($0.rawValue).tag($0) }
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
                    TextField("Custom name", text: $customName)
                }
                doseField
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
                    if notificationsDenied {
                        notificationsOffWarning
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
        .task { notificationsDenied = await ReminderService.isDenied() }
        .onChange(of: reminderEnabled) { _, _ in
            Task { notificationsDenied = await ReminderService.isDenied() }
        }
        .onAppear {
            let p = PlanStore.ensurePlan(in: modelContext)
            plan = p
            medication = p.medication
            customName = p.customMedicationName ?? ""
            doseMg = p.doseMg
            useCustomDose = !p.medication.standardDoseStepsMg.contains(p.doseMg)
            weekday = p.preferredWeekday
            hour = p.preferredHour
            minute = p.preferredMinute
            reminderEnabled = p.reminderEnabled
            reminderLeadMinutes = p.reminderLeadMinutes
        }
    }

    private var notificationsOffWarning: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.warm)
            VStack(alignment: .leading, spacing: 4) {
                Text("Notifications are off")
                    .font(.subheadline.weight(.semibold))
                Text("Reminders won't fire until you turn on notifications for Simple GLP in iOS Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption.weight(.semibold))
            }
        }
    }

    @ViewBuilder
    private var doseField: some View {
        let presets = medication.standardDoseStepsMg
        if !presets.isEmpty && !useCustomDose {
            Picker("Current dose", selection: $doseMg) {
                ForEach(presets, id: \.self) { value in
                    Text(DoseScheduleView.format(value)).tag(value)
                }
            }
            Button("Use custom dose") { useCustomDose = true }
                .font(.footnote)
        } else {
            HStack {
                Text("Dose (mg)")
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

struct DoseScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var plan: MedicationPlan?
    @State private var steps: [DoseStep] = []
    @State private var showAddStep = false

    var body: some View {
        List {
            Section {
                Text("Schedule your titration in advance. On each step's start date, new shots automatically use that dose, so you don't have to remember to change it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let plan {
                Section("Starting dose") {
                    HStack {
                        Text(plan.scheduleStartDate, style: .date)
                        Spacer()
                        Text(Self.format(plan.doseMg))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Scheduled changes") {
                if steps.isEmpty {
                    Text("No scheduled changes yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(steps) { step in
                        HStack {
                            Text(step.startDate, style: .date)
                            Spacer()
                            Text(Self.format(step.doseMg))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete(perform: deleteSteps)
                }
                Button {
                    showAddStep = true
                } label: {
                    Label("Add step", systemImage: "plus")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Dose schedule")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddStep) {
            if let plan {
                AddDoseStepSheet(plan: plan) { reload() }
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        let p = PlanStore.ensurePlan(in: modelContext)
        plan = p
        reload()
    }

    private func reload() {
        steps = (plan?.doseSteps ?? []).sorted { $0.startDate < $1.startDate }
    }

    private func deleteSteps(at offsets: IndexSet) {
        for index in offsets {
            let step = steps[index]
            modelContext.delete(step)
        }
        try? modelContext.save()
        reload()
    }

    static func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return (formatter.string(from: value as NSNumber) ?? "\(value)") + " mg"
    }
}

struct AddDoseStepSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let plan: MedicationPlan
    let onSave: () -> Void

    @State private var startDate = Date()
    @State private var doseMg = 0.25
    @State private var useCustomDose = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Starts on") {
                    DatePicker("Date", selection: $startDate, displayedComponents: .date)
                }
                Section("Dose") {
                    let presets = plan.medication.standardDoseStepsMg
                    if !presets.isEmpty && !useCustomDose {
                        Picker("Dose", selection: $doseMg) {
                            ForEach(presets, id: \.self) { value in
                                Text(DoseScheduleView.format(value)).tag(value)
                            }
                        }
                        Button("Use custom dose") { useCustomDose = true }
                            .font(.footnote)
                    } else {
                        HStack {
                            Text("Dose (mg)")
                            Spacer()
                            TextField("0.25", value: $doseMg, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        if !presets.isEmpty {
                            Button("Use standard dose") {
                                useCustomDose = false
                                if !presets.contains(doseMg) { doseMg = presets.first ?? doseMg }
                            }
                            .font(.footnote)
                        }
                    }
                }
            }
            .navigationTitle("Add step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                }
            }
            .onAppear {
                let presets = plan.medication.standardDoseStepsMg
                if presets.isEmpty {
                    useCustomDose = true
                } else {
                    doseMg = presets.first ?? doseMg
                }
            }
        }
    }

    private func save() {
        let step = DoseStep(startDate: startDate, doseMg: doseMg)
        step.plan = plan
        plan.doseSteps.append(step)
        modelContext.insert(step)
        try? modelContext.save()
        onSave()
        dismiss()
    }
}

struct ExportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var fileURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Text("Export every logged shot as a CSV file you can share or back up.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section {
                if let fileURL {
                    ShareLink(item: fileURL) {
                        Label("Share CSV", systemImage: "square.and.arrow.up")
                    }
                    Text(fileURL.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        generate()
                    } label: {
                        Label("Generate CSV", systemImage: "doc.text")
                    }
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Export")
    }

    private func generate() {
        do {
            fileURL = try ExportService.exportEvents(from: modelContext)
            errorMessage = nil
            ReviewPromptTracker.recordPositiveMoment()
            NotificationCenter.default.post(name: .glpPositiveMomentForReview, object: nil)
        } catch {
            errorMessage = "Could not generate export: \(error.localizedDescription)"
        }
    }
}

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showPicker = false
    @State private var statusMessage: String?
    @State private var isError = false

    var body: some View {
        Form {
            Section {
                Text("Import a Simple GLP CSV export to restore your shot history. Imported shots are added; they don't replace existing entries.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button {
                    showPicker = true
                } label: {
                    Label("Choose CSV file", systemImage: "tray.and.arrow.down")
                }
                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(isError ? .red : .secondary)
                }
            }
        }
        .navigationTitle("Import")
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handle(result)
        }
    }

    private func handle(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let count = try ImportService.importEvents(from: url, into: modelContext)
                isError = false
                statusMessage = count == 1 ? "Imported 1 shot." : "Imported \(count) shots."
            } catch {
                isError = true
                statusMessage = "Could not import: \(error.localizedDescription)"
            }
        case .failure(let error):
            isError = true
            statusMessage = "Could not open file: \(error.localizedDescription)"
        }
    }
}
