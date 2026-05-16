import Foundation

enum GLPAppGroup {
    static let identifier = "group.com.jackwallner.glp"

    nonisolated(unsafe) static let userDefaults: UserDefaults = UserDefaults(suiteName: identifier) ?? .standard
}

enum GLPStorageKey: String {
    case hasCompletedOnboarding = "glpHasCompletedOnboarding"
    case widgetLastLoggedAt = "glpWidgetLastLoggedAt"
    case appearance = "glpAppearance"
    case promptForDetails = "glpPromptForDetails"
    case proAlertsEnabled = "glpProAlertsEnabled"
    case proAlertQuietHoursEnabled = "glpProAlertQuietHoursEnabled"
    case proAlertQuietStartHour = "glpProAlertQuietStartHour"
    case proAlertQuietEndHour = "glpProAlertQuietEndHour"
    case patternAlertsEnabled = "glpPatternAlertsEnabled"
    case patternAlertSensitivity = "glpPatternAlertSensitivity"
    case proAlertLastFiredAt = "glpProAlertLastFiredAt"
    case proAlertLastFiredKind = "glpProAlertLastFiredKind"
}

enum GLPOnboardingStore {
    static var hasCompletedOnboarding: Bool {
        get { GLPAppGroup.userDefaults.bool(forKey: GLPStorageKey.hasCompletedOnboarding.rawValue) }
        set { GLPAppGroup.userDefaults.set(newValue, forKey: GLPStorageKey.hasCompletedOnboarding.rawValue) }
    }

    static var promptForDetails: Bool {
        get { GLPAppGroup.userDefaults.bool(forKey: GLPStorageKey.promptForDetails.rawValue) }
        set { GLPAppGroup.userDefaults.set(newValue, forKey: GLPStorageKey.promptForDetails.rawValue) }
    }
}

enum GLPWidgetQuickLog {
    static let healthMessagePending = "Open the app to capture Health context."
}
