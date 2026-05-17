import AppIntents
import Foundation
import WidgetKit

struct LogShotIntent: AppIntent {
    static let title: LocalizedStringResource = "Log shot"
    static let description = IntentDescription("Log a GLP-1 shot instantly.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        let defaults = GLPAppGroup.userDefaults
        let timestamp = Date()
        defaults.set(timestamp.timeIntervalSince1970, forKey: "pendingWidgetShotTimestamp")
        defaults.set(GLPWidgetQuickLog.healthMessagePending, forKey: "pendingWidgetShotMessage")
        defaults.set(timestamp, forKey: GLPStorageKey.widgetLastLoggedAt.rawValue)
        RecentShotsStore.record(RecentShot(timestamp: timestamp))
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
