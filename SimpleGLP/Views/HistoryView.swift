import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShotEvent.timestamp, order: .reverse) private var events: [ShotEvent]
    @AppStorage(GLPStorageKey.isPillPlan.rawValue, store: GLPAppGroup.userDefaults) private var isPillPlan = false
    @State private var selectedEvent: ShotEvent?
    @State private var showEdit = false
    @State private var pendingDeletion: [ShotEvent] = []
    @State private var deleteError: String?

    var body: some View {
        Group {
            if events.isEmpty {
                ContentUnavailableView {
                    Label("Nothing logged yet", systemImage: isPillPlan ? "pills" : "syringe")
                } description: {
                    Text("Your doses will appear here. Tap the big button on the One Tap tab to log your first.")
                }
            } else {
                List {
                    ForEach(groupedEvents.keys.sorted(by: >), id: \.self) { month in
                        Section(month.formatted(.dateTime.year().month())) {
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
            Text("Deleting an entry removes its dose, schedule status, and any logged details and Health context. This can't be undone.")
        }
        .alert(
            "Couldn't delete",
            isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "Please try again.")
        }
    }

    private var confirmDeleteTitle: String {
        pendingDeletion.count == 1 ? "Delete this entry?" : "Delete \(pendingDeletion.count) entries?"
    }

    /// Keyed by the first instant of each month so sections sort by date, not by month name.
    private var groupedEvents: [Date: [ShotEvent]] {
        let calendar = Calendar.current
        return Dictionary(grouping: events) { event in
            calendar.dateInterval(of: .month, for: event.timestamp)?.start ?? event.timestamp
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

    private func requestDelete(at offsets: IndexSet, in month: Date) {
        guard let items = groupedEvents[month] else { return }
        pendingDeletion = offsets.map { items[$0] }
    }

    private func performPendingDeletion() {
        for event in pendingDeletion {
            modelContext.delete(event)
        }
        do {
            try modelContext.save()
        } catch {
            // Put the rows back rather than showing a delete that will undo
            // itself on the next launch.
            modelContext.rollback()
            deleteError = "The entry could not be deleted. Please try again."
        }
        pendingDeletion = []
        DoseRoutineService.historyDidChange(in: modelContext)
    }
}
