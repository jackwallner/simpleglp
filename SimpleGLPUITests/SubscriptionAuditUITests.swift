import XCTest

/// Persona audit flows for a skeptical free user weighing Pro: what is locked, what the
/// paywall says, how restore and exit behave. Every step attaches a screenshot and
/// `measure` records control frames. Deterministic: simulator never configures RevenueCat
/// (StoreService returns early), so plans never load and no purchase is possible.
final class SubscriptionAuditUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
    }

    private func launch(seed: Bool = false, pill: Bool = false, pro: Bool = false, extra: [String] = []) {
        app = XCUIApplication(bundleIdentifier: "com.jackwallner.glp")
        app.launchArguments += ["-uitesting"]
        if seed { app.launchArguments.append("-GLPScreenshotSeed") }
        if pill { app.launchArguments.append("-GLPScreenshotPill") }
        if pro { app.launchArguments.append("-GLPScreenshotPro") }
        app.launchArguments += extra
        app.launch()
        _ = app.tabBars.firstMatch.waitForExistence(timeout: extra.contains("-PaywallSnapshot") ? 3 : 30)
        sleep(2)
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
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

    private func measure(_ label: String, _ element: XCUIElement) {
        guard element.waitForExistence(timeout: 4) else {
            note("size-\(label)", "\(label): NOT FOUND")
            return
        }
        let f = element.frame
        note("size-\(label)", "\(label): \(Int(f.width)) x \(Int(f.height)) pt at (\(Int(f.minX)), \(Int(f.minY))), hittable \(element.isHittable)")
    }

    private func tab(_ name: String) {
        app.tabBars.buttons[name].tap()
        sleep(1)
    }

    private func tapRow(_ label: String) -> Bool {
        let candidates = [app.buttons[label], app.cells.containing(.staticText, identifier: label).firstMatch, app.staticTexts[label]]
        for element in candidates where element.waitForExistence(timeout: 3) {
            element.tap()
            sleep(1)
            return true
        }
        note("missing-\(label)", "could not find \(label)")
        return false
    }

    /// Dumps every visible static text and button label, so copy can be read without OCR.
    private func dump(_ name: String) {
        let texts = app.staticTexts.allElementsBoundByIndex.prefix(60).map { $0.label }
        let buttons = app.buttons.allElementsBoundByIndex.prefix(40).map { "\($0.label) [\(Int($0.frame.width))x\(Int($0.frame.height))]" }
        note("dump-\(name)", "TEXTS:\n" + texts.joined(separator: "\n") + "\nBUTTONS:\n" + buttons.joined(separator: "\n"))
    }

    // MARK: - Paywall from Settings (free user, no seed so the Pro section is shown)

    func testSettingsProSectionAndPaywall() {
        launch()
        tab("Settings")
        snap("01-settings-top-free")
        app.swipeUp()
        snap("02-settings-scrolled-free")
        dump("settings-free")
        measure("settings-upgrade-row", app.buttons["Upgrade to Pro"])
        measure("settings-restore-row", app.buttons["Restore purchases"])
        note("manage-subscription-row", "Manage/Cancel subscription row present: \(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'manage' OR label CONTAINS[c] 'cancel'")).count > 0)")

        // Restore with nothing to restore: is there any feedback in Settings?
        if app.buttons["Restore purchases"].exists {
            app.buttons["Restore purchases"].tap()
            snap("03-settings-restore-tapped-0s")
            sleep(3)
            snap("04-settings-restore-tapped-3s")
            note("settings-restore-feedback", "alerts: \(app.alerts.count), staticTexts containing 'restore' or 'found': \(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'restor' OR label CONTAINS[c] 'found'")).count)")
        }

        if app.buttons["Upgrade to Pro"].exists {
            app.buttons["Upgrade to Pro"].tap()
            sleep(2)
            snap("05-paywall-from-settings")
            dump("paywall")
            measure("paywall-close", app.buttons["Close"])
            measure("paywall-primary", app.buttons["Try Again"])
            measure("paywall-restore", app.buttons["Restore Purchases"])
            measure("paywall-terms", app.links["Terms"])
            measure("paywall-privacy", app.links["Privacy Policy"])

            if app.buttons["Restore Purchases"].exists {
                app.buttons["Restore Purchases"].tap()
                sleep(2)
                snap("06-paywall-restore-tapped")
            }
            if app.buttons["Try Again"].exists {
                app.buttons["Try Again"].tap()
                sleep(2)
                snap("07-paywall-try-again-tapped")
            }
            // Exit path 1: Close button.
            if app.buttons["Close"].exists {
                app.buttons["Close"].tap()
                sleep(1)
                snap("08-after-close-button")
                note("exit-close", "Settings nav bar visible after Close: \(app.navigationBars["Settings"].exists)")
            }
        }
        // Exit path 2: swipe down.
        if app.buttons["Upgrade to Pro"].exists {
            app.buttons["Upgrade to Pro"].tap()
            sleep(2)
            app.swipeDown()
            sleep(1)
            snap("09-after-swipe-dismiss")
            note("exit-swipe", "Upgrade row visible again after swipe: \(app.buttons["Upgrade to Pro"].exists)")
        }
    }

    func testLockedSupplyRowOpensPaywall() {
        launch()
        tab("Settings")
        if tapRow("Supply & refills") {
            sleep(1)
            snap("10-paywall-from-supply-row")
            note("supply-row-paywall", "Paywall close button present: \(app.buttons["Close"].exists)")
        }
    }

    // MARK: - Free surfaces: what do I get without paying

    func testFreeWeeklyValueTour() {
        launch(seed: true)
        snap("20-home-free-weekly")
        dump("home-free")
        tab("History")
        snap("21-history-free")
        tab("Patterns")
        snap("22-patterns-free-top")
        dump("patterns-free")
        app.swipeUp()
        snap("23-patterns-free-scrolled")
        measure("patterns-see-plans", app.buttons["See Plans"])
        if app.buttons["See Plans"].exists {
            app.buttons["See Plans"].tap()
            sleep(2)
            snap("24-paywall-from-patterns")
        }
    }

    func testFreePillHomePromo() {
        launch(seed: true, pill: true)
        snap("30-pill-home-free")
        dump("pill-home-free")
        app.swipeUp()
        snap("31-pill-home-scrolled-promo")
        let upgrade = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'lock screen' OR label CONTAINS[c] 'pro' OR label CONTAINS[c] 'upgrade'")).firstMatch
        measure("pill-upgrade-promo", upgrade)
        if upgrade.exists {
            upgrade.tap()
            sleep(2)
            snap("32-paywall-from-pill-home")
        }
    }

    // MARK: - Accessibility size: does the paywall's single viewport keep CTA and exit reachable

    func testPaywallAccessibilityXL() {
        launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"])
        tab("Settings")
        app.swipeUp()
        if app.buttons["Upgrade to Pro"].exists {
            app.buttons["Upgrade to Pro"].tap()
            sleep(2)
            snap("40-paywall-xl")
            dump("paywall-xl")
            measure("xl-close", app.buttons["Close"])
            measure("xl-primary", app.buttons["Try Again"])
            measure("xl-restore", app.buttons["Restore Purchases"])
            measure("xl-privacy", app.links["Privacy Policy"])
        } else {
            snap("40-settings-xl-no-upgrade-row")
        }
    }

    // MARK: - Paid user: confirm, manage, cancel

    func testProUserSettingsAndExit() {
        launch(pro: true)
        tab("Settings")
        app.swipeUp()
        snap("50-settings-pro")
        dump("settings-pro")
        note("pro-status-row", "Rows mentioning plan/renew/manage: \(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'renew' OR label CONTAINS[c] 'manage' OR label CONTAINS[c] 'active' OR label CONTAINS[c] 'member'")).count + app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'renew' OR label CONTAINS[c] 'manage' OR label CONTAINS[c] 'subscription'")).count)")
        measure("pro-alerts-row", app.buttons["Proactive alerts"])
        measure("pro-restore-row", app.buttons["Restore purchases"])
        if app.buttons["Restore purchases"].exists {
            app.buttons["Restore purchases"].tap()
            sleep(2)
            snap("51-pro-restore-tapped")
        }
        if app.buttons["Proactive alerts"].exists {
            app.buttons["Proactive alerts"].tap()
            sleep(2)
            snap("52-pro-alerts-sheet")
            dump("pro-alerts")
        }
    }

    // MARK: - Debug harness renders of the sheets (no plans in sim, layout only)

    func testTrialSheetHarness() {
        launch(extra: ["-PaywallSnapshot", "trial"])
        sleep(2)
        snap("60-trial-sheet-harness")
        dump("trial-sheet")
        measure("trial-not-now", app.buttons["Not now"])
        measure("trial-restore", app.buttons["Restore Purchases"])
    }

    func testYearlyPaywallHarness() {
        launch(extra: ["-PaywallSnapshot", "yearly"])
        sleep(2)
        snap("61-paywall-harness-yearly")
        dump("paywall-harness")
    }
}
