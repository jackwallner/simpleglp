import Foundation

struct PendingWidgetShot: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date

    init(id: UUID = UUID(), timestamp: Date) {
        self.id = id
        self.timestamp = timestamp
    }
}

enum GLPAppGroup {
    static let identifier = "group.com.jackwallner.glp"

    nonisolated(unsafe) static let userDefaults: UserDefaults = UserDefaults(suiteName: identifier) ?? .standard

    private static let pendingWidgetShotsKey = "glpPendingWidgetShots"
    private static let legacyPendingTimestampKey = "pendingWidgetShotTimestamp"
    private static let legacyPendingIDKey = "pendingWidgetShotID"
    private static let legacyPendingMessageKey = "pendingWidgetShotMessage"

    static func pendingWidgetShots() -> [PendingWidgetShot] {
        var shots = decodePendingWidgetShots()
        let defaults = userDefaults
        let legacyTimestamp = defaults.double(forKey: legacyPendingTimestampKey)
        guard legacyTimestamp > 0 else { return shots.sorted { $0.timestamp < $1.timestamp } }

        let legacyID = defaults.string(forKey: legacyPendingIDKey).flatMap(UUID.init) ?? UUID()
        if !shots.contains(where: { $0.id == legacyID }) {
            shots.append(PendingWidgetShot(id: legacyID, timestamp: Date(timeIntervalSince1970: legacyTimestamp)))
            savePendingWidgetShots(shots)
        }
        defaults.removeObject(forKey: legacyPendingTimestampKey)
        defaults.removeObject(forKey: legacyPendingIDKey)
        defaults.removeObject(forKey: legacyPendingMessageKey)
        return shots.sorted { $0.timestamp < $1.timestamp }
    }

    static func enqueueWidgetShot(_ shot: PendingWidgetShot) {
        var shots = pendingWidgetShots()
        guard !shots.contains(where: { $0.id == shot.id }) else { return }
        shots.append(shot)
        savePendingWidgetShots(shots)
    }

    static func acknowledgeWidgetShot(id: UUID) {
        savePendingWidgetShots(pendingWidgetShots().filter { $0.id != id })
    }

    private static func decodePendingWidgetShots() -> [PendingWidgetShot] {
        guard let data = userDefaults.data(forKey: pendingWidgetShotsKey) else { return [] }
        return (try? JSONDecoder().decode([PendingWidgetShot].self, from: data)) ?? []
    }

    private static func savePendingWidgetShots(_ shots: [PendingWidgetShot]) {
        guard let data = try? JSONEncoder().encode(shots.sorted { $0.timestamp < $1.timestamp }) else { return }
        userDefaults.set(data, forKey: pendingWidgetShotsKey)
    }
}

enum GLPStorageKey: String {
    case hasCompletedOnboarding = "glpHasCompletedOnboarding"
    case hasSeenFirstRunOffer = "glpHasSeenFirstRunOffer"
    case hasSeenTrialOffer = "glpHasSeenTrialOffer"
    case hasSeenPatternsTrialOffer = "glpHasSeenPatternsTrialOffer"
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
    case healthContextEnabled = "glpHealthContextEnabled"
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

    static var healthContextEnabled: Bool {
        get {
            GLPAppGroup.userDefaults.object(forKey: GLPStorageKey.healthContextEnabled.rawValue) as? Bool ?? true
        }
        set { GLPAppGroup.userDefaults.set(newValue, forKey: GLPStorageKey.healthContextEnabled.rawValue) }
    }
}

enum GLPWidgetQuickLog {
    static let healthMessagePending = "Open the app to capture Health context."
}
