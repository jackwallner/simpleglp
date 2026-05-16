import Foundation
import os
@preconcurrency import RevenueCat

enum GLPProProduct {
    static let lifetime = "com.jackwallner.glp.pro.lifetime"
    static let yearly = "com.jackwallner.glp.pro.yearly"
    static let monthly = "com.jackwallner.glp.pro.monthly"
    static let all: [String] = [lifetime, yearly, monthly]
}

enum RevenueCatConfig {
    static let apiKey = "appl_GIiheOxycuuhBLLflisHGrMcrHU"
    static let proEntitlement = "SimpleGLPPro"
    static let fallbackEntitlement = "pro"
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
}

extension CustomerInfo {
    var hasGLPProEntitlement: Bool {
        entitlements.active[RevenueCatConfig.proEntitlement] != nil
        || entitlements.active[RevenueCatConfig.fallbackEntitlement] != nil
        || !entitlements.active.isEmpty
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
    var glpProPaywallOffering: Offering? {
        offering(identifier: "default") ?? current
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
    @Published var lastError: String?

    var monthlyPackage: Package? { products.first { $0.glpProPackageKind == .monthly } }
    var yearlyPackage: Package? { products.first { $0.glpProPackageKind == .yearly } }
    var lifetimePackage: Package? { products.first { $0.glpProPackageKind == .lifetime } }

    private let logger = Logger(subsystem: "com.jackwallner.glp", category: "Store")
    private var isConfigured = false

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
            currentOffering = offering
            products = offering?.glpProSortedPackages ?? []
            lastError = nil
        } catch {
            logger.error("Product fetch failed: \(String(describing: error), privacy: .public)")
            lastError = "Couldn't load purchase options. Check your connection and try again."
        }
    }

    @discardableResult
    func purchase(_ package: Package) async throws -> PurchaseState {
        configureIfNeeded()
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        let result = try await Purchases.shared.purchase(package: package)
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
