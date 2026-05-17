import Foundation

struct RecentShot: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var timestamp: Date
    var scheduleStatusRaw: String
    var medicationName: String?
    var doseMg: Double?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        scheduleStatusRaw: String = "unknown",
        medicationName: String? = nil,
        doseMg: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.scheduleStatusRaw = scheduleStatusRaw
        self.medicationName = medicationName
        self.doseMg = doseMg
    }
}

enum RecentShotsStore {
    static let maxEntries = 5
    private static let key = "glpRecentShots"

    static func load(from defaults: UserDefaults = GLPAppGroup.userDefaults) -> [RecentShot] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([RecentShot].self, from: data)) ?? []
    }

    static func save(_ shots: [RecentShot], to defaults: UserDefaults = GLPAppGroup.userDefaults) {
        let trimmed = Array(shots.sorted { $0.timestamp > $1.timestamp }.prefix(maxEntries))
        if let data = try? JSONEncoder().encode(trimmed) {
            defaults.set(data, forKey: key)
        }
    }

    @discardableResult
    static func record(_ shot: RecentShot, in defaults: UserDefaults = GLPAppGroup.userDefaults) -> [RecentShot] {
        var current = load(from: defaults)
        current.removeAll { $0.id == shot.id }
        current.insert(shot, at: 0)
        save(current, to: defaults)
        return load(from: defaults)
    }

    @discardableResult
    static func remove(id: UUID, in defaults: UserDefaults = GLPAppGroup.userDefaults) -> [RecentShot] {
        var current = load(from: defaults)
        current.removeAll { $0.id == id }
        save(current, to: defaults)
        return current
    }

    @discardableResult
    static func replaceAll(_ shots: [RecentShot], in defaults: UserDefaults = GLPAppGroup.userDefaults) -> [RecentShot] {
        save(shots, to: defaults)
        return load(from: defaults)
    }
}
