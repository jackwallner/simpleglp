import XCTest

/// Newcomer persona walk: real first run (onboarding is not bypassed), first log,
/// tab tour and a return launch. Screenshots are kept as attachments for review.
final class NewcomerAuditUITests: XCTestCase {
    private var shotIndex = 0

    override func setUp() {
        continueAfterFailure = true
        addUIInterruptionMonitor(withDescription: "system alert") { alert in
            for label in ["Allow", "Don’t Allow", "Don't Allow", "OK"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.glp")
        app.launchArguments += extra
        app.launch()
        return app
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        shotIndex += 1
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = String(format: "%02d-%@", shotIndex, name)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tapContinue(_ app: XCUIApplication, then name: String) {
        let button = app.buttons["Continue"]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Continue missing before \(name)")
        button.tap()
        sleep(1)
        snap(app, name)
    }

    private func walkOnboarding(_ app: XCUIApplication, pill: Bool) {
        snap(app, "onboarding-welcome")
        tapContinue(app, then: "onboarding-medication")
        if pill {
            let pillCard = app.buttons["Pill"]
            if pillCard.waitForExistence(timeout: 5) { pillCard.tap() }
            sleep(1)
            snap(app, "onboarding-medication-pill")
        }
        tapContinue(app, then: "onboarding-schedule")
        tapContinue(app, then: "onboarding-reminders")
        tapContinue(app, then: "onboarding-health")
        tapContinue(app, then: "onboarding-trial-step")
        let start = app.buttons["Get Started"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "Get Started exit missing")
        start.tap()
        sleep(3)
        app.tap()
        snap(app, "home-after-onboarding")
    }

    func testShotFirstRun() {
        let app = launch()
        walkOnboarding(app, pill: false)

        let log = app.buttons["I took my shot"]
        XCTAssertTrue(log.waitForExistence(timeout: 10), "Log button missing on Home")
        log.tap()
        sleep(1)
        snap(app, "home-just-logged")
        sleep(3)
        snap(app, "home-after-confirmation")

        for tab in ["History", "Patterns", "Settings", "One Tap"] {
            let button = app.tabBars.buttons[tab]
            if button.waitForExistence(timeout: 5) {
                button.tap()
                sleep(1)
                snap(app, "tab-\(tab.lowercased().replacingOccurrences(of: " ", with: "-"))")
            } else {
                XCTFail("Tab \(tab) missing")
            }
        }

        app.terminate()
        let again = launch()
        sleep(3)
        snap(again, "return-visit")
    }

    func testPillFirstRun() {
        let app = launch()
        walkOnboarding(app, pill: true)
        let log = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'took my pill'")).firstMatch
        XCTAssertTrue(log.waitForExistence(timeout: 10), "Pill log button missing")
        log.tap()
        sleep(2)
        snap(app, "pill-just-logged")
        app.swipeUp()
        sleep(1)
        snap(app, "pill-scrolled")
        app.tabBars.buttons["Settings"].tap()
        sleep(1)
        snap(app, "pill-settings")
    }

    func testShotFirstRunLargeText() {
        let app = launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"])
        snap(app, "xl-welcome")
        tapContinue(app, then: "xl-medication")
        tapContinue(app, then: "xl-schedule")
        tapContinue(app, then: "xl-reminders")
        tapContinue(app, then: "xl-health")
        tapContinue(app, then: "xl-trial-step")
    }
}
