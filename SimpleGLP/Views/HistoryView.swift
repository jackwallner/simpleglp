import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShotEvent.timestamp, order: .reverse) private var events: [ShotEvent]
    @State private var selectedEvent: ShotEvent?
    @State private var showEdit = false
    @State private var pendingDeletion: [ShotEvent] = []

    var body: some View {
        Group {
            if events.isEmpty {
                ContentUnavailableView {
                    Label("No shots logged yet", systemImage: "syringe")
                } description: {
                    Text("Your shots will appear here. Tap the big button on the One Tap tab to log your first.")
                }
            } else {
                List {
                    ForEach(groupedEvents.keys.sorted(by: >), id: \.self) { month in
                        Section(month) {
                            ForEach(groupedEvents[month] ?? []) { event in
                                Button {
                                    selectedEvent = event
                                    showEdit = true
                                } label: {
                                    historyRow(event: event)
                                }
                            }
                            .onDelete { indexSet in
                                requestDelete(at: indexSet, in: month)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("History")
        .sheet(item: $selectedEvent) { event in
            EditEventSheet(event: event)
        }
        .confirmationDialog(
            confirmDeleteTitle,
            isPresented: Binding(
                get: { !pendingDeletion.isEmpty },
                set: { if !$0 { pendingDeletion = [] } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { performPendingDeletion() }
            Button("Cancel", role: .cancel) { pendingDeletion = [] }
        } message: {
            Text("Deleting a shot removes its dose, schedule status, and any logged details and Health context. This can't be undone.")
        }
    }

    private var confirmDeleteTitle: String {
        pendingDeletion.count == 1 ? "Delete this shot?" : "Delete \(pendingDeletion.count) shots?"
    }

    private var groupedEvents: [String: [ShotEvent]] {
        Dictionary(grouping: events) { event in
            event.timestamp.formatted(.dateTime.year().month())
        }
    }

    private func historyRow(event: ShotEvent) -> some View {
        let pillTint: Color = event.scheduleStatus == .onSchedule ? AppTheme.brand : AppTheme.warm
        let doseText = String(format: "%.2f mg", event.doseMg)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.timestamp, style: .date)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Text(event.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Text(doseText)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.text)
            VStack(alignment: .trailing, spacing: 2) {
                StatusPill(label: event.scheduleStatus.label, tint: pillTint)
                if let rationale = event.scheduleRationale {
                    Text(rationale)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func requestDelete(at offsets: IndexSet, in month: String) {
        guard let items = groupedEvents[month] else { return }
        pendingDeletion = offsets.map { items[$0] }
    }

    private func performPendingDeletion() {
        for event in pendingDeletion {
            modelContext.delete(event)
        }
        try? modelContext.save()
        pendingDeletion = []
    }
}
