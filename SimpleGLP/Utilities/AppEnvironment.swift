import Foundation

enum AppEnvironment {
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-uitesting")
    }

    static var bypassOnboarding: Bool { isUITesting }
}
