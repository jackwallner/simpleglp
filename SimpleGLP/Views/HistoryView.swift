import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShotEvent.timestamp, order: .reverse) private var events: [ShotEvent]
    @State private var selectedEvent: ShotEvent?
    @State private var showEdit = false

    var body: some View {
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
                        deleteEvents(at: indexSet, in: month)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("History")
        .sheet(item: $selectedEvent) { event in
            EditEventSheet(event: event)
        }
    }

    private var groupedEvents: [String: [ShotEvent]] {
        Dictionary(grouping: events) { event in
            event.timestamp.formatted(.dateTime.year().month())
        }
    }

    private func historyRow(event: ShotEvent) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.timestamp, style: .date)
                    .font(.headline)
                Text(event.timestamp, style: .time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(event.doseMg, specifier: "%.2f") mg")
                    .font(.subheadline.weight(.semibold))
                StatusPill(label: event.scheduleStatus.label, tint: event.scheduleStatus == .onSchedule ? AppTheme.brand : AppTheme.warm)
                if event.captureStatus == .complete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.brand)
                        .font(.caption)
                }
            }
        }
    }

    private func deleteEvents(at offsets: IndexSet, in month: String) {
        guard let items = groupedEvents[month] else { return }
        for index in offsets {
            modelContext.delete(items[index])
        }
        try? modelContext.save()
    }
}
