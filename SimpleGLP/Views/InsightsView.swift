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

                if store.isProUnlocked {
                    NavigationLink(destination: ProAlertsConfigView()) {
                        Card {
                            HStack(spacing: 12) {
                                Image(systemName: "bell.badge.fill")
                                    .font(.title3)
                                    .foregroundStyle(AppTheme.brand)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Proactive Alerts")
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.text)
                                    Text("Pattern detection and dose-day nudges.")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                } else {
                    proLockedSection
                        .padding(.horizontal)
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
        let name = top.map { symbols[max(0, min(symbols.count - 1, $0.key - 1))] } ?? "-"
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

    private var proLockedSection: some View {
        ZStack {
            VStack(spacing: 14) {
                ProLockedPreviewCard(
                    icon: "bell.badge.fill",
                    title: "Proactive Alerts",
                    headline: "Dose day in 2 days",
                    detail: "Quiet hours respected. Your usual Tuesday window is 8:00–10:00 AM."
                )
                ProLockedPreviewCard(
                    icon: "waveform.path.ecg",
                    title: "Pattern detection",
                    headline: "Drift detected: +6 hrs over 3 weeks",
                    detail: "Shots are creeping later in the day. A reset nudge can pull your window back in line."
                )
                ProLockedPreviewCard(
                    icon: "calendar.badge.clock",
                    title: "Smart timing",
                    headline: "Best next dose: Tue 8:42 AM",
                    detail: "Based on your last 12 shots, mornings yield your most consistent rhythm."
                )
            }
            .blur(radius: 9)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            unlockOverlay
        }
        .contentShape(Rectangle())
        .onTapGesture { showPaywall = true }
    }

    private var unlockOverlay: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(AppTheme.brand)
                    .frame(width: 48, height: 48)
                    .shadow(color: AppTheme.brand.opacity(0.35), radius: 12, x: 0, y: 5)
                Image(systemName: "lock.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text("Unlock with Pro")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.text)
            Text("See patterns, get nudges, and stay on track on autopilot.")
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button {
                showPaywall = true
            } label: {
                Text("See Plans")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.brand, in: Capsule())
                    .shadow(color: AppTheme.brand.opacity(0.35), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(AppTheme.surfaceStroke.opacity(0.6), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Unlock Pro features")
        .accessibilityHint("Opens upgrade options")
    }
}

private struct ProLockedPreviewCard: View {
    let icon: String
    let title: String
    let headline: String
    let detail: String

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.brandSoft)
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.brand)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                    Text(headline)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
