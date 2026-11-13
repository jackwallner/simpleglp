import XCTest

/// Captures the 13-inch iPad App Store scenes for every listing locale in portrait.
/// Run on an iPad: `gh-sim test --device "iPad Pro 13-inch (M5)" --only SimpleGLPUITests/IPadStoreShotsTests`.
/// Attachments are named `<locale>__<scene>.png`.
final class IPadStoreShotsTests: XCTestCase {
    private let scenes: [(name: String, arguments: [String])] = [
        ("01-know-when-your-next-shot-is-due", ["-GLPDuoScreen", "oneTap"]),
        ("02-log-a-shot-in-one-tap", ["-GLPDuoScreen", "history"]),
        ("03-review-a-recorded-shot", ["-GLPDuoScreen", "history", "-GLPScreenshotDetails"]),
        ("04-see-how-your-timing-holds", ["-GLPDuoScreen", "patterns", "-GLPScreenshotPro"]),
        ("05-set-a-schedule-that-fits", ["-GLPScreenshotPlan"]),
        ("06-confirm-a-completed-shot", ["-GLPScreenshotConfirmation"]),
        ("07-tune-proactive-alerts", ["-GLPScreenshotAlerts", "-GLPScreenshotPro"]),
    ]

    private func capture(_ locale: String, language: String, region: String, sceneCount: Int = 7) throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad only")
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.glp")
        XCUIDevice.shared.orientation = .portrait
        for scene in scenes.prefix(sceneCount) {
            if app.state != .notRunning { app.terminate() }
            app.launchArguments = ["-uitesting", "-GLPScreenshotSeed",
                                   "-AppleLanguages", "(\(language))", "-AppleLocale", region] + scene.arguments
            app.launch()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 45), "App did not open for \(scene.name)")
            XCUIDevice.shared.orientation = .portrait
            sleep(10)
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "\(locale)__\(scene.name).png"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app.terminate()
    }

    func testEnUS() throws { try capture("en-US", language: "en", region: "en_US") }
    func testPtBR() throws { try capture("pt-BR", language: "pt-BR", region: "pt_BR") }
    func testDeDE() throws { try capture("de-DE", language: "de", region: "de_DE") }
    func testHu() throws { try capture("hu", language: "hu", region: "hu_HU", sceneCount: 6) }
    func testZhHant() throws { try capture("zh-Hant", language: "zh-Hant", region: "zh_TW") }
    func testTr() throws { try capture("tr", language: "tr", region: "tr_TR") }
    func testEsES() throws { try capture("es-ES", language: "es", region: "es_ES") }
    func testPl() throws { try capture("pl", language: "pl", region: "pl_PL") }
    func testEsMX() throws { try capture("es-MX", language: "es-MX", region: "es_MX") }
    func testFrFR() throws { try capture("fr-FR", language: "fr", region: "fr_FR") }
    func testRu() throws { try capture("ru", language: "ru", region: "ru_RU", sceneCount: 6) }
    func testIt() throws { try capture("it", language: "it", region: "it_IT") }
}
