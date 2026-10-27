import XCTest

@MainActor
final class ReleaseJourneysUITests: XCTestCase {
    private let seedArgument = "-GLPScreenshotSeed"
    private var allowMonitor: NSObjectProtocol?

    override func setUp() {
        continueAfterFailure = false
        // A foreground log may raise the notification permission alert; answer it so it
        // never sits over the screen being checked.
        allowMonitor = addUIInterruptionMonitor(withDescription: "notifications") { alert in
            for label in ["Allow", "OK", "Don\u{2019}t Allow"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
    }

    /// Core loop: tap the big button to log a dose, see it listed on Home and in History,
    /// and still find it after the app is killed and relaunched.
    func testCoreLoopLogDoseListsItAndKeepsItAfterRelaunch() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.glp")
        QA.launch(app, arguments: ["-uitesting", seedArgument])

        let logButton = app.buttons["I took my shot"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 20), "Home never showed the log button")
        XCTAssertEqual(todayRows(in: app).count, 0, "the seeded history already has a dose today")
        QA.checkpoint(app, "home-before-log")

        logButton.tap()
        XCTAssertTrue(app.buttons["Logged"].waitForExistence(timeout: 10), "tapping the button did not confirm a log")
        XCTAssertTrue(todayRows(in: app).firstMatch.waitForExistence(timeout: 10),
                      "the new dose is not in Home's recent list")
        QA.checkpoint(app, "home-after-log")

        openTab("History", in: app)
        XCTAssertTrue(todayRows(in: app).firstMatch.waitForExistence(timeout: 10),
                      "the new dose is not in History")
        XCTAssertTrue(todayRows(in: app).firstMatch.label.contains("5"), "the logged row lost its dose")
        QA.checkpoint(app, "history-after-log")

        // The seed rebuilds the data on every launch, so the relaunch drops it to prove the
        // store itself kept the dose.
        app.launchArguments.removeAll { $0 == seedArgument }
        QA.relaunch(app)
        openTab("History", in: app)
        XCTAssertTrue(todayRows(in: app).firstMatch.waitForExistence(timeout: 20),
                      "the logged dose is gone after relaunch")
        QA.checkpoint(app, "history-after-relaunch")

        openTab("One Tap", in: app)
        XCTAssertTrue(todayRows(in: app).firstMatch.waitForExistence(timeout: 10),
                      "Home lost the logged dose after relaunch")
        QA.checkpoint(app, "home-after-relaunch")
    }

    /// Rows whose date is today. Seeded doses are all a day or more old.
    private func todayRows(in app: XCUIApplication) -> XCUIElementQuery {
        let today = Date.now.formatted(date: .abbreviated, time: .omitted)
        return app.buttons.matching(NSPredicate(format: "label CONTAINS %@", today))
    }

    /// Tab bar on iPhone, sidebar item on the Duo: both are buttons with the tab's title.
    private func openTab(_ title: String, in app: XCUIApplication) {
        let tab = app.buttons[title].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "no \(title) tab or sidebar item")
        tab.tap()
    }
}
