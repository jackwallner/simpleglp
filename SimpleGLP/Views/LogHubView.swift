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

            Section("Quick add details") {
                Text("Select a recent shot to add optional details like injection site, symptoms, notes, and how you felt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ForEach(events.prefix(10)) { event in
                    Button {
                        selectedEvent = event
                        showSheet = true
                    } label: {
                        HStack {
                            Text(event.timestamp, style: .date)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
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
    @State private var site: InjectionSite = .abdomen
    @State private var notes = ""
    @State private var nausea: Int = 0
    @State private var appetite: Int = 0
    @State private var foodNoise: Int = 0
    @State private var wellbeing: Int = 0

    var body: some View {
        NavigationStack {
            Form {
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
            site = event.injectionSite ?? .abdomen
            notes = event.userNotes ?? ""
            nausea = event.nausea ?? 0
            appetite = event.appetite ?? 0
            foodNoise = event.foodNoise ?? 0
            wellbeing = event.wellbeing ?? 0
        }
    }

    private func save() {
        event.injectionSite = site
        event.userNotes = notes.isEmpty ? nil : notes
        event.nausea = nausea
        event.appetite = appetite
        event.foodNoise = foodNoise
        event.wellbeing = wellbeing
        try? modelContext.save()
        dismiss()
    }
}
