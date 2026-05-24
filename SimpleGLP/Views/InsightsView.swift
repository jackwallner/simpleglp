import SwiftData
import SwiftUI

struct InsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var store: StoreService
    @Query(sort: \ShotEvent.timestamp, order: .forward) private var events: [ShotEvent]
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if events.count < ProactiveAlertsEngine.minimumSampleSize {
                    Card {
                        Text("Keep logging your shots. Insights appear once you have enough data.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                } else {
                    adherenceCard
                    timingCard
                }

                if !store.isProUnlocked {
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Go Pro")
                                .font(.headline)
                            Text("Unlock pattern alerts and deeper schedule insights.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button("Upgrade") { showPaywall = true }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.brand)
                        }
                    }
                    .padding(.horizontal)
                } else {
                    NavigationLink(destination: ProAlertsConfigView()) {
                        Card {
                            HStack {
                                Text("Proactive Alerts")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 40)
            }
            .padding(.top, 16)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("Patterns")
        .sheet(isPresented: $showPaywall) {
            SimplePaywallView(paywallImpressionId: "simpleglp_insights_sheet")
                .environmentObject(store)
        }
    }

    private var adherenceCard: some View {
        let total = events.count
        let onTime = events.filter { $0.scheduleStatus == .onSchedule }.count
        let percentage = total > 0 ? Double(onTime) / Double(total) : 0
        return Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Schedule adherence")
                    .font(.headline)
                Text("\(Int(percentage * 100))% on schedule")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.brand)
                Text("\(onTime) of \(total) shots logged within the expected window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    private var timingCard: some View {
        let days = events.map(\.weekdayIndex)
        let counts = Dictionary(grouping: days, by: { $0 }).mapValues(\.count)
        let top = counts.max { $0.value < $1.value }
        let symbols = Calendar.current.weekdaySymbols
        let name = top.map { symbols[max(0, min(symbols.count - 1, $0.key - 1))] } ?? "—"
        return Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Timing pattern")
                    .font(.headline)
                Text("Most shots on \(name)")
                    .font(.title3.weight(.semibold))
                Text("Weekday preference from your history.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }
}
