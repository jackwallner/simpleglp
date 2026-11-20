import SwiftData
import XCTest
@testable import SimpleGLP

/// A failed open must never trade the dose history for an empty file. These
/// run the real opener on real SwiftData files in a scratch folder, with the
/// open itself made to fail the way a locked phone, a full disk or a corrupt
/// file would.
final class StoreQuarantineTests: XCTestCase {
    private final class Calls: @unchecked Sendable { var count = 0 }

    private func scratchStore() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("store-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir.appendingPathComponent("SimpleGLP.store")
    }

    private func writeShot(at url: URL) throws {
        let container = try GLPModelStore.makeContainer(url: url)
        let context = ModelContext(container)
        context.insert(ShotEvent(timestamp: Date(timeIntervalSince1970: 1_700_000_000), doseMg: 2.5))
        try context.save()
    }

    private func opener(
        _ url: URL,
        unlocked: Bool = false,
        failFirst: Int = 0,
        error: Error = CocoaError(.fileReadNoPermission)
    ) -> LocalStoreOpener {
        let calls = Calls()
        var opener = GLPModelStore.storeOpener(url: url, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        opener.retryDelay = 0
        opener.protectedDataAvailable = { unlocked }
        opener.open = { target in
            calls.count += 1
            if calls.count <= failFirst { throw error }
            return try GLPModelStore.makeContainer(url: target)
        }
        return opener
    }

    private func setAside(in folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path)
            .filter { $0.contains(".unopenable-") || $0.contains(".corrupt-") }
    }

    func testATransientFailureIsRetriedAndNothingMoves() throws {
        let url = try scratchStore()
        try writeShot(at: url)
        let result = opener(url, unlocked: true, failFirst: 2).run()
        XCTAssertEqual(result.status, .opened)
        XCTAssertTrue(GLPModelStore.hasUserData(in: result.container))
        XCTAssertTrue(try setAside(in: url.deletingLastPathComponent()).isEmpty)
    }

    /// A widget or Siri log before first unlock used to move the history aside.
    func testALockedPhoneNeverMovesTheFileAndNeverShowsAnEmptyStore() throws {
        let url = try scratchStore()
        try writeShot(at: url)
        let failing = opener(url, unlocked: false, failFirst: .max)
        for _ in 0..<5 {
            XCTAssertEqual(failing.run().status, .unavailable)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(try setAside(in: url.deletingLastPathComponent()).isEmpty)
    }

    func testAnUnlockedFailureMovesTheFileOnlyAfterThreeLaunches() throws {
        let url = try scratchStore()
        try writeShot(at: url)
        var failing = GLPModelStore.storeOpener(url: url, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        failing.retryDelay = 0
        failing.protectedDataAvailable = { true }
        failing.open = { _ in throw CocoaError(.fileWriteOutOfSpace) }
        XCTAssertEqual(failing.run().status, .unavailable)
        XCTAssertEqual(failing.run().status, .unavailable)
        for _ in 0..<5 { XCTAssertEqual(failing.run(countsAsLaunch: false).status, .unavailable) }
        XCTAssertTrue(try setAside(in: url.deletingLastPathComponent()).isEmpty)
        XCTAssertEqual(failing.run().status, .unavailable)
        XCTAssertFalse(try setAside(in: url.deletingLastPathComponent()).isEmpty, "the third launch sets the file aside")
    }

    func testAProvenCorruptFileIsSetAsideAtOnceAndKept() throws {
        let url = try scratchStore()
        try writeShot(at: url)
        let corrupt = NSError(domain: NSCocoaErrorDomain, code: 259, userInfo: [
            NSUnderlyingErrorKey: NSError(domain: "NSSQLiteErrorDomain", code: 11)
        ])
        let result = opener(url, failFirst: 3, error: corrupt).run()
        XCTAssertEqual(result.status, .movedAside)
        XCTAssertFalse(GLPModelStore.hasUserData(in: result.container))
        XCTAssertTrue(try setAside(in: url.deletingLastPathComponent()).contains { $0.hasPrefix("SimpleGLP.store.unopenable-") })
    }

    func testBusyAndFullErrorsAreNotCorruption() {
        XCTAssertFalse(LocalStoreOpener.isCorrupt(NSError(domain: "NSSQLiteErrorDomain", code: 5)))
        XCTAssertFalse(LocalStoreOpener.isCorrupt(NSError(domain: "NSSQLiteErrorDomain", code: 13)))
        XCTAssertFalse(LocalStoreOpener.isCorrupt(CocoaError(.fileReadNoPermission)))
        XCTAssertTrue(LocalStoreOpener.isCorrupt(NSError(domain: "NSSQLiteErrorDomain", code: 26)))
    }

    /// Earlier builds moved the store aside on any failure and opened an empty
    /// one. That copy is put back the first time the open store is empty.
    func testAnEmptyStoreGetsTheSetAsideCopyBackOnce() throws {
        let url = try scratchStore()
        try writeShot(at: url)
        let folder = url.deletingLastPathComponent()
        let suffix = ".corrupt-\(UUID().uuidString)"
        for extra in ["", "-wal", "-shm"] {
            let file = URL(fileURLWithPath: url.path + extra)
            guard FileManager.default.fileExists(atPath: file.path) else { continue }
            try FileManager.default.moveItem(at: file, to: URL(fileURLWithPath: file.path + suffix))
        }
        _ = try GLPModelStore.makeContainer(url: url)

        let result = opener(url).run()
        XCTAssertEqual(result.status, .recovered)
        XCTAssertTrue(GLPModelStore.hasUserData(in: result.container))
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        XCTAssertFalse(names.contains { $0.contains(".corrupt-") }, "a copy that was put back is not offered again")
    }

    func testAStoreWithDataIsNeverReplacedByACopy() throws {
        let url = try scratchStore()
        try writeShot(at: url)
        let stale = try scratchStore()
        try writeShot(at: stale)
        try FileManager.default.copyItem(at: stale, to: URL(fileURLWithPath: url.path + ".corrupt-OLD"))
        XCTAssertEqual(opener(url).run().status, .opened)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path + ".corrupt-OLD"))
    }
}
