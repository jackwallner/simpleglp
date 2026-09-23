import AppIntents
import Foundation
import WidgetKit

struct LogShotIntent: AppIntent {
    static let title: LocalizedStringResource = "Log dose"
    static let description = IntentDescription("Log your GLP-1 shot or pill instantly.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        let timestamp = Date()
        let pending = PendingWidgetShot(timestamp: timestamp)
        GLPAppGroup.enqueueWidgetShot(pending)

        let defaults = GLPAppGroup.userDefaults
        defaults.set(timestamp, forKey: GLPStorageKey.widgetLastLoggedAt.rawValue)
        RecentShotsStore.record(RecentShot(id: pending.id, timestamp: timestamp))
        // Start the pill countdown on the widget now; the app confirms it on ingest.
        var glance = GLPGlanceStore.load()
        glance.lastDoseAt = timestamp
        GLPGlanceStore.save(glance)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
