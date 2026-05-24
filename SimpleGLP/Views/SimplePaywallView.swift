import SwiftUI
@preconcurrency import RevenueCat

enum PaywallLinks {
    static let privacyPolicy = URL(string: "https://jackwallner.github.io/simpleglp/privacy-policy.html")!
    static let standardEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

/// Native Simple GLP Pro paywall. Purchases flow through `StoreService.purchase`
/// → `Purchases.shared.purchase`; RevenueCat records transactions and entitlements.
struct SimplePaywallView: View {
    @EnvironmentObject private var store: StoreService
    @Environment(\.dismiss) private var dismiss

    var displayCloseButton: Bool = true
    var paywallImpressionId: String?

    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var restoreMessage: String?
    @State private var isRestoring = false

    private let features: [(icon: String, title: String)] = [
        ("bell.badge.fill", "Proactive alerts when your schedule drifts"),
        ("chart.bar.xaxis", "Deeper pattern insights from your shot history"),
        ("calendar.badge.clock", "Personalized timing and adherence trends")
    ]

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            if store.isLoadingProducts && store.products.isEmpty {
                loadingState
            } else if store.products.isEmpty {
                emptyState
            } else {
                content
            }

            if displayCloseButton {
                closeButton
            }
        }
        .onChange(of: store.isProUnlocked) { _, isPro in
            if isPro { dismiss() }
        }
        .task {
            if let paywallImpressionId {
                store.trackPaywallImpression(id: paywallImpressionId)
            }
            if store.products.isEmpty { await store.fetchProducts() }
            selectDefaultPackageIfNeeded()
        }
        .onChange(of: store.products.count) { _, _ in selectDefaultPackageIfNeeded() }
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading plans…")
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.muted)
            Text("Couldn't Load Plans")
                .font(.headline)
                .foregroundStyle(AppTheme.text)
            Text(store.lastError ?? "Check your connection and try again.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again") {
                Task {
                    await store.fetchProducts()
                    selectDefaultPackageIfNeeded()
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.brand)
        }
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                header
                featureList
                planCards
                purchaseSection
            }
            .padding(.horizontal, 24)
            .padding(.top, displayCloseButton ? 56 : 32)
            .padding(.bottom, 32)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(AppTheme.brand)
                    .frame(width: 64, height: 64)
                    .shadow(color: AppTheme.brand.opacity(0.35), radius: 12, x: 0, y: 4)
                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text("Simple GLP Pro")
                .font(.title.weight(.bold))
                .foregroundStyle(AppTheme.text)
            Text("Unlock proactive alerts and personalized pattern insights.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(features, id: \.title) { feature in
                HStack(spacing: 12) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.brand)
                        .frame(width: 24)
                    Text(feature.title)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var planCards: some View {
        VStack(spacing: 10) {
            ForEach(store.products, id: \.identifier) { package in
                GLPProPlanCard(
                    package: package,
                    isSelected: selectedPackage?.identifier == package.identifier,
                    showsTrialBadge: store.isEligibleForIntroOffer(package),
                    isBestValue: package.glpProPackageKind == .yearly
                ) {
                    selectedPackage = package
                }
            }
        }
    }

    private var purchaseSection: some View {
        VStack(spacing: 12) {
            Button(action: startPurchase) {
                ZStack {
                    Text(ctaTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .opacity(isPurchasing ? 0 : 1)
                    if isPurchasing {
                        ProgressView().tint(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(AppTheme.brand, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing || selectedPackage == nil)

            if let disclosure = disclosureText {
                Text(disclosure)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            if let restoreMessage {
                Text(restoreMessage)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
            }

            Button(action: startRestore) {
                Text(isRestoring ? "Restoring…" : "Restore Purchases")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
            }
            .buttonStyle(.plain)
            .disabled(isRestoring || isPurchasing)

            HStack(spacing: 4) {
                Link("Terms", destination: PaywallLinks.standardEULA)
                Text("·")
                Link("Privacy Policy", destination: PaywallLinks.privacyPolicy)
            }
            .font(.caption2)
            .foregroundStyle(AppTheme.muted)
        }
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.muted)
                        .padding(16)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var ctaTitle: String {
        guard let package = selectedPackage else { return "Continue" }
        if package.glpProPackageKind == .lifetime { return "Unlock Lifetime" }
        if store.isEligibleForIntroOffer(package) { return "Start Free Trial" }
        return "Subscribe"
    }

    private var disclosureText: String? {
        guard let package = selectedPackage else { return nil }
        let price = package.glpProPriceLabel
        if package.glpProPackageKind == .lifetime {
            return "\(price). One-time purchase. Lifetime access, no subscription."
        }
        let renew = "Auto-renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings."
        if store.isEligibleForIntroOffer(package), let trial = package.glpProIntroOfferLabel {
            return "\(trial.capitalized), then \(price). \(renew)"
        }
        return "\(price). \(renew)"
    }

    private func selectDefaultPackageIfNeeded() {
        guard selectedPackage == nil, !store.products.isEmpty else { return }
        selectedPackage = store.products.first { $0.glpProPackageKind == .yearly }
            ?? store.products.first
    }

    private func startPurchase() {
        guard let package = selectedPackage else { return }
        errorMessage = nil
        restoreMessage = nil
        isPurchasing = true
        Task { @MainActor in
            defer { isPurchasing = false }
            do {
                switch try await store.purchase(package) {
                case .purchased, .pending:
                    break
                case .cancelled:
                    errorMessage = "Purchase cancelled. Tap again to continue."
                }
            } catch {
                errorMessage = "Couldn't complete the purchase. Please try again."
            }
        }
    }

    private func startRestore() {
        errorMessage = nil
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
}

private struct GLPProPlanCard: View {
    let package: Package
    let isSelected: Bool
    let showsTrialBadge: Bool
    let isBestValue: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? AppTheme.brand : AppTheme.surfaceStroke, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(AppTheme.brand)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(package.glpProDisplayName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.text)
                        if isBestValue {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.brand, in: Capsule())
                        }
                    }
                    if showsTrialBadge, let trial = package.glpProIntroOfferLabel {
                        Text(trial.capitalized)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.calm)
                    }
                }

                Spacer(minLength: 8)

                Text(package.glpProPriceLabel)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppTheme.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? AppTheme.brand : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
