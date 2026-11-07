import XCTest

/// The release gate's journeys (`qa-gate run`). Each step ends in a
/// `QA.checkpoint`, which runs the fleet oracles on whatever is on screen.
/// Journeys assert reachability, except `testCoreLoop`, which proves a log lands.
///
/// Labels are matched in English or German (the german persona), and tabs are
/// found as buttons because the unfolded Duo draws its bar vertically and moves
/// History into its own pane.
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
            checkpoint(name, button: Self.continueLabels, in: app)
            tap(Self.continueLabels, in: app)
            allowSystemAlert()
        }
        XCTAssertTrue(button(["Get Started", "Loslegen"], in: app).waitForExistence(timeout: 20))
        QA.checkpoint(app, "onboarding-trial", paywall: true)
        tap(["Get Started", "Loslegen"], in: app)
        allowSystemAlert()
        XCTAssertTrue(tab(Self.oneTap, in: app).waitForExistence(timeout: 20))
        QA.checkpoint(app, "first-one-tap")
    }

    func test2LogTabsUpgradeAndReturn() {
        let app = XCUIApplication(bundleIdentifier: Self.bundleID)
        QA.launch(app, environment: Self.customer, arguments: ["-uitesting", "-GLPScreenshotSeed", "-rcfunnelprobe"])
        XCTAssertTrue(tab(Self.oneTap, in: app).waitForExistence(timeout: 20))
        QA.checkpoint(app, "one-tap")

        let tabs: [(name: String, labels: [String])] = [
            ("history", ["History", "Verlauf"]),
            ("patterns", Self.patterns),
            ("settings", ["Settings", "Einstellungen"]),
        ]
        for (name, labels) in tabs {
            let button = tab(labels, in: app)
            // Unfolded, History is a pane beside One Tap, not a tab.
            if name == "history", !button.waitForExistence(timeout: 3), QA.persona == "duo" {
                QA.checkpoint(app, name)
                continue
            }
            XCTAssertTrue(button.waitForExistence(timeout: 10), "\(name) tab missing")
            button.tap()
            QA.checkpoint(app, name)
        }

        // The screenshot seed hides Settings' Pro row, so upgrade from the
        // Pro preview at the foot of Patterns.
        tab(Self.patterns, in: app).tap()
        // The whole preview opens the plans; its header is always on screen.
        let upgrade = app.staticTexts.matching(
            NSPredicate(format: "label IN %@", ["What Pro watches for you", "Was Pro für dich im Blick behält"])
        ).firstMatch
        XCTAssertTrue(upgrade.waitForExistence(timeout: 15))
        upgrade.tap()
        XCTAssertTrue(button(["Restore Purchases", "Käufe wiederherstellen"], in: app).waitForExistence(timeout: 20))
        QA.checkpoint(app, "upgrade", paywall: true)
        QA.swipe(app, .down)

        tab(Self.oneTap, in: app).tap()
        QA.checkpoint(app, "one-tap-return")
        QA.interrupt(app)
        XCTAssertTrue(tab(Self.oneTap, in: app).waitForExistence(timeout: 15))
        QA.checkpoint(app, "one-tap-after-background")
        QA.relaunch(app)
        XCTAssertTrue(tab(Self.oneTap, in: app).waitForExistence(timeout: 20))
        QA.checkpoint(app, "one-tap-after-relaunch")
    }

    /// The core loop: tap the big button and the dose is recorded. The seed's
    /// doses are all in the past, so a row dated today appears only once the
    /// log has saved. (The seed rebuilds its data each launch, so this does not
    /// assert persistence across a relaunch.)
    func testCoreLoopLogsDose() {
        let app = XCUIApplication(bundleIdentifier: Self.bundleID)
        QA.launch(app, environment: Self.customer, arguments: ["-uitesting", "-GLPScreenshotSeed", "-rcfunnelprobe"])
        XCTAssertTrue(tab(Self.oneTap, in: app).waitForExistence(timeout: 20))
        let today = Date.now.formatted(date: .long, time: .omitted)
        let todayRow = app.staticTexts.matching(NSPredicate(format: "label == %@", today)).firstMatch
        XCTAssertFalse(todayRow.exists, "a dose dated today is listed before logging")
        QA.checkpoint(app, "core-before-log")

        let log = button(["I took my shot", "Ich habe gespritzt."], in: app)
        XCTAssertTrue(log.waitForExistence(timeout: 15), "log button missing")
        log.tap()
        let confirmation = app.staticTexts.matching(NSPredicate(format: "label IN %@", ["Logged", "Erfasst"])).firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 10), "no confirmation after logging")
        QA.checkpoint(app, "core-logged")

        XCTAssertTrue(todayRow.waitForExistence(timeout: 10), "the new dose is not listed")
        QA.checkpoint(app, "core-listed")
    }

    private static let oneTap = ["One Tap", "Einmal tippen"]
    private static let patterns = ["Patterns", "Muster"]
    private static let continueLabels = ["Continue", "Weiter"]

    private func button(_ labels: [String], in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
    }

    /// A tab, found as a button so it also resolves in the Duo's vertical bar.
    private func tab(_ labels: [String], in app: XCUIApplication) -> XCUIElement {
        let bar = app.tabBars.firstMatch
        let scope = bar.exists ? bar : app.otherElements.firstMatch
        let inBar = scope.buttons.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
        return inBar.exists ? inBar : button(labels, in: app)
    }

    private func tap(_ labels: [String], in app: XCUIApplication) {
        let button = button(labels, in: app)
        XCTAssertTrue(button.waitForExistence(timeout: 15), "\(labels[0]) missing")
        button.tap()
    }

    private func checkpoint(_ name: String, button labels: [String], in app: XCUIApplication,
                            journey: String = #function) {
        XCTAssertTrue(button(labels, in: app).waitForExistence(timeout: 15), "\(labels[0]) missing")
        QA.checkpoint(app, name, journey: journey)
    }

    private func allowSystemAlert() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow", "Don't Allow", "Erlauben", "Nicht erlauben"]
        where springboard.buttons[label].waitForExistence(timeout: 2) {
            springboard.buttons[label].tap()
            return
        }
    }
}
