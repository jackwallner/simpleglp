import XCTest

/// S10 of the 2026-11-06 state machine audit: the weekly One Tap card has to turn
/// overdue when the planned time passes while the screen stays open.
@MainActor
final class WeeklyHomeClockUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testWeeklyCardTurnsOverdueWhileOneTapStaysOpen() throws {
        let calendar = Calendar.current
        let minutesToMidnight = calendar.dateComponents(
            [.minute], from: .now, to: calendar.startOfDay(for: .now).addingTimeInterval(86_400)
        ).minute ?? 0
        try XCTSkipIf(minutesToMidnight < 6, "the seeded dose would fall on tomorrow")

        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.glp")
        app.launchArguments += ["-uitesting", "-GLPScreenshotSeed", "-GLPScreenshotDueSoon"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["One Tap"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["Due today"].waitForExistence(timeout: 20), "precondition: today's dose is still ahead")

        let warning = app.images.matching(NSPredicate(
            format: "identifier == %@ OR label IN %@",
            "exclamationmark.triangle.fill", ["Warning", "Alert", "exclamationmark.triangle.fill"]
        )).firstMatch
        XCTAssertFalse(warning.exists, "precondition: not overdue before the planned time")

        // The seeded dose is due 90 to 150 seconds after launch; give the card a minute past that.
        let turnedOverdue = warning.waitForExistence(timeout: 240)
        if !turnedOverdue {
            add(XCTAttachment(string: app.debugDescription))
        }
        XCTAssertTrue(turnedOverdue, "One Tap still shows the weekly dose as upcoming after its planned time passed")
    }
}
