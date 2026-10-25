import XCTest

/// The release gate's journeys (`qa-gate run`). Each step ends in a
/// `QA.checkpoint`, which runs the fleet oracles on whatever is on screen.
/// Journeys assert reachability only.
///
/// `-rcfunnelprobe` loads plans from RevenueCat's Test Store (a separate app in
/// the project, never the production key), so the paywalls render real prices
/// on the simulator.
@MainActor
final class ReleaseJourneysUITests: XCTestCase {
    private static let bundleID = "com.jackwallner.glp"
    private static let customer = ["RC_PROBE_USER": "qa-ios-journeys", "RC_PROBE_SURFACE": "qa_gate"]

    override func setUp() {
        continueAfterFailure = false
    }

    func test1FirstRunToTrial() {
        let app = XCUIApplication(bundleIdentifier: Self.bundleID)
        QA.launch(app, environment: Self.customer, arguments: ["-rcfunnelprobe"])
        for name in ["welcome", "medication", "schedule", "reminders", "health"] {
            checkpoint(name, button: "Continue", in: app)
            tap("Continue", in: app)
            allowSystemAlert()
        }
        XCTAssertTrue(app.buttons["Get Started"].waitForExistence(timeout: 20))
        QA.checkpoint(app, "onboarding-trial", paywall: true)
        tap("Get Started", in: app)
        allowSystemAlert()
        XCTAssertTrue(app.tabBars.buttons["One Tap"].waitForExistence(timeout: 20))
        QA.checkpoint(app, "first-one-tap")
    }

    func test2LogTabsUpgradeAndReturn() {
        let app = XCUIApplication(bundleIdentifier: Self.bundleID)
        QA.launch(app, environment: Self.customer, arguments: ["-uitesting", "-GLPScreenshotSeed", "-rcfunnelprobe"])
        XCTAssertTrue(app.tabBars.buttons["One Tap"].waitForExistence(timeout: 20))
        QA.checkpoint(app, "one-tap")

        for tab in ["History", "Patterns", "Settings"] {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 10))
            button.tap()
            QA.checkpoint(app, tab.lowercased())
        }

        // The Pro row sits below the fold of the Settings list.
        let upgrade = app.buttons["Upgrade to Pro"].firstMatch
        var swipes = 0
        while !(upgrade.exists && upgrade.isHittable) && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        upgrade.tap()
        XCTAssertTrue(app.buttons["Restore"].firstMatch.waitForExistence(timeout: 20))
        QA.checkpoint(app, "upgrade", paywall: true)
        app.swipeDown(velocity: .fast)

        app.tabBars.buttons["One Tap"].tap()
        QA.checkpoint(app, "one-tap-return")
        QA.interrupt(app)
        XCTAssertTrue(app.tabBars.buttons["One Tap"].waitForExistence(timeout: 15))
        QA.checkpoint(app, "one-tap-after-background")
        QA.relaunch(app)
        XCTAssertTrue(app.tabBars.buttons["One Tap"].waitForExistence(timeout: 20))
        QA.checkpoint(app, "one-tap-after-relaunch")
    }

    private func tap(_ label: String, in app: XCUIApplication) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15), "\(label) missing")
        button.tap()
    }

    private func checkpoint(_ name: String, button label: String, in app: XCUIApplication) {
        XCTAssertTrue(app.buttons[label].firstMatch.waitForExistence(timeout: 15), "\(label) missing")
        QA.checkpoint(app, name)
    }

    private func allowSystemAlert() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow", "Don't Allow"] where springboard.buttons[label].waitForExistence(timeout: 2) {
            springboard.buttons[label].tap()
            return
        }
    }
}
