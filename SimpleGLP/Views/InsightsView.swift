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
                        Text("Keep logging your shots. Insights appear once you've logged \(ProactiveAlertsEngine.minimumSampleSize) — you have \(events.count) so far.")
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
        .onAppear {
            NotificationCenter.default.post(name: .glpPatternsDidAppear, object: nil)
        }
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
        VStack(spacing: 16) {
            previewHeader
            previewStack
            unlockCallout
        }
        .contentShape(Rectangle())
        .onTapGesture { showPaywall = true }
    }

    private var previewHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.brand)
            Text("What Pro watches for you")
                .font(.headline)
                .foregroundStyle(AppTheme.text)
            Spacer(minLength: 0)
            Text("PREVIEW")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(AppTheme.brand)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.brandSoft, in: Capsule())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("What Pro watches for you. Preview.")
    }

    // A light, legible blur reads as "locked sample" without hiding the value;
    // the bottom fades into the page so it feels like there's more behind the wall.
    private var previewStack: some View {
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
        .blur(radius: 2.5)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.6),
                    .init(color: .black.opacity(0.12), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var unlockCallout: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.brand)
                        .frame(width: 40, height: 40)
                        .shadow(color: AppTheme.brand.opacity(0.35), radius: 10, x: 0, y: 4)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock with Pro")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                    Text("Pattern alerts and dose-day nudges, on autopilot.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            Button {
                showPaywall = true
            } label: {
                Text("See Plans")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(AppTheme.brand, in: Capsule())
                    .shadow(color: AppTheme.brand.opacity(0.35), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Unlock Pro — see plans")
            .accessibilityHint("Opens upgrade options")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(AppTheme.surfaceStroke.opacity(0.6), lineWidth: 1)
                )
        )
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
