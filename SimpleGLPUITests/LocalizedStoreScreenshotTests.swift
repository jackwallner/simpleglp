import XCTest

final class LocalizedStoreScreenshotTests: XCTestCase {
    private struct Locale: Decodable {
        let storeLocale: String
        let language: String
        let appleLanguages: String
        let appleLocale: String
    }

    private struct CaptureConfig: Decodable {
        let locales: [Locale]
        let scenes: [String]
    }

    private struct Scene {
        let name: String
        let arguments: [String]
    }

    func testLocalizedStoreScreenshots() throws {
        let url = try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "capture-locales", withExtension: "json")
        )
        let capture = try JSONDecoder().decode(CaptureConfig.self, from: Data(contentsOf: url))
        let availableScenes = [
            Scene(name: "01-know-when-your-next-shot-is-due", arguments: ["-GLPDuoScreen", "oneTap"]),
            Scene(name: "02-log-a-shot-in-one-tap", arguments: ["-GLPDuoScreen", "history"]),
            Scene(name: "03-review-a-recorded-shot", arguments: ["-GLPDuoScreen", "history", "-GLPScreenshotDetails"]),
            Scene(name: "04-see-how-your-timing-holds", arguments: ["-GLPDuoScreen", "patterns", "-GLPScreenshotPro"]),
            Scene(name: "05-set-a-schedule-that-fits", arguments: ["-GLPScreenshotPlan"]),
            Scene(name: "06-confirm-a-completed-shot", arguments: ["-GLPScreenshotConfirmation"]),
            Scene(name: "07-tune-proactive-alerts", arguments: ["-GLPScreenshotAlerts", "-GLPScreenshotPro"]),
        ]
        let requestedScenes = Set(capture.scenes)
        let scenes = availableScenes.filter { requestedScenes.contains($0.name) }
        XCTAssertEqual(scenes.map(\.name), capture.scenes, "Capture config names an unknown or out-of-order scene")
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.glp")
        var didLaunchApp = false

        for locale in capture.locales {
            for scene in scenes {
                if didLaunchApp && app.state != .notRunning {
                    app.terminate()
                }
                app.launchArguments = [
                    "-uitesting",
                    "-AppleLanguages", locale.appleLanguages,
                    "-AppleLocale", locale.appleLocale,
                    "-GLPScreenshotSeed",
                ] + scene.arguments
                app.launch()
                didLaunchApp = true
                XCTAssertTrue(app.wait(for: .runningForeground, timeout: 45), "App did not open for \(locale.storeLocale) \(scene.name)")
                sleep(14)

                let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                attachment.name = "\(locale.storeLocale)__\(scene.name).png"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        app.terminate()
    }
}
