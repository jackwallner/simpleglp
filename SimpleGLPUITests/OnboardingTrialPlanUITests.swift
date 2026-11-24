import XCTest

/// The onboarding trial button buys monthly unless the offering's
/// `onboarding_plan` says yearly: the disclosure under it must quote the
/// monthly charge. `-rcfunnelprobe` loads RevenueCat's Test Store, never the
/// production key. The Test Store has no intro offers, so the page reads
/// "Unlock ... for $X / month"; the free-trial wording is pinned in
/// `OnboardingPlanTests`.
@MainActor
final class OnboardingTrialPlanUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testTrialPageQuotesTheMonthlyCharge() {
        let app = trialPage([])
        let monthly = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '/ month' AND label CONTAINS 'Auto-renews'")).firstMatch
        XCTAssertTrue(monthly.waitForExistence(timeout: 30), "the trial page does not quote a monthly charge")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '/ year'")).firstMatch.exists)
        attach(app, "onboarding-trial-monthly")
    }

    func testYearlySwitchQuotesTheYearlyCharge() {
        let app = trialPage(["-GLPOnboardingPlan", "yearly"])
        let yearly = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '/ year' AND label CONTAINS 'Auto-renews'")).firstMatch
        XCTAssertTrue(yearly.waitForExistence(timeout: 30), "the yearly switch did not reach the trial page")
        attach(app, "onboarding-trial-yearly")
    }

    private func trialPage(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.glp")
        app.launchArguments = ["-rcfunnelprobe"] + extra
        app.launchEnvironment["RC_PROBE_USER"] = "qa-onboarding-plan-\(UUID().uuidString.prefix(8))"
        app.launchEnvironment["RC_PROBE_SURFACE"] = "qa_gate"
        app.launch()
        for _ in 0..<5 {
            let next = app.buttons["Continue"]
            XCTAssertTrue(next.waitForExistence(timeout: 20))
            next.tap()
            answerSystemAlert()
        }
        XCTAssertTrue(app.buttons["Get Started"].waitForExistence(timeout: 20))
        return app
    }

    private func answerSystemAlert() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if let button = ["Allow", "Don't Allow"].map({ springboard.buttons[$0] }).first(where: { $0.exists }) {
                button.tap()
                return
            }
            usleep(250_000)
        }
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
