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
        allowSystemAlert(followUps: true)
        XCTAssertTrue(tabButton(L("One Tap"), in: app).waitForExistence(timeout: 20))
        QA.checkpoint(app, "first-one-tap")
    }

    func test2LogTabsUpgradeAndReturn() {
        let app = XCUIApplication(bundleIdentifier: Self.bundleID)
        QA.launch(app, environment: Self.customer, arguments: ["-uitesting", "-GLPScreenshotSeed", "-rcfunnelprobe"])
        XCTAssertTrue(tabButton(L("One Tap"), in: app).waitForExistence(timeout: 20))
        QA.checkpoint(app, "one-tap")

        for tab in ["History", "Patterns", "Settings"] {
            // Unfolded, History is its own pane beside One Tap and has no tab.
            if tab == "History" && !tabButton(L(tab), in: app).waitForExistence(timeout: 3) {
                QA.checkpoint(app, tab.lowercased())
                continue
            }
            tapTab(L(tab), in: app)
            QA.checkpoint(app, tab.lowercased())
        }

        // The screenshot seed hides Settings' Pro row, so upgrade from the
        // Pro preview at the foot of Patterns.
        tapTab(L("Patterns"), in: app)
        // The whole preview opens the plans; its header is always on screen.
        let upgrade = app.staticTexts[L("What Pro watches for you")].firstMatch
        XCTAssertTrue(upgrade.waitForExistence(timeout: 15))
        upgrade.tap()
        XCTAssertTrue(app.buttons[L("Restore Purchases")].firstMatch.waitForExistence(timeout: 20))
        QA.checkpoint(app, "upgrade", paywall: true)
        app.swipeDown(velocity: .fast)

        tapTab(L("One Tap"), in: app)
        QA.checkpoint(app, "one-tap-return")
        QA.interrupt(app)
        XCTAssertTrue(tabButton(L("One Tap"), in: app).waitForExistence(timeout: 15))
        QA.checkpoint(app, "one-tap-after-background")
        QA.relaunch(app)
        XCTAssertTrue(tabButton(L("One Tap"), in: app).waitForExistence(timeout: 20))
        QA.checkpoint(app, "one-tap-after-relaunch")
    }

    /// Core loop: one tap logs today's shot, and it is still in the list
    /// after the app is killed and reopened.
    func testCoreLoopOneTapLogsTodaysShotAndKeepsIt() {
        let app = XCUIApplication(bundleIdentifier: Self.bundleID)
        QA.launch(app, environment: Self.customer, arguments: ["-uitesting", "-GLPScreenshotSeed", "-rcfunnelprobe"])
        XCTAssertTrue(tabButton(L("One Tap"), in: app).waitForExistence(timeout: 20))
        QA.checkpoint(app, "one-tap-before-log")
        let locale = Locale(identifier: QA.persona == "german" ? "de_DE" : "en_US")
        let today = Date.now.formatted(Date.FormatStyle(date: .long, time: .omitted).locale(locale))
        let todays = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", today))
        let before = todays.count
        let shot = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", L("I took my shot"))).firstMatch
        XCTAssertTrue(shot.waitForExistence(timeout: 15))
        shot.tap()
        // Unfolded, History's pane lists the shot beside One Tap's recent list.
        let grew = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count > %d", before), object: todays)
        XCTAssertEqual(XCTWaiter().wait(for: [grew], timeout: 15), .completed, "the shot is logged for today")
        let logged = todays.count
        // The confirmation lasts about two seconds; capture after the button settles back.
        let settled = NSPredicate(format: "label BEGINSWITH %@", L("I took my shot"))
        _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: settled, object: shot)], timeout: 10)
        sleep(1)
        QA.checkpoint(app, "one-tap-logged")
        // Reopen without the seed, which would replace the logged shot.
        app.launchArguments.removeAll { $0 == "-GLPScreenshotSeed" }
        QA.relaunch(app)
        XCTAssertTrue(tabButton(L("One Tap"), in: app).waitForExistence(timeout: 20))
        assertCount(todays, logged, "today's shot survives a relaunch")
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

    /// A tab bar on a phone; unfolded, the Duo's bar is not a `tabBars`
    /// element, so match the tab's button by label wherever it sits.
    private func tabButton(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// A tap can miss on the unfolded Duo; a short press on the button's own
    /// coordinate selects it there too.
    private func tapTab(_ label: String, in app: XCUIApplication) {
        let button = tabButton(label, in: app)
        XCTAssertTrue(button.waitForExistence(timeout: 15), "\(label) tab")
        button.tap()
        let selected = NSPredicate(format: "isSelected == true")
        if XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: selected, object: button)], timeout: 3) != .completed {
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.05)
        }
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

    /// The notification prompt and then the Health sheet arrive one after the other
    /// after the last onboarding step; with `followUps` every one is answered so the
    /// next checkpoint is not taken while a system sheet is still on its way.
    private func allowSystemAlert(followUps: Bool = false) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let labels = [L("Allow"), L("Don't Allow")]
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
