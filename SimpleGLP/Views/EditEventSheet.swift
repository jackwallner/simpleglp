import SwiftData
import SwiftUI

struct EditEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let event: ShotEvent
    @AppStorage(GLPStorageKey.isPillPlan.rawValue, store: GLPAppGroup.userDefaults) private var isPillPlan = false
    @State private var timestamp: Date = .now
    @State private var doseMg: Double = 0
    /// nil = not recorded. A default here would write a site nobody chose.
    @State private var site: InjectionSite?
    @State private var notes = ""
    /// -1 = not rated, so opening the sheet for a note doesn't record a 0 for every feeling.
    @State private var nausea = FeelingRow.unrated
    @State private var appetite = FeelingRow.unrated
    @State private var foodNoise = FeelingRow.unrated
    @State private var wellbeing = FeelingRow.unrated
    @State private var saveError: String?
    @State private var confirmDelete = false
    /// Set before the delete so the sheet stops reading the model it is about to remove.
    @State private var isDeleted = false

    var body: some View {
        if isDeleted {
            Color.clear
        } else {
            editor
        }
    }

    private var editor: some View {
        NavigationStack {
            Form {
                Section(isPillPlan ? "Pill" : "Shot") {
                    DatePicker("When", selection: $timestamp)
                    HStack {
                        Text("Dose (mg)")
                        Spacer()
                        TextField("0.25", value: $doseMg, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
                Section("Basics") {
                    if !isPillPlan {
                        Picker("Injection site", selection: $site) {
                            Text("Not recorded").tag(InjectionSite?.none)
                            ForEach(InjectionSite.allCases) { Text($0.rawValue).tag(InjectionSite?.some($0)) }
                        }
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    FeelingRow(title: "Nausea", value: $nausea)
                    FeelingRow(title: "Appetite", value: $appetite)
                    FeelingRow(title: "Food noise", value: $foodNoise)
                    FeelingRow(title: "Wellbeing", value: $wellbeing)
                } header: {
                    Text("How do you feel?")
                } footer: {
                    Text("0 to 5. Leave any you don’t want to rate.")
                }
                healthContextSection
                Section {
                    Button("Delete this \(isPillPlan ? "pill" : "shot")", role: .destructive) { confirmDelete = true }
                }
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
        .onAppear {
            timestamp = event.timestamp
            doseMg = event.doseMg
            site = event.injectionSite
            notes = event.userNotes ?? ""
            nausea = event.nausea ?? FeelingRow.unrated
            appetite = event.appetite ?? FeelingRow.unrated
            foodNoise = event.foodNoise ?? FeelingRow.unrated
            wellbeing = event.wellbeing ?? FeelingRow.unrated
        }
        .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the dose and its details. It can’t be undone.")
        }
        .alert(
            "Couldn't save",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "Try again.")
        }
    }

    @ViewBuilder
    private var healthContextSection: some View {
        let rows = healthRows
        if !rows.isEmpty || event.healthStatus != .captured {
            Section {
                ForEach(rows, id: \.label) { row in
                    HStack {
                        Text(row.label)
                        Spacer()
                        Text(row.value)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                if rows.isEmpty {
                    Text(healthStatusCopy)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if event.healthStatus != .captured, let msg = event.healthStatusMessage, !msg.isEmpty {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("That day")
            } footer: {
                Text("Read from Apple Health on device. Nothing is uploaded.")
            }
        }
    }

    private var healthStatusCopy: String {
        switch event.healthStatus {
        case .captured: return ""
        case .pending: return "Adding Health context…"
        case .unavailable: return event.healthStatusMessage ?? "Health context unavailable."
        case .failed: return event.healthStatusMessage ?? "Could not read Health context."
        }
    }

    private var healthRows: [(label: String, value: String)] {
        var rows: [(label: String, value: String)] = []
        if let kg = event.bodyMassKg {
            let lbs = kg * 2.2046226218
            rows.append(("Weight", String(format: "%.1f kg · %.1f lb", kg, lbs)))
        }
        if let steps = event.stepsToday {
            rows.append(("Steps", steps.formatted()))
        }
        if let sleep = event.sleepHoursLastNight {
            rows.append(("Sleep", String(format: "%.1f h", sleep)))
        }
        if let protein = event.proteinGramsToday {
            rows.append(("Protein", String(format: "%.0f g", protein)))
        }
        if let glucose = event.bloodGlucoseMgPerDL {
            rows.append(("Glucose", String(format: "%.0f mg/dL", glucose)))
        }
        if let energy = event.activeEnergyKcalToday {
            rows.append(("Active kcal", String(format: "%.0f", energy)))
        }
        if let hr = event.restingHeartRateBpm {
            rows.append(("Resting HR", String(format: "%.0f bpm", hr)))
        }
        return rows
    }

    private func save() {
        guard doseMg > 0 else {
            saveError = "Enter a dose greater than 0 mg."
            return
        }
        let timestampChanged = timestamp != event.timestamp
        event.timestamp = timestamp
        event.doseMg = doseMg
        if !isPillPlan {
            event.injectionSite = site
        }
        event.userNotes = notes.isEmpty ? nil : notes
        event.nausea = FeelingRow.stored(nausea)
        event.appetite = FeelingRow.stored(appetite)
        event.foodNoise = FeelingRow.stored(foodNoise)
        event.wellbeing = FeelingRow.stored(wellbeing)

        if timestampChanged {
            let plan = PlanStore.currentPlan(in: modelContext)
            let others = ((try? modelContext.fetch(FetchDescriptor<ShotEvent>())) ?? [])
                .filter { $0.id != event.id }
            let match = ScheduleEngine.match(timestamp: timestamp, plan: plan, existingEvents: others)
            event.scheduledDate = match.scheduledDate
            event.scheduleStatus = match.status
            event.minutesFromSchedule = match.minutesFromSchedule
        }

        do {
            try modelContext.save()
        } catch {
            saveError = "The entry could not be saved. Please try again."
            return
        }
        DoseRoutineService.historyDidChange(in: modelContext)
        dismiss()
    }

    private func delete() {
        isDeleted = true
        modelContext.delete(event)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            isDeleted = false
            saveError = "The entry could not be deleted. Please try again."
            return
        }
        DoseRoutineService.historyDidChange(in: modelContext)
        dismiss()
    }
}

/// A 0 to 5 rating that starts unrated and can be cleared again.
struct FeelingRow: View {
    static let unrated = -1
    let title: String
    @Binding var value: Int

    static func stored(_ value: Int) -> Int? { value == unrated ? nil : value }

    var body: some View {
        Stepper(value: $value, in: Self.unrated...5) {
            HStack {
                Text(title)
                Spacer()
                Text(value == Self.unrated ? "–" : "\(value)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
