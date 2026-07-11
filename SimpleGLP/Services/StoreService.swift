import Foundation
import os
@preconcurrency import RevenueCat

enum GLPProProduct {
    static let lifetime = "com.jackwallner.glp.pro.lifetime"
    static let yearly = "com.jackwallner.glp.pro.yearly"
    static let monthly = "com.jackwallner.glp.pro.monthly"
    static let all: [String] = [lifetime, yearly, monthly]

    static func kind(for productID: String) -> GLPProPackageKind {
        switch productID {
        case lifetime: return .lifetime
        case yearly: return .yearly
        case monthly: return .monthly
        default:
            let id = productID.lowercased()
            if id.contains("lifetime") { return .lifetime }
            if id.contains("year") || id.contains("annual") { return .yearly }
            if id.contains("month") { return .monthly }
            return .other
        }
    }
}

enum RevenueCatConfig {
    static let apiKey = "appl_GIiheOxycuuhBLLflisHGrMcrHU"
    /// Entitlement identifier as configured on the RevenueCat dashboard ("GLP Pro").
    static let proEntitlement = "GLP Pro"
    /// Older/alternate identifiers kept so prior sandbox or pre-migration purchases still unlock.
    static let fallbackEntitlements = ["SimpleGLPPro", "pro"]
}

enum PurchaseState {
    case purchased
    case cancelled
    case pending
}

enum GLPProPackageKind: Int {
    case lifetime = 0
    case yearly = 1
    case monthly = 2
    case other = 3

    var packageType: PackageType {
        switch self {
        case .lifetime: return .lifetime
        case .yearly: return .annual
        case .monthly: return .monthly
        case .other: return .custom
        }
    }

    var fallbackPackageIdentifier: String {
        switch self {
        case .lifetime: return "$rc_lifetime"
        case .yearly: return "$rc_annual"
        case .monthly: return "$rc_monthly"
        case .other: return "$rc_custom"
        }
    }
}

extension GLPProPackageKind {
    init(package: Package) {
        switch package.packageType {
        case .lifetime:
            self = .lifetime
        case .annual:
            self = .yearly
        case .monthly:
            self = .monthly
        default:
            let identifiers = [package.identifier, package.storeProduct.productIdentifier].map { $0.lowercased() }
            if identifiers.contains(where: { $0.contains("lifetime") }) {
                self = .lifetime
            } else if identifiers.contains(where: { $0.contains("yearly") || $0.contains("annual") }) {
                self = .yearly
            } else if identifiers.contains(where: { $0.contains("monthly") }) {
                self = .monthly
            } else {
                self = .other
            }
        }
    }
}

extension Package {
    var glpProPackageKind: GLPProPackageKind {
        GLPProPackageKind(package: self)
    }

    var glpProDisplayName: String {
        switch glpProPackageKind {
        case .lifetime: "Lifetime"
        case .yearly: "Yearly"
        case .monthly: "Monthly"
        case .other: storeProduct.localizedTitle
        }
    }

    var glpProPriceLabel: String {
        guard let period = storeProduct.subscriptionPeriod else { return storeProduct.localizedPriceString }
        let unit: String
        switch period.unit {
        case .day: unit = period.value == 1 ? "day" : "days"
        case .week: unit = period.value == 1 ? "week" : "weeks"
        case .month: unit = period.value == 1 ? "month" : "months"
        case .year: unit = period.value == 1 ? "year" : "years"
        @unknown default: unit = ""
        }
        if period.value == 1 {
            return "\(storeProduct.localizedPriceString) / \(unit)"
        }
        return "\(storeProduct.localizedPriceString) / \(period.value) \(unit)"
    }

    var glpProIntroOfferLabel: String? {
        guard let intro = storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial else {
            return nil
        }
        let period = intro.subscriptionPeriod
        let unit: String
        switch period.unit {
        case .day: unit = period.value == 1 ? "day" : "days"
        case .week: unit = period.value == 1 ? "week" : "weeks"
        case .month: unit = period.value == 1 ? "month" : "months"
        case .year: unit = period.value == 1 ? "year" : "years"
        @unknown default: unit = ""
        }
        if period.unit == .week {
            return "\(period.value * 7)-day free trial"
        }
        return "\(period.value)-\(unit.dropLast(period.value == 1 ? 0 : 1)) free trial"
    }
}

extension CustomerInfo {
    var hasGLPProEntitlement: Bool {
        if entitlements.active[RevenueCatConfig.proEntitlement] != nil { return true }
        if RevenueCatConfig.fallbackEntitlements.contains(where: { entitlements.active[$0] != nil }) {
            return true
        }
        // Resilience: if the RevenueCat dashboard entitlement isn't attached to our products
        // (or is named differently), a real purchase still "goes through" but `entitlements.active`
        // stays empty. Fall back to verified product ownership — an active subscription or the
        // lifetime non-consumable — so Pro unlocks regardless of dashboard entitlement mapping.
        let proIDs = Set(GLPProProduct.all)
        if !activeSubscriptions.isDisjoint(with: proIDs) { return true }
        return nonSubscriptions.contains { proIDs.contains($0.productIdentifier) }
    }
}

extension Offering {
    var glpProSortedPackages: [Package] {
        availablePackages.sorted {
            let lhsKind = $0.glpProPackageKind
            let rhsKind = $1.glpProPackageKind
            if lhsKind.rawValue != rhsKind.rawValue {
                return lhsKind.rawValue < rhsKind.rawValue
            }
            return $0.storeProduct.productIdentifier < $1.storeProduct.productIdentifier
        }
    }
}

extension Offerings {
    /// Try `default` (our RC-dashboard key), then `current`, then any offering that actually
    /// has packages attached. This rescues installs from a mis-configured offering identifier.
    var glpProPaywallOffering: Offering? {
        if let named = offering(identifier: "default"), !named.availablePackages.isEmpty {
            return named
        }
        if let current, !current.availablePackages.isEmpty {
            return current
        }
        return all.values.first { !$0.availablePackages.isEmpty }
    }
}

@MainActor
final class StoreService: NSObject, ObservableObject {
    static let shared = StoreService()

    @Published private(set) var products: [Package] = []
    @Published private(set) var currentOffering: Offering?
    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var isProUnlocked: Bool = false
    @Published private(set) var purchaseInFlight: Bool = false
    @Published private(set) var isLoadingProducts: Bool = false
    /// True when `products` were loaded directly by ID instead of from a RevenueCat offering
    /// (offering missing/empty on the dashboard). Purchases must then go through the product, not the package.
    @Published private(set) var usingFallbackProducts: Bool = false
    @Published var lastError: String?
    @Published private(set) var introEligibility: [String: Bool] = [:]
    /// Flips true only after an explicit `customerInfo` fetch resolves. The delegate's
    /// initial push can carry stale/cached non-Pro info; promo surfaces that present on
    /// it get yanked when the authoritative result lands — a blank sheet flash on cold
    /// launch for returning Pro users. Promo gating waits on this instead.
    @Published private(set) var hasResolvedEntitlements: Bool = false

    var monthlyPackage: Package? { products.first { $0.glpProPackageKind == .monthly } }
    var yearlyPackage: Package? { products.first { $0.glpProPackageKind == .yearly } }
    var lifetimePackage: Package? { products.first { $0.glpProPackageKind == .lifetime } }

    /// True when this account shows any Pro signal — active entitlement, a lifetime
    /// purchase, or a subscription that expired within the last 48h. An expired-but-renewing
    /// subscription can flip `isProUnlocked` a beat after launch; presenting a promo inside
    /// that window gets the sheet yanked before layout. Promo surfaces stay quiet for these.
    var hasRecentOrActiveProSignal: Bool {
        guard let info = customerInfo else { return false }
        if info.hasGLPProEntitlement { return true }
        if !info.nonSubscriptions.isEmpty { return true }
        let cutoff = Date(timeIntervalSinceNow: -48 * 3600)
        return info.entitlements.all.values.contains { entitlement in
            entitlement.isActive || (entitlement.expirationDate.map { $0 > cutoff } ?? false)
        }
    }

    private let logger = Logger(subsystem: "com.jackwallner.glp", category: "Store")
    private var isConfigured = false
    private var paywallImpressionsThisSession: Set<String> = []

    private override init() {}

    func start() {
        configureIfNeeded()
        Task { await updateCustomerProductStatus(fetchPolicy: .fetchCurrent) }
        Task { await fetchProducts() }
    }

    func fetchProducts() async {
        configureIfNeeded()
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            let offering = offerings.glpProPaywallOffering
            let packages = offering?.glpProSortedPackages ?? []
            if !packages.isEmpty {
                currentOffering = offering
                usingFallbackProducts = false
                products = packages
                lastError = nil
                await refreshIntroEligibility()
                return
            }
            // Offering missing or empty on the RevenueCat dashboard. Rather than show
            // "no purchase options", load the products straight from the store by ID so the
            // paywall works regardless of how the dashboard offering is configured.
            logger.error("Offerings returned no packages (all=\(offerings.all.count, privacy: .public), current=\(offerings.current?.identifier ?? "nil", privacy: .public)). Falling back to direct product fetch.")
            await loadFallbackProducts()
        } catch {
            logger.error("Offerings fetch failed: \(String(describing: error), privacy: .public). Falling back to direct product fetch.")
            await loadFallbackProducts()
        }
    }

    /// Loads the Pro products by identifier and wraps them in synthesized packages so the
    /// existing paywall UI keeps working even when no RevenueCat offering is attached.
    private func loadFallbackProducts() async {
        let storeProducts = await Purchases.shared.products(GLPProProduct.all)
        guard !storeProducts.isEmpty else {
            currentOffering = nil
            usingFallbackProducts = false
            products = []
            #if DEBUG
            lastError = "No products returned for \(GLPProProduct.all.joined(separator: ", ")). Check App Store Connect / StoreKit config."
            #else
            lastError = "Purchase options aren't available right now. Please try again shortly."
            #endif
            return
        }
        let synthesized = storeProducts.map { product -> Package in
            let kind = GLPProProduct.kind(for: product.productIdentifier)
            return Package(
                identifier: kind.fallbackPackageIdentifier,
                packageType: kind.packageType,
                storeProduct: product,
                offeringIdentifier: "fallback",
                webCheckoutUrl: nil
            )
        }
        currentOffering = nil
        usingFallbackProducts = true
        products = synthesized.sorted { $0.glpProPackageKind.rawValue < $1.glpProPackageKind.rawValue }
        lastError = nil
        await refreshIntroEligibility()
    }

    private func refreshIntroEligibility() async {
        let identifiers = products
            .filter { $0.storeProduct.introductoryDiscount != nil }
            .map(\.storeProduct.productIdentifier)
        guard !identifiers.isEmpty else {
            introEligibility = [:]
            return
        }
        let result = await Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: identifiers)
        introEligibility = result.mapValues { $0.status == .eligible }
    }

    func isEligibleForIntroOffer(_ package: Package) -> Bool {
        guard package.glpProIntroOfferLabel != nil else { return false }
        return introEligibility[package.storeProduct.productIdentifier] ?? true
    }

    // MARK: - Onboarding trial CTA (StatScout / Headaches pattern)

    /// One-tap conversion target for the onboarding trial step: the eligible yearly
    /// trial package, falling back to any eligible trial-bearing package, then the
    /// plain yearly package. Bought directly (Apple confirm); the full paywall is only
    /// the fallback when this is nil (products not loaded). Mirrors the package
    /// selection RootTabView uses for its post-onboarding trial sheet so the label,
    /// disclosure, and purchase all reference the same product.
    var directTrialPackage: Package? {
        let eligible = products.filter { isEligibleForIntroOffer($0) }
        return eligible.first { $0.glpProPackageKind == .yearly }
            ?? eligible.first
            ?? yearlyPackage
    }

    /// CTA label for the one-tap yearly conversion. Leads with the free-trial offer
    /// when eligible, price-forward otherwise so the price is never hidden
    /// (Apple 3.1.2 — nothing implies Pro is free forever).
    var onboardingTrialCTALabel: String {
        guard let pkg = directTrialPackage else { return "Unlock Simple GLP Pro" }
        if isEligibleForIntroOffer(pkg), let trial = pkg.glpProIntroOfferLabel {
            return "Start \(trial)"
        }
        return "Unlock Simple GLP Pro for \(pkg.glpProPriceLabel)"
    }

    /// Full Apple-3.1.2 auto-renew disclosure for the onboarding trial CTA. States
    /// trial length (when eligible), then the real price from the loaded package, then
    /// auto-renew and how to cancel. Returns nil until a package loads so no
    /// placeholder price is ever rendered.
    var onboardingTrialDisclosureText: String? {
        guard let pkg = directTrialPackage else { return nil }
        let renew = "Auto-renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings › Apple ID › Subscriptions."
        if isEligibleForIntroOffer(pkg), let trial = pkg.glpProIntroOfferLabel {
            return "\(trial.capitalized), then \(pkg.glpProPriceLabel). \(renew)"
        }
        return "\(pkg.glpProPriceLabel). \(renew)"
    }

    func trackPaywallImpression(id: String, oncePerSession: Bool = false) {
        configureIfNeeded()
        if AppEnvironment.isUITesting { return }
        if oncePerSession {
            guard !paywallImpressionsThisSession.contains(id) else { return }
            paywallImpressionsThisSession.insert(id)
        }
        Purchases.shared.trackCustomPaywallImpression(
            CustomPaywallImpressionParams(paywallId: id)
        )
    }

    @discardableResult
    func purchase(_ package: Package) async throws -> PurchaseState {
        configureIfNeeded()
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        // Synthesized fallback packages point at an offering that doesn't exist on the
        // dashboard, so purchase the underlying product directly in that case.
        let result = usingFallbackProducts
            ? try await Purchases.shared.purchase(product: package.storeProduct)
            : try await Purchases.shared.purchase(package: package)
        apply(customerInfo: result.customerInfo)
        if result.userCancelled {
            return .cancelled
        } else if result.customerInfo.hasGLPProEntitlement {
            return .purchased
        }
        return .pending
    }

    func updateCustomerProductStatus(fetchPolicy: CacheFetchPolicy = .default) async {
        configureIfNeeded()
        do {
            let info = try await Purchases.shared.customerInfo(fetchPolicy: fetchPolicy)
            apply(customerInfo: info)
            // Explicit fetch — Pro status is now authoritative, so promo sheets may unblock.
            hasResolvedEntitlements = true
            lastError = nil
        } catch {
            logger.error("Customer info refresh failed: \(String(describing: error), privacy: .public)")
            lastError = "Couldn't refresh your subscription status. Check your connection and try again."
        }
    }

    func restorePurchases() async {
        configureIfNeeded()
        lastError = nil
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(customerInfo: info)
            lastError = isProUnlocked ? nil : "No previous Simple GLP Pro purchase was found on this Apple ID."
        } catch {
            logger.error("Restore failed: \(String(describing: error), privacy: .public)")
            lastError = "Couldn't restore purchases. Try again."
        }
    }

    func apply(customerInfo: CustomerInfo) {
        self.customerInfo = customerInfo
        let hasPro = customerInfo.hasGLPProEntitlement
        if isProUnlocked != hasPro {
            isProUnlocked = hasPro
            logger.info("isProUnlocked updated to \(hasPro, privacy: .public)")
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
        Purchases.shared.delegate = self
        isConfigured = true
    }
}

extension StoreService: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            StoreService.shared.apply(customerInfo: customerInfo)
        }
    }
}
