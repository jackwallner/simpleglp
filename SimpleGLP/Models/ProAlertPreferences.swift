import Foundation
import SwiftUI

@MainActor
final class ProAlertPreferences: ObservableObject {
    static let shared = ProAlertPreferences()

    @AppStorage(GLPStorageKey.proAlertsEnabled.rawValue, store: GLPAppGroup.userDefaults)
    var alertsEnabled: Bool = false

    @AppStorage(GLPStorageKey.proAlertQuietHoursEnabled.rawValue, store: GLPAppGroup.userDefaults)
    var quietHoursEnabled: Bool = true

    @AppStorage(GLPStorageKey.proAlertQuietStartHour.rawValue, store: GLPAppGroup.userDefaults)
    var quietHoursStart: Int = 22

    @AppStorage(GLPStorageKey.proAlertQuietEndHour.rawValue, store: GLPAppGroup.userDefaults)
    var quietHoursEnd: Int = 7

    @AppStorage(GLPStorageKey.patternAlertsEnabled.rawValue, store: GLPAppGroup.userDefaults)
    var patternAlertsEnabled: Bool = false

    @AppStorage(GLPStorageKey.patternAlertSensitivity.rawValue, store: GLPAppGroup.userDefaults)
    var patternAlertSensitivity: Double = 0.0
}

struct ProAlertPreferenceValues: Sendable {
    var alertsEnabled: Bool
    var quietHoursEnabled: Bool
    var quietHoursStart: Int
    var quietHoursEnd: Int
    var patternAlertsEnabled: Bool
    var patternAlertSensitivity: Double

    static func current() -> ProAlertPreferenceValues {
        let defaults = GLPAppGroup.userDefaults
        return ProAlertPreferenceValues(
            alertsEnabled: defaults.bool(forKey: GLPStorageKey.proAlertsEnabled.rawValue),
            quietHoursEnabled: defaults.object(forKey: GLPStorageKey.proAlertQuietHoursEnabled.rawValue) as? Bool ?? true,
            quietHoursStart: defaults.object(forKey: GLPStorageKey.proAlertQuietStartHour.rawValue) as? Int ?? 22,
            quietHoursEnd: defaults.object(forKey: GLPStorageKey.proAlertQuietEndHour.rawValue) as? Int ?? 7,
            patternAlertsEnabled: defaults.object(forKey: GLPStorageKey.patternAlertsEnabled.rawValue) as? Bool ?? false,
            patternAlertSensitivity: defaults.object(forKey: GLPStorageKey.patternAlertSensitivity.rawValue) as? Double ?? 0.0
        )
    }

    func isQuietHour(at date: Date, calendar: Calendar = .current) -> Bool {
        guard quietHoursEnabled else { return false }
        let hour = calendar.component(.hour, from: date)
        if quietHoursStart == quietHoursEnd { return false }
        if quietHoursStart < quietHoursEnd {
            return hour >= quietHoursStart && hour < quietHoursEnd
        }
        return hour >= quietHoursStart || hour < quietHoursEnd
    }
}
