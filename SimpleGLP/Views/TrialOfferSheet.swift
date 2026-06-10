import SwiftUI

/// Focused one-decision trial offer. Unlike the full paywall, this sheet sells a
/// single action — start the free trial with one tap (direct StoreKit purchase of
/// the trial-bearing yearly package) — with "See all plans" chaining to the full
/// paywall for users who want to compare. This pattern is the highest trial-start
/// surface in the sibling headache app.
struct TrialOfferSheet: View {
    let offerLabel: String?
    /// Recurring price after the trial, e.g. "$19.99 / year". Only required in
    /// `directPurchase` mode (Apple 3.1.2 needs price + terms before purchase).
    let priceLabel: String?
    /// When true the primary button buys the trial product directly via StoreKit
    /// and the sheet shows compliant billing disclosure + a "See all plans" link.
    /// When false it chains to the full native paywall via `onSeeAllPlans`.
    let directPurchase: Bool
    let isPurchasing: Bool
    let errorMessage: String?
    let onStartTrial: () -> Void
    let onSeeAllPlans: () -> Void
    let onDismiss: () -> Void
    @EnvironmentObject private var store: StoreService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateGlow = false
    @State private var shimmerPhase: CGFloat = -1
    @State private var isRestoring = false
    @State private var restoreMessage: String?

    private var brandGradient: LinearGradient {
        LinearGradient(colors: [AppTheme.brand, AppTheme.calm], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Extract a clean period phrase from an intro label like `"7-day free trial"` → `"7 days"`.
    /// Falls back to nil when the label doesn't match the expected shape.
    private var trialPeriodPhrase: String? {
        guard let offerLabel else { return nil }
        let scanner = Scanner(string: offerLabel)
        var value: Int = 0
        guard scanner.scanInt(&value) else { return nil }
        _ = scanner.scanString("-")
        guard let unit = scanner.scanCharacters(from: .letters) else { return nil }
        let plural = value == 1 ? unit : "\(unit)s"
        return "\(value) \(plural)"
    }

    private var headline: String {
        if let period = trialPeriodPhrase {
            return "\(period) of Pro, free."
        }
        return "Try Simple GLP Pro free."
    }

    private var subheadline: String {
        if trialPeriodPhrase != nil {
            return "Dose-day nudges and drift alerts, on autopilot. Free until your trial ends."
        }
        return "Dose-day nudges and drift alerts, free for eligible new subscribers."
    }

    /// Leads with the alerts payoff. "On-device" is intentionally demoted to a
    /// single trust line below the cards so the value props get top billing.
    private var trialBullets: [TrialBullet] {
        [
            TrialBullet(
                icon: "bell.badge.fill",
                tint: AppTheme.warm,
                title: "Never miss a dose",
                detail: "A nudge before a dose slips, tuned to your real schedule."
            ),
            TrialBullet(
                icon: "waveform.path.ecg",
                tint: AppTheme.calm,
                title: "Catch drift early",
                detail: "Know when shots creep later week over week."
            )
        ]
    }

    /// Compliant billing disclosure shown beside the buy control (Apple 3.1.2): trial
    /// length, recurring price, auto-renew, and how to cancel — condensed to one line.
    private var billingDisclosure: String {
        if directPurchase, let priceLabel {
            if let period = trialPeriodPhrase {
                return "Free for \(period), then \(priceLabel). Auto-renews; cancel anytime in Settings at least 24h before it ends."
            }
            return "Then \(priceLabel). Auto-renews; cancel anytime in Settings at least 24h before it ends."
        }
        return "Billed through Apple. No charge during the trial."
    }

    private var glowAnimation: Animation {
        .easeInOut(duration: 2.2).repeatForever(autoreverses: true)
    }

    private var shimmerAnimation: Animation {
        .linear(duration: 2.6).repeatForever(autoreverses: false).delay(0.4)
    }

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()
            Circle()
                .fill(AppTheme.brand.opacity(0.20))
                .frame(width: 220, height: 220)
                .blur(radius: 36)
                .offset(x: animateGlow ? 96 : -96, y: animateGlow ? -220 : -180)
                .animation(glowAnimation, value: animateGlow)
            Circle()
                .fill(AppTheme.calm.opacity(0.18))
                .frame(width: 180, height: 180)
                .blur(radius: 34)
                .offset(x: animateGlow ? -110 : 110, y: animateGlow ? 250 : 210)
                .animation(glowAnimation, value: animateGlow)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(brandGradient)
                            .frame(width: 76, height: 76)
                            .shadow(color: AppTheme.brand.opacity(0.4), radius: 16, x: 0, y: 6)
                            .scaleEffect(animateGlow ? 1.07 : 0.96)
                        Circle()
                            .stroke(.white.opacity(0.35), lineWidth: 1)
                            .frame(width: 64, height: 64)
                            .scaleEffect(animateGlow ? 1.04 : 0.98)
                        Image(systemName: "sparkles")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(animateGlow ? 6 : -6))
                    }
                    .padding(.top, 18)
                    .animation(glowAnimation, value: animateGlow)

                    VStack(spacing: 6) {
                        Text(headline)
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(AppTheme.text)
                            .multilineTextAlignment(.center)
                            .overlay(shimmerOverlay)
                            .mask(
                                Text(headline)
                                    .font(.system(.title, design: .rounded, weight: .bold))
                                    .multilineTextAlignment(.center)
                            )
                        Text(subheadline)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(AppTheme.muted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 12)
                    }

                    VStack(spacing: 10) {
                        ForEach(trialBullets) { bullet in
                            TrialBulletRow(bullet: bullet)
                        }
                    }
                    .padding(.horizontal, 4)

                    Label("All on-device. Your shots never leave your phone.", systemImage: "lock.shield")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(AppTheme.muted)
                        .labelStyle(.titleAndIcon)

                    Group {
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.18), value: errorMessage)

                    VStack(spacing: 10) {
                        Button(action: onStartTrial) {
                            ZStack {
                                Text("Start My Free Trial")
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundStyle(.white)
                                    .opacity(isPurchasing ? 0 : 1)
                                if isPurchasing {
                                    ProgressView()
                                        .tint(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(brandGradient, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(isPurchasing)

                        Text(billingDisclosure)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        if directPurchase {
                            Button(action: onSeeAllPlans) {
                                Text("See all plans")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(AppTheme.brand)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .disabled(isPurchasing)
                        }

                        Button(action: onDismiss) {
                            Text("Not now")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(AppTheme.muted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .disabled(isPurchasing)

                        Button(action: startRestore) {
                            Text(isRestoring ? "Restoring…" : "Restore Purchases")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(AppTheme.muted)
                        }
                        .buttonStyle(.plain)
                        .disabled(isRestoring || isPurchasing)

                        if let restoreMessage {
                            Text(restoreMessage)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(AppTheme.muted)
                                .multilineTextAlignment(.center)
                        }
                    }

                    HStack(spacing: 4) {
                        Link("Terms", destination: PaywallLinks.standardEULA)
                        Text("·")
                        Link("Privacy Policy", destination: PaywallLinks.privacyPolicy)
                    }
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            animateGlow = true
            shimmerPhase = 1.4
        }
    }

    private func startRestore() {
        restoreMessage = nil
        isRestoring = true
        Task { @MainActor in
            defer { isRestoring = false }
            await store.restorePurchases()
            if !store.isProUnlocked {
                restoreMessage = store.lastError ?? "No previous Simple GLP Pro purchase was found on this Apple ID."
            }
        }
    }

    private var shimmerOverlay: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .white.opacity(0.55), location: 0.5),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * 0.5)
            .offset(x: shimmerPhase * width)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
            .animation(shimmerAnimation, value: shimmerPhase)
        }
    }
}

private struct TrialBullet: Identifiable {
    let id = UUID()
    let icon: String
    let tint: Color
    let title: String
    let detail: String
}

private struct TrialBulletRow: View {
    let bullet: TrialBullet

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(bullet.tint.opacity(0.18))
                    .frame(width: 34, height: 34)
                Image(systemName: bullet.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(bullet.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(bullet.title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.text)
                Text(bullet.detail)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.surface.opacity(0.85))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(bullet.tint.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bullet.title). \(bullet.detail)")
    }
}
