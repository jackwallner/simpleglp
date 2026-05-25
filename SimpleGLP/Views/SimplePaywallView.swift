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

    private let benefits: [(icon: String, title: String, detail: String)] = [
        ("bell.badge.fill",
         "Never miss a dose",
         "Proactive alerts catch schedule drift before it costs you a week of progress."),
        ("waveform.path.ecg",
         "See what's working",
         "Personalized pattern insights surface trends across timing, adherence, and consistency."),
        ("calendar.badge.clock",
         "Stay on track on autopilot",
         "Smart timing nudges adapt to your real life — not a rigid weekly calendar.")
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
            VStack(spacing: 24) {
                header
                benefitList
                if showTrialTimeline {
                    trialTimeline
                }
                planCards
                purchaseSection
                trustRow
                footerLinks
            }
            .padding(.horizontal, 22)
            .padding(.top, displayCloseButton ? 52 : 28)
            .padding(.bottom, 32)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.brand)
                    .frame(width: 68, height: 68)
                    .shadow(color: AppTheme.brand.opacity(0.35), radius: 14, x: 0, y: 6)
                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text("Simple GLP Pro")
                .font(.title.weight(.bold))
                .foregroundStyle(AppTheme.text)
            Text("Get the most out of every dose.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
        }
    }

    private var benefitList: some View {
        VStack(spacing: 14) {
            ForEach(benefits, id: \.title) { benefit in
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.brandSoft)
                            .frame(width: 32, height: 32)
                        Image(systemName: benefit.icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.brand)
                    }
                    VStack(alignment: .leading, spacing: 2) {
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

    private var showTrialTimeline: Bool {
        guard let package = selectedPackage else { return false }
        return store.isEligibleForIntroOffer(package) && package.glpProIntroOfferLabel != nil
    }

    private var trialTimeline: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How your free trial works")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                TrialTimelineRow(
                    icon: "lock.open.fill",
                    title: "Today",
                    detail: "Full access to alerts and insights. No charge.",
                    showsConnector: true
                )
                TrialTimelineRow(
                    icon: "bell.fill",
                    title: trialReminderTitle,
                    detail: "We'll remind you before your trial ends.",
                    showsConnector: true
                )
                TrialTimelineRow(
                    icon: "checkmark.seal.fill",
                    title: trialBillingTitle,
                    detail: "You're billed only if you stay. Cancel anytime in Settings.",
                    showsConnector: false
                )
            }
        }
        .padding(16)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.surfaceStroke.opacity(0.6), lineWidth: 1)
        }
    }

    private var trialDays: Int {
        guard let package = selectedPackage,
              let intro = package.storeProduct.introductoryDiscount,
              intro.paymentMode == .freeTrial else { return 7 }
        let period = intro.subscriptionPeriod
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        case .month: return period.value * 30
        case .year: return period.value * 365
        @unknown default: return 7
        }
    }

    private var trialReminderTitle: String {
        let reminder = max(trialDays - 2, 1)
        return "Day \(reminder) · Reminder"
    }

    private var trialBillingTitle: String {
        "Day \(trialDays) · Subscription begins"
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
        VStack(spacing: 10) {
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
                .padding(.vertical, 17)
                .background(AppTheme.brand, in: Capsule())
                .shadow(color: AppTheme.brand.opacity(0.35), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing || selectedPackage == nil)

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
                    .padding(.top, 2)
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
        }
    }

    private var trustRow: some View {
        HStack(spacing: 18) {
            TrustChip(icon: "xmark.circle", text: "Cancel\nanytime")
            TrustChip(icon: "lock.shield", text: "Private &\nencrypted")
            TrustChip(icon: "applelogo", text: "Billed via\nApple ID")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var footerLinks: some View {
        VStack(spacing: 10) {
            Button(action: startRestore) {
                Text(isRestoring ? "Restoring…" : "Restore Purchases")
                    .font(.footnote.weight(.semibold))
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

    private var ctaTitle: String {
        guard let package = selectedPackage else { return "Continue" }
        if package.glpProPackageKind == .lifetime { return "Unlock Lifetime Access" }
        if store.isEligibleForIntroOffer(package) { return "Start My Free Trial" }
        return "Subscribe & Continue"
    }

    private var assuranceText: String? {
        guard let package = selectedPackage else { return nil }
        if package.glpProPackageKind == .lifetime { return nil }
        if store.isEligibleForIntroOffer(package) {
            return "No payment today — cancel anytime."
        }
        return nil
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

private struct TrialTimelineRow: View {
    let icon: String
    let title: String
    let detail: String
    let showsConnector: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(AppTheme.brand)
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                if showsConnector {
                    Rectangle()
                        .fill(AppTheme.brand.opacity(0.35))
                        .frame(width: 2, height: 22)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, showsConnector ? 8 : 0)
            Spacer(minLength: 0)
        }
    }
}

private struct TrustChip: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.muted)
            Text(text)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
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
