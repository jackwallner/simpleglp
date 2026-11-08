import XCTest

/// The release gate's journeys (`qa-gate run`). Each step ends in a
/// `QA.checkpoint`, which runs the fleet oracles on whatever is on screen.
/// Journeys assert reachability, except the core loop, which proves a log lands and persists.
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
        allowSystemAlert(followUps: true)
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
            tapTab(button, name)
            QA.checkpoint(app, name)
        }

        // The screenshot seed hides Settings' Pro row, so upgrade from the
        // Pro preview at the foot of Patterns.
        tapTab(tab(Self.patterns, in: app), "patterns")
        // The whole preview opens the plans; its header is always on screen.
        let upgrade = app.staticTexts.matching(
            NSPredicate(format: "label IN %@", ["What Pro watches for you", "Was Pro für dich im Blick behält"])
        ).firstMatch
        XCTAssertTrue(upgrade.waitForExistence(timeout: 15))
        upgrade.tap()
        XCTAssertTrue(button(["Restore Purchases", "Käufe wiederherstellen"], in: app).waitForExistence(timeout: 20))
        QA.checkpoint(app, "upgrade", paywall: true)
        QA.swipe(app, .down)

        tapTab(tab(Self.oneTap, in: app), "one tap")
        QA.checkpoint(app, "one-tap-return")
        QA.interrupt(app)
        XCTAssertTrue(tab(Self.oneTap, in: app).waitForExistence(timeout: 15))
        QA.checkpoint(app, "one-tap-after-background")
        QA.relaunch(app)
        XCTAssertTrue(tab(Self.oneTap, in: app).waitForExistence(timeout: 20))
        QA.checkpoint(app, "one-tap-after-relaunch")
    }

    /// The core loop: tap the big button and today's dose is recorded, and it is
    /// still listed after the app is killed and reopened. Home names each dose row
    /// by its calendar day, so the check does not depend on the language or on the
    /// next-dose card (which also prints a date): it counts today's rows before and
    /// after.
    func testCoreLoopOneTapLogsTodaysShotAndKeepsIt() {
        let app = XCUIApplication(bundleIdentifier: Self.bundleID)
        QA.launch(app, environment: Self.customer, arguments: ["-uitesting", "-GLPScreenshotSeed", "-rcfunnelprobe"])
        XCTAssertTrue(tab(Self.oneTap, in: app).waitForExistence(timeout: 20))
        let todayID = "recentDose-" + Self.dayStamp(.now)
        let todayRows = app.buttons.matching(identifier: todayID)
        let before = todayRows.count
        QA.checkpoint(app, "one-tap-before-log")

        let log = button(Self.logLabels, in: app)
        XCTAssertTrue(log.waitForExistence(timeout: 15), "log button missing")
        log.tap()
        let confirmation = app.staticTexts.matching(NSPredicate(format: "label IN %@", ["Logged", "Erfasst"])).firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 10), "no confirmation after logging")
        assertCount(todayRows, before + 1, "the new dose is not listed (\(before) rows today before)")

        // The confirmation lasts about two seconds; capture after the button settles back.
        let settled = NSPredicate(format: "label IN %@", Self.logLabels)
        _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: settled, object: log)], timeout: 10)
        sleep(1)
        QA.checkpoint(app, "one-tap-logged")

        // Reopen without the seed, which would replace the logged dose.
        app.launchArguments.removeAll { $0 == "-GLPScreenshotSeed" }
        QA.relaunch(app)
        XCTAssertTrue(tab(Self.oneTap, in: app).waitForExistence(timeout: 20))
        assertCount(todayRows, before + 1, "today's dose does not survive a relaunch")
        QA.checkpoint(app, "one-tap-after-relaunch")
    }

    private func assertCount(_ query: XCUIElementQuery, _ count: Int, _ message: String) {
        let match = NSPredicate { _, _ in query.count == count }
        let wait = XCTNSPredicateExpectation(predicate: match, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 15), .completed, "\(message) (\(query.count) now)")
    }

    /// `yyyy-MM-dd` in the device calendar, matching `RecentShotRow.identifier`.
    private static func dayStamp(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static let oneTap = ["One Tap", "Einmal tippen"]
    private static let patterns = ["Patterns", "Muster"]
    private static let continueLabels = ["Continue", "Weiter"]
    private static let logLabels = ["I took my shot", "Ich habe gespritzt."]

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

    /// A tap can miss on the unfolded Duo; a short press on the button's own
    /// coordinate selects it there too.
    private func tapTab(_ button: XCUIElement, _ name: String) {
        XCTAssertTrue(button.waitForExistence(timeout: 15), "\(name) tab missing")
        button.tap()
        let selected = NSPredicate(format: "isSelected == true")
        if XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: selected, object: button)], timeout: 3) != .completed {
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.05)
        }
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

    /// The notification prompt and then the Health sheet arrive one after the other
    /// after the last onboarding step; with `followUps` every one is answered so the
    /// next checkpoint is not taken while a system sheet is still on its way.
    private func allowSystemAlert(followUps: Bool = false) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let labels = ["Allow", "Don't Allow", "Erlauben", "Nicht erlauben"]
        var wait: TimeInterval = 2
        while true {
            let deadline = Date().addingTimeInterval(wait)
            var answered = false
            while Date() < deadline, !answered {
                if let button = labels.map({ springboard.buttons[$0] }).first(where: { $0.exists && $0.isEnabled }) {
                    button.tap()
                    answered = true
                } else {
                    usleep(250_000)
                }
            }
            guard answered, followUps else { return }
            wait = 3
        }
    }
}
