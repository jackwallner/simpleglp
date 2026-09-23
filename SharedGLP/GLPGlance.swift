import Foundation

/// What the widget and the Watch need to render the current routine without the database:
/// shot or pill, the medication name, and any wait-before-eating countdown in progress.
/// The phone writes it; the widget reads it from the App Group and the Watch receives it
/// through the application context.
struct GLPGlance: Codable, Equatable, Sendable {
    var isPill: Bool
    var medicationName: String
    var waitMinutes: Int
    var lastDoseAt: Date?

    init(isPill: Bool = false, medicationName: String = "GLP-1", waitMinutes: Int = 0, lastDoseAt: Date? = nil) {
        self.isPill = isPill
        self.medicationName = medicationName
        self.waitMinutes = waitMinutes
        self.lastDoseAt = lastDoseAt
    }

    var noun: String { isPill ? "pill" : "shot" }
    var symbolName: String { isPill ? "pills.fill" : "syringe.fill" }
    var logButtonTitle: String { "I took my \(noun)" }

    /// End of the countdown started by the last dose, while it is still running.
    func waitEndsAt(now: Date = .now) -> Date? {
        guard isPill, waitMinutes > 0, let lastDoseAt else { return nil }
        let end = lastDoseAt.addingTimeInterval(TimeInterval(waitMinutes * 60))
        return end > now && lastDoseAt <= now ? end : nil
    }

    func takenToday(now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let lastDoseAt else { return false }
        return calendar.isDate(lastDoseAt, inSameDayAs: now)
    }
}

enum GLPGlanceStore {
    private static let key = "glpGlance"

    static func load(from defaults: UserDefaults = GLPAppGroup.userDefaults) -> GLPGlance {
        guard let data = defaults.data(forKey: key),
              let glance = try? JSONDecoder().decode(GLPGlance.self, from: data)
        else { return GLPGlance() }
        return glance
    }

    static func save(_ glance: GLPGlance, to defaults: UserDefaults = GLPAppGroup.userDefaults) {
        guard let data = try? JSONEncoder().encode(glance) else { return }
        defaults.set(data, forKey: key)
        defaults.set(glance.isPill, forKey: GLPStorageKey.isPillPlan.rawValue)
    }

    static func encoded(_ glance: GLPGlance) -> Data? {
        try? JSONEncoder().encode(glance)
    }

    static func decode(_ data: Data?) -> GLPGlance? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(GLPGlance.self, from: data)
    }
}
