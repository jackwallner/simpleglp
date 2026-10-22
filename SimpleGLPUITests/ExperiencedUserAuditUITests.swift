import XCTest

/// Persona audit flows for an experienced user repeating core tasks: log, backfill,
/// edit details, titrate, read patterns, export. Every step attaches a screenshot,
/// and `measure` attaches the frame of controls so touch targets are numbers, not guesses.
/// Deterministic: seeded debug data only, no purchases, no production keys.
final class ExperiencedUserAuditUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
    }

    private func launch(pill: Bool = false, pro: Bool = false) {
        app = XCUIApplication(bundleIdentifier: "com.jackwallner.glp")
        app.launchArguments += ["-uitesting", "-GLPScreenshotSeed"]
        if pill { app.launchArguments.append("-GLPScreenshotPill") }
        if pro { app.launchArguments.append("-GLPScreenshotPro") }
        app.launch()
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 30)
        sleep(2)
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func note(_ name: String, _ text: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Records the on-screen size of a control, the way a finger would meet it.
    private func measure(_ label: String, _ element: XCUIElement) {
        guard element.waitForExistence(timeout: 5) else {
            note("size-\(label)", "\(label): NOT FOUND")
            return
        }
        let f = element.frame
        note("size-\(label)", "\(label): \(Int(f.width)) x \(Int(f.height)) pt at (\(Int(f.minX)), \(Int(f.minY)))")
    }

    private func tab(_ name: String) {
        app.tabBars.buttons[name].tap()
        sleep(1)
    }

    private func tapRow(_ label: String) {
        let candidates = [app.buttons[label], app.cells.containing(.staticText, identifier: label).firstMatch, app.staticTexts[label]]
        for element in candidates where element.waitForExistence(timeout: 3) {
            element.tap()
            sleep(1)
            return
        }
        note("missing-\(label)", "could not find \(label)")
    }

    // MARK: - Weekly shot user

    func testWeeklyShotCoreLoop() {
        launch()
        snap("01-home-weekly-seeded")
        measure("home-took-it-earlier-link", app.buttons["Took it earlier?"])
        measure("home-log-button", app.buttons["I took my shot"])

        app.buttons["I took my shot"].tap()
        snap("02-home-right-after-log")
        sleep(3)
        snap("03-home-3s-after-log-banner-undo")
        measure("home-undo", app.buttons["Undo"])
        note("undo-present-3s", "Undo visible after 3s: \(app.buttons["Undo"].exists)")

        // Undo is meant for a mistaken tap. Does it linger after leaving the screen?
        tab("History")
        snap("04-history-after-log")
        tab("One Tap")
        sleep(1)
        note("undo-present-after-tab-roundtrip", "Undo visible after History round trip: \(app.buttons["Undo"].exists)")
        snap("05-home-after-tab-roundtrip")
    }

    func testBackfillFromHistoryAndEditDetails() {
        launch()
        tab("History")
        snap("10-history-weekly")
        measure("history-plus", app.buttons["Log a past dose"])
        app.buttons["Log a past dose"].tap()
        sleep(1)
        snap("11-log-earlier-sheet-from-history")
        measure("log-earlier-chip-5m", app.buttons["5 minutes ago"])
        // Back-date by a day with the compact picker is not scriptable reliably; log "1h ago".
        if app.buttons["60 minutes ago"].exists { app.buttons["60 minutes ago"].tap() }
        snap("12-log-earlier-chip-chosen")
        app.buttons["Log"].tap()
        sleep(2)
        snap("13-history-after-backfill")

        // Open the newest row for details.
        let firstRow = app.cells.firstMatch
        if firstRow.waitForExistence(timeout: 5) {
            measure("history-row", firstRow)
            firstRow.tap()
        }
        sleep(1)
        snap("14-edit-sheet-top")
        let feelingRows = app.steppers
        note("edit-stepper-count", "steppers in edit sheet: \(feelingRows.count)")
        if feelingRows.count > 0 { measure("edit-stepper-first", feelingRows.element(boundBy: 0)) }

        // Rate nausea 3: count the taps an experienced user needs from "–".
        let nausea = app.steppers.firstMatch
        if nausea.exists {
            let plus = nausea.buttons["Increment"]
            for _ in 0..<4 { plus.tap() }
            snap("15-edit-nausea-after-4-taps")
        }
        let notes = app.textFields["Notes"]
        if notes.waitForExistence(timeout: 2) {
            notes.tap()
            notes.typeText("felt fine, a bit tired")
            snap("16-edit-notes-typing-keyboard-up")
            app.navigationBars["Details"].tap()
        }

        // Swipe the sheet away without pressing Save.
        let nav = app.navigationBars["Details"]
        let from = nav.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let to = nav.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 12))
        from.press(forDuration: 0.1, thenDragTo: to)
        sleep(2)
        snap("17-after-swipe-dismiss-no-save-prompt")
        note("sheet-dismissed-silently", "Details nav bar still present after swipe: \(app.navigationBars["Details"].exists)")

        // Reopen: was anything kept?
        let again = app.cells.firstMatch
        if again.exists { again.tap(); sleep(1) }
        snap("18-edit-sheet-reopened-edits-lost?")
    }

    func testTitrationAndPlanEditorConsistency() {
        launch()
        tab("Settings")
        snap("20-settings-top")
        tapRow("Medication & schedule")
        snap("21-plan-editor-current-dose")
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)
        tapRow("Dose schedule")
        snap("22-dose-schedule-before")
        tapRow("Add step")
        snap("23-add-step-sheet-defaults")
        let add = app.buttons["Add"]
        if add.waitForExistence(timeout: 3) { add.tap(); sleep(1) }
        snap("24-dose-schedule-after-add-default")
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)
        tapRow("Medication & schedule")
        snap("25-plan-editor-after-step-current-dose-unchanged?")
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)
        tab("One Tap")
        snap("26-home-dose-card-after-step")
    }

    func testPatternsAndDataFlows() {
        launch(pro: true)
        tab("Patterns")
        snap("30-patterns-weekly-pro")
        app.swipeUp()
        snap("31-patterns-scrolled")
        tab("Settings")
        tapRow("Export")
        snap("32-export-before-generate")
        let gen = app.buttons["Generate CSV"]
        if gen.waitForExistence(timeout: 3) { gen.tap(); sleep(1) }
        snap("33-export-after-generate")
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)
        tapRow("Import")
        snap("34-import-screen")
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)
        tapRow("Supply & refills")
        snap("35-supply-untracked")
        measure("supply-start-tracking", app.buttons["Start tracking"])
    }

    // MARK: - Daily pill user

    func testPillCoreLoop() {
        launch(pill: true)
        snap("40-pill-home-countdown")
        measure("pill-week-strip-day", app.buttons.matching(NSPredicate(format: "label CONTAINS 'taken'")).firstMatch)
        measure("pill-today-edit", app.buttons.matching(NSPredicate(format: "label CONTAINS 'Taken at'")).firstMatch)
        tab("History")
        snap("41-pill-history-month")
        let day = app.buttons.matching(NSPredicate(format: "label CONTAINS 'not logged'")).firstMatch
        measure("pill-month-missed-day", day)
        if day.waitForExistence(timeout: 3) {
            day.tap()
            sleep(1)
            snap("42-pill-backfill-missed-day-sheet")
        }
    }

    func testPillLogEarlierAndSupply() {
        launch(pill: true, pro: true)
        snap("50-pill-home-pro")
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS 'left'")).firstMatch
        if card.waitForExistence(timeout: 3) { card.tap(); sleep(1); snap("51-supply-tracking") }
        measure("supply-refill-button", app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'I refilled'")).firstMatch)
    }
}
