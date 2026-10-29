import Foundation
import XCTest
@preconcurrency import RevenueCat
@testable import SimpleGLP
/// The fleet paywall record, checked in this app's own build.
///
/// The `rc-funnel-probe` run proves an impression reaches RevenueCat. These
/// prove what is underneath it: the counts, the conversion freeze, RevenueCat's
/// silent 40-character key limit, and the rule that nothing here may carry free
/// text or health data. Every assertion is a claim that will be read off a
/// customer record later, so a wrong value is worse than no value.

final class PaywallFunnelTests: XCTestCase {

    private var suite: UserDefaults!

    override func setUp() {
        super.setUp()
        // A throwaway suite per test. These counters outlive a launch and would
        // otherwise carry between tests and into the real container.
        let name = "conv.tests.\(UUID().uuidString)"
        suite = UserDefaults(suiteName: name)!
        ConversionDiagnostics.defaultsOverride = suite
    }

    override func tearDown() {
        ConversionDiagnostics.defaultsOverride = nil
        suite = nil
        super.tearDown()
    }

    func testCountsPitchesPerSurfaceAndInTotal() {
        ConversionDiagnostics.recordPitchView(impressionID: "simpleglp_onboarding_trial")
        ConversionDiagnostics.recordPitchView(impressionID: "simpleglp_onboarding_trial")
        ConversionDiagnostics.recordPitchView(impressionID: "simpleglp_insights_sheet")

        let attributes = ConversionDiagnostics.subscriberAttributes
        XCTAssertEqual(attributes["pitch_views_total"], "3")
        XCTAssertEqual(attributes["pitch_views_onboarding_trial"], "2")
        XCTAssertEqual(attributes["pitch_last"], "insights_sheet")
    }

    func testFunnelStepsAreSentAsFleetKeys() {
        ConversionDiagnostics.recordPitchView(impressionID: "simpleglp_onboarding_trial")
        ConversionDiagnostics.record(.trialOfferReached)
        ConversionDiagnostics.record(.trialCTATapped)
        ConversionDiagnostics.record(.purchaseCancelled)
        ConversionDiagnostics.record(.trialCTATapped)

        let attributes = ConversionDiagnostics.subscriberAttributes
        XCTAssertEqual(attributes["funnel_trialOfferReached"], "1")
        XCTAssertEqual(attributes["funnel_trialCTATapped"], "2")
        XCTAssertEqual(attributes["funnel_purchaseCancelled"], "1")
        XCTAssertNil(attributes["funnel_freeVersionChosen"])
    }

    func testNoAttributesBeforeAnyPitchIsSeen() {
        // Someone never shown a paywall has nothing to say about paywalls.
        // Zeros would make them look like a funnel failure.
        ConversionDiagnostics.recordAppOpen()
        XCTAssertTrue(ConversionDiagnostics.subscriberAttributes.isEmpty)
    }

    func testRecordsHowEarlyTheFirstPitchArrived() {
        ConversionDiagnostics.recordAppOpen()
        ConversionDiagnostics.recordAppOpen()
        ConversionDiagnostics.recordPitchView(impressionID: "simpleglp_onboarding_trial")

        let attributes = ConversionDiagnostics.subscriberAttributes
        XCTAssertEqual(attributes["opens_before_first_pitch"], "2")
        XCTAssertEqual(attributes["days_since_install"], "0")
    }

    func testTheEarlinessPairIsFrozenOnTheFirstPitchOnly() {
        ConversionDiagnostics.recordAppOpen()
        ConversionDiagnostics.recordPitchView(impressionID: "simpleglp_onboarding_trial")
        ConversionDiagnostics.recordAppOpen()
        ConversionDiagnostics.recordPitchView(impressionID: "simpleglp_insights_sheet")

        XCTAssertEqual(
            ConversionDiagnostics.subscriberAttributes["opens_before_first_pitch"],
            "1"
        )
    }

    func testAnInstallThatPredatesThisCodeReportsNoAge() {
        // No recorded app open, so no install stamp. Absent is the honest
        // answer; zero would claim they were asked on their first day.
        ConversionDiagnostics.recordPitchView(impressionID: "simpleglp_onboarding_trial")
        XCTAssertNil(ConversionDiagnostics.subscriberAttributes["days_since_install"])
        XCTAssertNotNil(ConversionDiagnostics.subscriberAttributes["pitch_views_total"])
    }

    func testConversionFreezesTheSurfaceAndCountAtTheMomentOfSale() {
        ConversionDiagnostics.recordPitchView(impressionID: "simpleglp_onboarding_trial")
        ConversionDiagnostics.recordPitchView(impressionID: "simpleglp_insights_sheet")
        ConversionDiagnostics.recordConversion(plan: "yearly", startedTrial: true, offeringID: "default")
        // A pitch after the sale must not rewrite how they converted.
        ConversionDiagnostics.recordPitchView(impressionID: "simpleglp_onboarding_trial")

        let attributes = ConversionDiagnostics.subscriberAttributes
        XCTAssertEqual(attributes["converted_surface"], "insights_sheet")
        XCTAssertEqual(attributes["pitch_views_at_convert"], "2")
        XCTAssertEqual(attributes["converted_plan"], "yearly")
        XCTAssertEqual(attributes["converted_with_trial"], "true")
        XCTAssertEqual(attributes["converted_offering"], "default")
    }

    func testOnlyTheFirstConversionIsRecorded() {
        ConversionDiagnostics.recordPitchView(impressionID: "simpleglp_onboarding_trial")
        ConversionDiagnostics.recordConversion(plan: "monthly", startedTrial: true)
        // A renewal or plan change is not a new answer to what sold them.
        ConversionDiagnostics.recordConversion(plan: "yearly", startedTrial: false)

        let attributes = ConversionDiagnostics.subscriberAttributes
        XCTAssertEqual(attributes["converted_plan"], "monthly")
        XCTAssertEqual(attributes["converted_with_trial"], "true")
    }

    func testAttributeKeysStayInsideRevenueCatsLimit() {
        // RevenueCat drops a key over 40 characters, silently.
        let long = String(repeating: "a", count: 80)
        ConversionDiagnostics.recordPitchView(impressionID: "simpleglp_\(long)")
        for key in ConversionDiagnostics.subscriberAttributes.keys {
            XCTAssertLessThanOrEqual(key.count, 40, "attribute key too long: \(key)")
        }
    }

    func testNoAttributeCarriesFreeTextOrHealthData() {
        ConversionDiagnostics.recordAppOpen()
        ConversionDiagnostics.recordPitchView(impressionID: "simpleglp_onboarding_trial")
        ConversionDiagnostics.recordConversion(plan: "monthly", startedTrial: false)

        for (key, value) in ConversionDiagnostics.subscriberAttributes {
            XCTAssertFalse(value.contains(" "), "\(key) looks like free text: \(value)")
            XCTAssertLessThanOrEqual(value.count, 64, "\(key) is too long to be a label")
        }
    }
}

@MainActor
final class TrialEligibilityTests: XCTestCase {
    private func testDefaults() -> UserDefaults {
        UserDefaults(suiteName: "purchase.tests.\(UUID().uuidString)")!
    }

    private func package(hasTrial: Bool = true) -> Package {
        let discount = TestStoreProductDiscount(
            identifier: "trial", price: 0, localizedPriceString: "$0", paymentMode: .freeTrial,
            subscriptionPeriod: .init(value: 1, unit: .week), numberOfPeriods: 1, type: .introductory
        )
        let product = TestStoreProduct(
            localizedTitle: "Yearly", price: 29.99, currencyCode: "USD", localizedPriceString: "$29.99",
            productIdentifier: GLPProProduct.yearly, productType: .autoRenewableSubscription,
            localizedDescription: "Yearly Pro", subscriptionPeriod: .init(value: 1, unit: .year),
            introductoryDiscount: hasTrial ? discount : nil, locale: Locale(identifier: "en_US")
        ).toStoreProduct()
        return Package(identifier: "$rc_annual", packageType: .annual, storeProduct: product,
                       offeringIdentifier: "test", webCheckoutUrl: nil)
    }

    func testMissingAndUnknownEligibilityNeverPromiseATrial() {
        let package = package()
        for eligibility: [String: IntroEligibilityStatus] in [[:], [GLPProProduct.yearly: .unknown]] {
            let store = StoreService(products: [package], introEligibility: eligibility, defaults: testDefaults())
            XCTAssertFalse(store.isEligibleForIntroOffer(package))
            XCTAssertTrue(store.isIntroEligibilityUnknown(package))
            XCTAssertEqual(store.onboardingTrialCTALabel, "Try Again")
            XCTAssertNil(store.onboardingTrialDisclosureText)
        }
    }

    func testOnlyConfirmedEligibilityShowsTrialCopy() {
        let package = package()
        for status in [IntroEligibilityStatus.eligible, .ineligible, .noIntroOfferExists] {
            let store = StoreService(products: [package], introEligibility: [GLPProProduct.yearly: status], defaults: testDefaults())
            XCTAssertEqual(store.isEligibleForIntroOffer(package), status == .eligible)
            XCTAssertEqual(store.onboardingTrialCTALabel.contains("free trial"), status == .eligible)
            XCTAssertEqual(store.onboardingTrialDisclosureText?.localizedCaseInsensitiveContains("free trial"), status == .eligible)
            XCTAssertFalse(store.isIntroEligibilityUnknown(package))
        }
    }

    func testProductWithoutTrialDoesNotWaitForEligibility() {
        let package = package(hasTrial: false)
        let store = StoreService(products: [package], defaults: testDefaults())
        XCTAssertFalse(store.isIntroEligibilityUnknown(package))
        XCTAssertFalse(store.isEligibleForIntroOffer(package))
        XCTAssertTrue(store.onboardingTrialCTALabel.contains("$29.99"))
    }

    func testUnknownEligibilityBlocksPurchaseAtTheService() async {
        let package = package()
        let store = StoreService(products: [package], defaults: testDefaults())
        do {
            _ = try await store.purchase(package)
            XCTFail("An unconfirmed trial must not reach the purchase SDK")
        } catch StoreServiceError.unresolvedIntroEligibility {
            XCTAssertFalse(store.purchaseInFlight)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

extension TrialEligibilityTests {
    func testCompletedTransactionWithoutProStaysPendingAcrossRestarts() {
        let defaults = testDefaults()
        let store = StoreService(defaults: defaults)
        let diagnostics = testDefaults()
        ConversionDiagnostics.defaultsOverride = diagnostics
        defer { ConversionDiagnostics.defaultsOverride = nil }
        ConversionDiagnostics.recordPitchView(impressionID: "simpleglp_onboarding_trial")

        XCTAssertEqual(store.completePurchase(package(), userCancelled: false), .pending)
        XCTAssertTrue(store.isPurchasePending)
        XCTAssertTrue(StoreService(defaults: defaults).isPurchasePending)
        XCTAssertNil(ConversionDiagnostics.subscriberAttributes["funnel_purchaseSucceeded"])
        XCTAssertNil(ConversionDiagnostics.subscriberAttributes["converted_plan"])

        store.setLocalOverride(isPro: false)
        XCTAssertTrue(store.isPurchasePending)
        store.setLocalOverride(isPro: true)
        XCTAssertFalse(store.isPurchasePending)
        XCTAssertFalse(StoreService(defaults: defaults).isPurchasePending)
        XCTAssertEqual(ConversionDiagnostics.subscriberAttributes["funnel_purchaseSucceeded"], "1")
        XCTAssertEqual(ConversionDiagnostics.subscriberAttributes["converted_plan"], GLPProProduct.yearly)
        store.setLocalOverride(isPro: true)
        XCTAssertEqual(ConversionDiagnostics.subscriberAttributes["funnel_purchaseSucceeded"], "1")
    }

    func testCancellationDoesNotBecomePendingOrSuccessful() {
        let store = StoreService(defaults: testDefaults())
        XCTAssertEqual(store.completePurchase(package(), userCancelled: true), .cancelled)
        XCTAssertFalse(store.isPurchasePending)
    }

    func testVerifiedProCompletesPurchaseImmediately() {
        let store = StoreService(defaults: testDefaults())
        ConversionDiagnostics.defaultsOverride = testDefaults()
        defer { ConversionDiagnostics.defaultsOverride = nil }
        store.setLocalOverride(isPro: true)
        XCTAssertEqual(store.completePurchase(package(), userCancelled: false), .purchased)
        XCTAssertFalse(store.isPurchasePending)
    }
}

extension TrialEligibilityTests {
    func testPendingPurchasePreventsAnotherPurchaseAttempt() async throws {
        let store = StoreService(defaults: testDefaults())
        XCTAssertEqual(store.completePurchase(package(), userCancelled: false), .pending)
        let state = try await store.purchase(package())
        XCTAssertEqual(state, .pending)
        XCTAssertFalse(store.purchaseInFlight)
        XCTAssertTrue(store.isPurchasePending)
    }
}
