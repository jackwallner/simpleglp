import Foundation

/// Doses logged on the Watch that the iPhone has not shown back yet. A tap
/// before the session activates is held here and sent on activation, and the
/// phone's recent list never wipes a dose it hasn't seen.
struct WatchShotOutbox: Codable, Equatable, Sendable {
    struct Entry: Codable, Equatable, Sendable {
        var id: UUID
        var timestamp: Date
        /// Handed to `transferUserInfo`, which delivers it from then on.
        var sent: Bool
    }

    var entries: [Entry] = []

    /// A sent dose the phone never lists (undone there, or merged into another
    /// tap) stops being protected after this long.
    static let sentLifetime: TimeInterval = 24 * 3600
    /// The phone dedupes taps this close together into one dose.
    static let matchWindow: TimeInterval = 120

    mutating func add(id: UUID, timestamp: Date) {
        guard !entries.contains(where: { $0.id == id }) else { return }
        entries.append(Entry(id: id, timestamp: timestamp, sent: false))
    }

    var unsent: [Entry] { entries.filter { !$0.sent } }

    mutating func markSent(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].sent = true
    }

    /// The phone's list, plus every dose logged here that it does not show
    /// yet. Entries the phone now lists, and sent ones past their lifetime,
    /// leave the outbox.
    mutating func merge(phone shots: [RecentShot], now: Date = .now) -> [RecentShot] {
        entries.removeAll { entry in
            Self.phoneShows(entry, in: shots) || (entry.sent && now.timeIntervalSince(entry.timestamp) > Self.sentLifetime)
        }
        let pending = entries.map { RecentShot(id: $0.id, timestamp: $0.timestamp) }
        return (shots + pending).sorted { $0.timestamp > $1.timestamp }
    }

    static func phoneShows(_ entry: Entry, in shots: [RecentShot]) -> Bool {
        shots.contains { $0.id == entry.id || abs($0.timestamp.timeIntervalSince(entry.timestamp)) < matchWindow }
    }

    static func payload(for entry: Entry) -> [String: Any] {
        ["type": "logShot", "timestamp": entry.timestamp.timeIntervalSince1970, "id": entry.id.uuidString]
    }

    // MARK: - Storage

    private static let key = "glpWatchShotOutbox"

    static func load(from defaults: UserDefaults = .standard) -> WatchShotOutbox {
        guard let data = defaults.data(forKey: key),
              let outbox = try? JSONDecoder().decode(WatchShotOutbox.self, from: data) else { return WatchShotOutbox() }
        return outbox
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
