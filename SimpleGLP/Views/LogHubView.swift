import SwiftData
import SwiftUI

struct LogHubView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShotEvent.timestamp, order: .reverse) private var events: [ShotEvent]
    @State private var selectedEvent: ShotEvent?
    @State private var showSheet = false

    var body: some View {
        List {
            if let latest = events.first {
                Section("Most recent shot") {
                    Button {
                        selectedEvent = latest
                        showSheet = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(latest.timestamp, style: .date)
                                    .font(.headline)
                                Text(latest.timestamp, style: .time)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            StatusPill(label: latest.scheduleStatus.label, tint: latest.scheduleStatus == .onSchedule ? AppTheme.brand : AppTheme.warm)
                        }
                    }
                }
            }

            Section {
                ForEach(events.prefix(10)) { event in
                    Button {
                        selectedEvent = event
                        showSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.timestamp, style: .date)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                                Text(event.timestamp, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            } header: {
                Text("Quick add details")
            } footer: {
                Text("Tap a shot to log injection site, symptoms, notes, and how you felt.")
            }
        }
        .listStyle(.insetGrouped)
        .background(AppTheme.bg.ignoresSafeArea())
        .sheet(item: $selectedEvent) { event in
            EditEventSheet(event: event)
        }
        .navigationTitle("Optional details")
    }
}

struct EditEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let event: ShotEvent
    @State private var timestamp: Date = .now
    @State private var doseMg: Double = 0
    @State private var site: InjectionSite = .abdomen
    @State private var notes = ""
    @State private var nausea: Int = 0
    @State private var appetite: Int = 0
    @State private var foodNoise: Int = 0
    @State private var wellbeing: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Shot") {
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
                    Picker("Injection site", selection: $site) {
                        ForEach(InjectionSite.allCases) { Text($0.rawValue).tag($0) }
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("How do you feel?") {
                    HStack {
                        Text("Nausea")
                        Spacer()
                        Stepper("\(nausea)", value: $nausea, in: 0...5)
                    }
                    HStack {
                        Text("Appetite")
                        Spacer()
                        Stepper("\(appetite)", value: $appetite, in: 0...5)
                    }
                    HStack {
                        Text("Food noise")
                        Spacer()
                        Stepper("\(foodNoise)", value: $foodNoise, in: 0...5)
                    }
                    HStack {
                        Text("Wellbeing")
                        Spacer()
                        Stepper("\(wellbeing)", value: $wellbeing, in: 0...5)
                    }
                }
                healthContextSection
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
            site = event.injectionSite ?? .abdomen
            notes = event.userNotes ?? ""
            nausea = event.nausea ?? 0
            appetite = event.appetite ?? 0
            foodNoise = event.foodNoise ?? 0
            wellbeing = event.wellbeing ?? 0
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
        let timestampChanged = timestamp != event.timestamp
        event.timestamp = timestamp
        event.doseMg = doseMg
        event.injectionSite = site
        event.userNotes = notes.isEmpty ? nil : notes
        event.nausea = nausea
        event.appetite = appetite
        event.foodNoise = foodNoise
        event.wellbeing = wellbeing

        if timestampChanged {
            let plan = PlanStore.currentPlan(in: modelContext)
            let match = ScheduleEngine.match(timestamp: timestamp, plan: plan)
            event.scheduledDate = match.scheduledDate
            event.scheduleStatus = match.status
            event.minutesFromSchedule = match.minutesFromSchedule
        }

        try? modelContext.save()
        dismiss()
    }
}
