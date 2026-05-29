import SwiftUI
@preconcurrency import RevenueCat

enum PaywallLinks {
    static let privacyPolicy = URL(string: "https://jackwallner.github.io/simpleglp/privacy-policy.html")!
    static let termsOfUse = URL(string: "https://jackwallner.github.io/simpleglp/terms.html")!
    static let standardEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let support = URL(string: "https://jackwallner.github.io/simpleglp/support.html")!
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

    private let benefits: [(icon: String, title: String, detail: String)] = [
        ("bell.badge.fill",
         "Never miss a dose",
         "Pro watches your timing and nudges you before a dose slips — so one busy week doesn't undo your progress."),
        ("waveform.path.ecg",
         "Catch drift early",
         "Spot when your shots creep later week over week, and pull your rhythm back in line."),
        ("lock.shield.fill",
         "Private by design",
         "Everything stays on your device. No accounts, no ads, no data sold — ever.")
    ]

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            content

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

    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: displayCloseButton ? 44 : 16)

            header
                .padding(.horizontal, 22)

            Spacer(minLength: 12)

            benefitList
                .padding(.horizontal, 22)

            Spacer(minLength: 12)

            if store.products.isEmpty {
                planPlaceholder
                    .padding(.horizontal, 22)
            } else {
                planCards
                    .padding(.horizontal, 22)
            }

            Spacer(minLength: 12)

            purchaseSection
                .padding(.horizontal, 22)

            Spacer(minLength: 8)

            footerLinks
                .padding(.horizontal, 22)
                .padding(.bottom, 16)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(AppTheme.brand)
                    .frame(width: 56, height: 56)
                    .shadow(color: AppTheme.brand.opacity(0.35), radius: 12, x: 0, y: 5)
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text("Simple GLP Pro")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.text)
            Text("Get the most out of every dose.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
            Label("Private · On-device · No accounts, ever.", systemImage: "lock.fill")
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppTheme.muted)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }

    private var benefitList: some View {
        VStack(spacing: 12) {
            ForEach(benefits, id: \.title) { benefit in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.brandSoft)
                            .frame(width: 30, height: 30)
                        Image(systemName: benefit.icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.brand)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(benefit.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                        Text(benefit.detail)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var planPlaceholder: some View {
        VStack(spacing: 10) {
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.surface)
                    .frame(height: 64)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(AppTheme.surfaceStroke.opacity(0.4), lineWidth: 1)
                    }
                    .overlay {
                        if store.isLoadingProducts {
                            ProgressView()
                                .tint(AppTheme.muted)
                        }
                    }
            }
            if !store.isLoadingProducts {
                Text(store.lastError ?? "Hang tight, plans are loading.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
        }
    }

    private var planCards: some View {
        VStack(spacing: 10) {
            let monthlyPrice = monthlyReferencePrice
            ForEach(orderedPackages, id: \.identifier) { package in
                GLPProPlanCard(
                    package: package,
                    isSelected: selectedPackage?.identifier == package.identifier,
                    showsTrialBadge: store.isEligibleForIntroOffer(package),
                    isBestValue: package.glpProPackageKind == .yearly,
                    perMonthLabel: perMonthLabel(for: package),
                    savingsLabel: savingsLabel(for: package, monthlyReference: monthlyPrice)
                ) {
                    selectedPackage = package
                }
            }
        }
    }

    private var orderedPackages: [Package] {
        // Yearly first (highest conversion default), then monthly, then lifetime, then anything else.
        store.products.sorted { lhs, rhs in
            rank(for: lhs) < rank(for: rhs)
        }
    }

    private func rank(for package: Package) -> Int {
        switch package.glpProPackageKind {
        case .yearly: return 0
        case .monthly: return 1
        case .lifetime: return 2
        case .other: return 3
        }
    }

    private var purchaseSection: some View {
        VStack(spacing: 8) {
            Button(action: primaryButtonAction) {
                ZStack {
                    Text(primaryButtonTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .opacity(isPurchasing ? 0 : 1)
                    if isPurchasing {
                        ProgressView().tint(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(AppTheme.brand, in: Capsule())
                .shadow(color: AppTheme.brand.opacity(0.35), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing || (store.products.isEmpty == false && selectedPackage == nil))

            if let assurance = assuranceText {
                Text(assurance)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.brand)
                    .multilineTextAlignment(.center)
            }

            if let disclosure = disclosureText {
                Text(disclosure)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            if let restoreMessage {
                Text(restoreMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var footerLinks: some View {
        VStack(spacing: 6) {
            Button(action: startRestore) {
                Text(isRestoring ? "Restoring…" : "Restore Purchases")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
            }
            .buttonStyle(.plain)
            .disabled(isRestoring || isPurchasing)

            HStack(spacing: 6) {
                Link("Terms", destination: PaywallLinks.standardEULA)
                Text("·").foregroundStyle(AppTheme.muted)
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
                .accessibilityLabel("Close")
            }
            Spacer()
        }
    }

    private var primaryButtonTitle: String {
        if store.products.isEmpty {
            return store.isLoadingProducts ? "Loading…" : "Try Again"
        }
        guard let package = selectedPackage else { return "Continue" }
        if package.glpProPackageKind == .lifetime { return "Unlock Lifetime Access" }
        if store.isEligibleForIntroOffer(package) { return "Start My Free Trial" }
        return "Subscribe & Continue"
    }

    private func primaryButtonAction() {
        if store.products.isEmpty {
            Task {
                await store.fetchProducts()
                selectDefaultPackageIfNeeded()
            }
        } else {
            startPurchase()
        }
    }

    private var assuranceText: String? {
        guard let package = selectedPackage else { return nil }
        if package.glpProPackageKind == .lifetime { return nil }
        if store.isEligibleForIntroOffer(package) {
            return "No payment today."
        }
        return nil
    }

    /// Apple 3.1.2: full price, renewal, and cancellation — one caption under the CTA (not a separate cancel section).
    private var disclosureText: String? {
        guard let package = selectedPackage else { return nil }
        let price = package.glpProPriceLabel
        if package.glpProPackageKind == .lifetime {
            return "\(price). One-time purchase. Lifetime access."
        }
        let renew = "Auto-renews. Cancel anytime."
        if store.isEligibleForIntroOffer(package), let trial = package.glpProIntroOfferLabel {
            return "\(trial.capitalized), then \(price). \(renew)"
        }
        return "\(price). \(renew)"
    }

    private var monthlyReferencePrice: Decimal? {
        store.products
            .first { $0.glpProPackageKind == .monthly }?
            .storeProduct.price
    }

    private func perMonthLabel(for package: Package) -> String? {
        guard package.glpProPackageKind == .yearly,
              let period = package.storeProduct.subscriptionPeriod,
              period.unit == .year else { return nil }
        let months = Decimal(period.value * 12)
        let perMonth = NSDecimalNumber(decimal: package.storeProduct.price / months)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = package.storeProduct.priceFormatter?.locale ?? .current
        formatter.currencyCode = package.storeProduct.currencyCode
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        guard let formatted = formatter.string(from: perMonth) else { return nil }
        return "\(formatted) / month"
    }

    private func savingsLabel(for package: Package, monthlyReference: Decimal?) -> String? {
        guard package.glpProPackageKind == .yearly,
              let monthlyReference,
              monthlyReference > 0,
              let period = package.storeProduct.subscriptionPeriod,
              period.unit == .year else { return nil }
        let months = Decimal(period.value * 12)
        let yearlyEquivalent = monthlyReference * months
        guard yearlyEquivalent > package.storeProduct.price else { return nil }
        let saved = (yearlyEquivalent - package.storeProduct.price) / yearlyEquivalent
        let percent = NSDecimalNumber(decimal: saved * 100).intValue
        guard percent > 0 else { return nil }
        return "SAVE \(percent)%"
    }

    private func selectDefaultPackageIfNeeded() {
        guard selectedPackage == nil, !store.products.isEmpty else { return }
        selectedPackage = store.products.first { $0.glpProPackageKind == .yearly }
            ?? store.products.first { $0.glpProPackageKind == .monthly }
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
    let perMonthLabel: String?
    let savingsLabel: String?
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

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(package.glpProDisplayName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.text)
                        if let savingsLabel {
                            Text(savingsLabel)
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.brand, in: Capsule())
                        } else if isBestValue {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .heavy))
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
                    } else if let perMonthLabel {
                        Text(perMonthLabel)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(package.glpProPriceLabel)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(AppTheme.text)
                    if showsTrialBadge, let perMonthLabel {
                        Text(perMonthLabel)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.muted)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? AppTheme.brand : AppTheme.surfaceStroke.opacity(0.5),
                            lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
