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
            checkpoint(name, button: L("Continue"), in: app)
            tap(L("Continue"), in: app)
            allowSystemAlert()
        }
        XCTAssertTrue(app.buttons[L("Get Started")].waitForExistence(timeout: 20))
        QA.checkpoint(app, "onboarding-trial", paywall: true)
        tap(L("Get Started"), in: app)
        allowSystemAlert()
        XCTAssertTrue(app.tabBars.buttons[L("One Tap")].waitForExistence(timeout: 20))
        QA.checkpoint(app, "first-one-tap")
    }

    func test2LogTabsUpgradeAndReturn() {
        let app = XCUIApplication(bundleIdentifier: Self.bundleID)
        QA.launch(app, environment: Self.customer, arguments: ["-uitesting", "-GLPScreenshotSeed", "-rcfunnelprobe"])
        XCTAssertTrue(app.tabBars.buttons[L("One Tap")].waitForExistence(timeout: 20))
        QA.checkpoint(app, "one-tap")

        for tab in ["History", "Patterns", "Settings"] {
            let button = app.tabBars.buttons[L(tab)]
            XCTAssertTrue(button.waitForExistence(timeout: 10))
            button.tap()
            QA.checkpoint(app, tab.lowercased())
        }

        // The screenshot seed hides Settings' Pro row, so upgrade from the
        // Pro preview at the foot of Patterns.
        app.tabBars.buttons[L("Patterns")].tap()
        // The whole preview opens the plans; its header is always on screen.
        let upgrade = app.staticTexts[L("What Pro watches for you")].firstMatch
        XCTAssertTrue(upgrade.waitForExistence(timeout: 15))
        upgrade.tap()
        XCTAssertTrue(app.buttons[L("Restore Purchases")].firstMatch.waitForExistence(timeout: 20))
        QA.checkpoint(app, "upgrade", paywall: true)
        app.swipeDown(velocity: .fast)

        app.tabBars.buttons[L("One Tap")].tap()
        QA.checkpoint(app, "one-tap-return")
        QA.interrupt(app)
        XCTAssertTrue(app.tabBars.buttons[L("One Tap")].waitForExistence(timeout: 15))
        QA.checkpoint(app, "one-tap-after-background")
        QA.relaunch(app)
        XCTAssertTrue(app.tabBars.buttons[L("One Tap")].waitForExistence(timeout: 20))
        QA.checkpoint(app, "one-tap-after-relaunch")
    }

    /// Core loop: one tap logs today's shot, and it is still in the list
    /// after the app is killed and reopened.
    func testCoreLoopOneTapLogsTodaysShotAndKeepsIt() {
        let app = XCUIApplication(bundleIdentifier: Self.bundleID)
        QA.launch(app, environment: Self.customer, arguments: ["-uitesting", "-GLPScreenshotSeed", "-rcfunnelprobe"])
        XCTAssertTrue(app.tabBars.buttons[L("One Tap")].waitForExistence(timeout: 20))
        QA.checkpoint(app, "one-tap-before-log")
        let locale = Locale(identifier: QA.persona == "german" ? "de_DE" : "en_US")
        let today = Date.now.formatted(Date.FormatStyle(date: .long, time: .omitted).locale(locale))
        let todays = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", today))
        let before = todays.count
        let shot = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", L("I took my shot"))).firstMatch
        XCTAssertTrue(shot.waitForExistence(timeout: 15))
        shot.tap()
        assertCount(todays, before + 1, "the shot is logged for today")
        QA.checkpoint(app, "one-tap-logged")
        // Reopen without the seed, which would replace the logged shot.
        app.launchArguments.removeAll { $0 == "-GLPScreenshotSeed" }
        QA.relaunch(app)
        XCTAssertTrue(app.tabBars.buttons[L("One Tap")].waitForExistence(timeout: 20))
        assertCount(todays, before + 1, "today's shot survives a relaunch")
        QA.checkpoint(app, "one-tap-after-relaunch")
    }

    private func assertCount(_ query: XCUIElementQuery, _ count: Int, _ message: String) {
        let match = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == %d", count), object: query)
        XCTAssertEqual(XCTWaiter().wait(for: [match], timeout: 15), .completed, message)
    }

    /// The German strings the journeys look for; other personas see the English source.
    private static let german = [
        "Continue": "Weiter", "Get Started": "Loslegen", "One Tap": "Einmal tippen",
        "History": "Verlauf", "Patterns": "Muster", "Settings": "Einstellungen",
        "What Pro watches for you": "Was Pro für dich im Blick behält",
        "Restore Purchases": "Käufe wiederherstellen", "I took my shot": "Ich habe gespritzt.",
        "Allow": "Erlauben", "Don't Allow": "Nicht erlauben",
    ]

    private func L(_ english: String) -> String {
        QA.persona == "german" ? Self.german[english] ?? english : english
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
        for label in [L("Allow"), L("Don't Allow")] where springboard.buttons[label].waitForExistence(timeout: 2) {
            springboard.buttons[label].tap()
            return
        }
    }
}
