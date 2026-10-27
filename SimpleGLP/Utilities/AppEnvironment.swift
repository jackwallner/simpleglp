import Foundation

enum AppEnvironment {
    static var isUITesting: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-uitesting")
        #else
        return false
        #endif
    }

    static var bypassOnboarding: Bool { isUITesting }
}
