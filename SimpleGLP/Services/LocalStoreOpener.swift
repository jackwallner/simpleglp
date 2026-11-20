import Foundation
import SwiftData
import os

/// What happened when the local store was opened.
enum LocalStoreStatus: Equatable, Sendable {
    /// The real file opened.
    case opened
    /// The real file was empty and a copy an earlier launch set aside was put back.
    case recovered
    /// The file was proven unreadable, so it was set aside (kept, never deleted)
    /// and a fresh one opened.
    case movedAside
    /// The real file could not be opened right now. Nothing was moved. An empty
    /// in-memory stand-in is running and must never be shown as the user's data.
    case unavailable
}

/// Opens a local SwiftData store without ever trading the user's data for an
/// empty file. A failed open is retried; the file is set aside only when the
/// error proves it unreadable, or after several failed launches with the
/// device unlocked; a set-aside copy is put back when the open store is empty.
struct LocalStoreOpener {
    var url: URL
    var open: (URL) throws -> ModelContainer
    /// True when the store holds anything the user made.
    var hasUserData: (ModelContainer) -> Bool
    var makeStandIn: () throws -> ModelContainer
    /// True when the device is unlocked, so a failure is not file protection.
    /// A caller that cannot tell (an extension) returns false, and then only a
    /// proven corruption error ever moves the file.
    var protectedDataAvailable: () -> Bool
    var defaults: UserDefaults
    var failureCountKey: String
    var attempts = 3
    var retryDelay: TimeInterval = 0.2
    var launchesBeforeMovingAside = 3
    var fileManager: FileManager = .default
    var logger = Logger(subsystem: "LocalStoreOpener", category: "Store")

    /// `countsAsLaunch` is false for a retry inside the same launch, so tapping
    /// Try Again can never add up to moving the file aside.
    func run(countsAsLaunch: Bool = true) -> (container: ModelContainer, status: LocalStoreStatus) {
        var lastError: Error?
        for attempt in 0..<max(attempts, 1) {
            if attempt > 0 { Thread.sleep(forTimeInterval: retryDelay) }
            do {
                var container: ModelContainer? = try open(url)
                defaults.removeObject(forKey: failureCountKey)
                if let opened = container, hasUserData(opened) { return (opened, .opened) }
                guard let restorable = newestRestorableCopy() else { return (container!, .opened) }
                // Close the empty store before its files move.
                container = nil
                return restore(from: restorable.scratch, copySuffix: restorable.suffix)
            } catch {
                lastError = error
                logger.error("Store open attempt \(attempt + 1) failed: \(String(describing: error), privacy: .public)")
            }
        }
        if let lastError, shouldMoveAside(after: lastError, countsAsLaunch: countsAsLaunch) {
            logger.error("Store is unreadable; setting it aside and opening a fresh one")
            moveAside(url, label: "unopenable")
            defaults.removeObject(forKey: failureCountKey)
            if let fresh = try? open(url) { return (fresh, .movedAside) }
        }
        return (standIn(), .unavailable)
    }

    // MARK: - Deciding

    private func shouldMoveAside(after error: Error, countsAsLaunch: Bool) -> Bool {
        if Self.isCorrupt(error) { return true }
        guard countsAsLaunch, protectedDataAvailable() else { return false }
        let failures = defaults.integer(forKey: failureCountKey) + 1
        defaults.set(failures, forKey: failureCountKey)
        return failures >= launchesBeforeMovingAside
    }

    /// SQLite corrupt (11) or not-a-database (26), or a file Foundation calls
    /// corrupt. Busy, full, locked and model-mismatch errors prove nothing.
    static func isCorrupt(_ error: Error) -> Bool {
        var queue: [NSError] = [error as NSError]
        var seen = 0
        while let next = queue.popLast(), seen < 32 {
            seen += 1
            if next.domain == "NSSQLiteErrorDomain", [11, 26].contains(next.code & 0xff) { return true }
            if next.domain == NSCocoaErrorDomain, next.code == NSFileReadCorruptFileError { return true }
            if let underlying = next.userInfo[NSUnderlyingErrorKey] as? NSError { queue.append(underlying) }
            if let detailed = next.userInfo["NSDetailedErrors"] as? [NSError] { queue.append(contentsOf: detailed) }
        }
        return false
    }

    // MARK: - Restoring a set-aside copy

    private func restore(from restorable: URL, copySuffix: String) -> (container: ModelContainer, status: LocalStoreStatus) {
        defer { try? fileManager.removeItem(at: restorable.deletingLastPathComponent()) }
        let emptySet = moveAside(url, label: "empty")
        do {
            for extra in ["", "-wal", "-shm"] {
                let from = URL(fileURLWithPath: restorable.path + extra)
                guard fileManager.fileExists(atPath: from.path) else { continue }
                try fileManager.copyItem(at: from, to: URL(fileURLWithPath: url.path + extra))
            }
            let restored = try open(url)
            markUsed(copySuffix)
            logger.notice("Restored the local store from a set-aside copy")
            return (restored, .recovered)
        } catch {
            logger.error("Restoring a set-aside copy failed: \(String(describing: error), privacy: .public)")
            for extra in ["", "-wal", "-shm"] {
                try? fileManager.removeItem(at: URL(fileURLWithPath: url.path + extra))
            }
            for (original, moved) in emptySet { try? fileManager.moveItem(at: moved, to: original) }
            if let reopened = try? open(url) { return (reopened, .opened) }
            return (standIn(), .unavailable)
        }
    }

    /// The newest copy an earlier launch set aside that opens and holds user
    /// data, assembled in a scratch folder so the copies themselves are never
    /// touched. Returns the scratch store's URL and the copy's file suffix.
    private func newestRestorableCopy() -> (scratch: URL, suffix: String)? {
        let folder = url.deletingLastPathComponent()
        let base = url.lastPathComponent
        guard let names = try? fileManager.contentsOfDirectory(atPath: folder.path) else { return nil }
        let suffixes = names.compactMap { name -> String? in
            guard name.hasPrefix(base + ".corrupt-") || name.hasPrefix(base + ".unopenable-") else { return nil }
            return String(name.dropFirst(base.count))
        }
        let newestFirst = suffixes.sorted { modified(base + $0, in: folder) > modified(base + $1, in: folder) }
        for suffix in newestFirst.prefix(5) {
            let scratch = fileManager.temporaryDirectory
                .appendingPathComponent("store-restore-\(UUID().uuidString)", isDirectory: true)
            let candidate = scratch.appendingPathComponent(base)
            do {
                try fileManager.createDirectory(at: scratch, withIntermediateDirectories: true)
                for extra in ["", "-wal", "-shm"] {
                    let from = folder.appendingPathComponent(base + extra + suffix)
                    guard fileManager.fileExists(atPath: from.path) else { continue }
                    try fileManager.copyItem(at: from, to: URL(fileURLWithPath: candidate.path + extra))
                }
                let holdsData: Bool = try {
                    let probe = try open(candidate)
                    return hasUserData(probe)
                }()
                if holdsData { return (candidate, suffix) }
            } catch {
                logger.error("Set-aside copy \(suffix, privacy: .public) does not open: \(String(describing: error), privacy: .public)")
            }
            try? fileManager.removeItem(at: scratch)
        }
        return nil
    }

    /// A copy that was put back is renamed so a later empty store never
    /// brings it back a second time.
    private func markUsed(_ suffix: String) {
        let folder = url.deletingLastPathComponent()
        let base = url.lastPathComponent
        let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
        for extra in ["", "-wal", "-shm"] {
            let from = folder.appendingPathComponent(base + extra + suffix)
            guard fileManager.fileExists(atPath: from.path) else { continue }
            try? fileManager.moveItem(at: from, to: folder.appendingPathComponent(base + extra + ".restored-\(stamp)"))
        }
    }

    private func modified(_ name: String, in folder: URL) -> Date {
        let attributes = try? fileManager.attributesOfItem(atPath: folder.appendingPathComponent(name).path)
        return attributes?[.modificationDate] as? Date ?? .distantPast
    }

    // MARK: - Moving files

    /// Renames the store and its SQLite sidecars to `<name>.<label>-<stamp>`.
    /// Never deletes. Returns the new names.
    @discardableResult
    private func moveAside(_ store: URL, label: String) -> [(original: URL, moved: URL)] {
        let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
        let suffix = ".\(label)-\(stamp)-\(UUID().uuidString.prefix(8))"
        var moved: [(original: URL, moved: URL)] = []
        for extra in ["", "-wal", "-shm"] {
            let file = URL(fileURLWithPath: store.path + extra)
            guard fileManager.fileExists(atPath: file.path) else { continue }
            let destination = URL(fileURLWithPath: file.path + suffix)
            if (try? fileManager.moveItem(at: file, to: destination)) != nil { moved.append((file, destination)) }
        }
        return moved
    }

    private func standIn() -> ModelContainer {
        do {
            return try makeStandIn()
        } catch {
            fatalError("In-memory store could not open: \(error)")
        }
    }
}
