import XCTest
@testable import SimpleGLP

/// An unopenable store is moved aside, never deleted: shot history exists nowhere else.
final class StoreQuarantineTests: XCTestCase {
    func testUnreadableStoreIsMovedAsideNotDeleted() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = dir.appendingPathComponent("SimpleGLP.store")
        let wal = URL(fileURLWithPath: store.path + "-wal")
        try Data("shots".utf8).write(to: store)
        try Data("wal".utf8).write(to: wal)

        let moved = GLPModelStore.quarantineStore(at: store)

        XCTAssertEqual(moved.count, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: wal.path))
        let copy = try XCTUnwrap(moved.first { !$0.lastPathComponent.contains("-wal") })
        XCTAssertTrue(copy.lastPathComponent.hasPrefix("SimpleGLP.store.corrupt-"))
        XCTAssertEqual(try Data(contentsOf: copy), Data("shots".utf8))
    }

    func testMissingStoreQuarantinesNothing() {
        let store = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("SimpleGLP.store")
        XCTAssertTrue(GLPModelStore.quarantineStore(at: store).isEmpty)
    }
}
