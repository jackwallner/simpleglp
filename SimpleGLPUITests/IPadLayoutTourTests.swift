import XCTest

/// Captures every main iPad screen in portrait and landscape for layout review.
/// Run on an iPad destination: `gh-sim test --device "iPad Pro 13-inch (M5)" --only SimpleGLPUITests/IPadLayoutTourTests`.
final class IPadLayoutTourTests: XCTestCase {
    private struct Scene {
        let name: String
        let arguments: [String]
    }

    private let scenes = [
        Scene(name: "home", arguments: ["-GLPDuoScreen", "oneTap"]),
        Scene(name: "history", arguments: ["-GLPDuoScreen", "history"]),
        Scene(name: "patterns", arguments: ["-GLPDuoScreen", "patterns", "-GLPScreenshotPro"]),
        Scene(name: "supply", arguments: ["-GLPDuoScreen", "supply", "-GLPScreenshotPro"]),
        Scene(name: "settings", arguments: ["-GLPDuoScreen", "settings"]),
        Scene(name: "alerts", arguments: ["-GLPScreenshotAlerts", "-GLPScreenshotPro"]),
        Scene(name: "plan", arguments: ["-GLPScreenshotPlan"]),
        Scene(name: "onboarding", arguments: ["-GLPScreenshotOnboarding"]),
        Scene(name: "paywall-yearly", arguments: ["-PaywallSnapshot", "yearly"]),
        Scene(name: "paywall-trial", arguments: ["-PaywallSnapshot", "trial"]),
    ]

    func testIPadLayoutTour() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad only")
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.glp")
        let orientations: [(String, UIDeviceOrientation)] = [
            ("portrait", .portrait),
            ("landscape", .landscapeLeft),
        ]

        for (orientationName, orientation) in orientations {
            for scene in scenes {
                if app.state != .notRunning { app.terminate() }
                XCUIDevice.shared.orientation = orientation
                app.launchArguments = ["-uitesting", "-GLPScreenshotSeed"] + scene.arguments
                app.launch()
                XCTAssertTrue(app.wait(for: .runningForeground, timeout: 45), "App did not open for \(scene.name)")
                XCUIDevice.shared.orientation = orientation
                sleep(12)

                let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                attachment.name = "\(orientationName)__\(scene.name).png"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        XCUIDevice.shared.orientation = .portrait
        app.terminate()
    }
}
