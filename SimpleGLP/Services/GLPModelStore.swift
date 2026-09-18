import Foundation
import SwiftData

enum GLPModelStore {
    static let appGroupID = "group.com.jackwallner.glp"

    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([ShotEvent.self, MedicationPlan.self, DoseStep.self])
        let url = storeURL

        if let container = makeContainer(schema: schema, url: url) {
            return container
        }

        // A failed migration or half-written file can leave the store unopenable.
        // Shot history exists nowhere else, so move it aside instead of deleting it.
        quarantineStore(at: url)

        if let container = makeContainer(schema: schema, url: url) {
            return container
        }

        let inMemory = ModelConfiguration("SimpleGLP", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [inMemory])
        } catch {
            fatalError("GLPModelStore could not initialize: \(error)")
        }
    }()

    /// Renames the store and its SQLite sidecars to `<name>.corrupt-<uuid>` so a
    /// fresh store can open at `url`. Returns the quarantined copies.
    @discardableResult
    static func quarantineStore(at url: URL, fileManager: FileManager = .default) -> [URL] {
        let suffix = ".corrupt-\(UUID().uuidString)"
        let candidates = [
            url,
            URL(fileURLWithPath: url.path + "-wal"),
            URL(fileURLWithPath: url.path + "-shm"),
            url.appendingPathExtension("wal"),
            url.appendingPathExtension("shm")
        ]
        var moved: [URL] = []
        for file in candidates where fileManager.fileExists(atPath: file.path) {
            let destination = URL(fileURLWithPath: file.path + suffix)
            if (try? fileManager.moveItem(at: file, to: destination)) != nil {
                moved.append(destination)
            }
        }
        return moved
    }

    private static func makeContainer(schema: Schema, url: URL) -> ModelContainer? {
        let config = ModelConfiguration(
            "SimpleGLP",
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        return try? ModelContainer(for: schema, configurations: [config])
    }

    private static var storeURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("SimpleGLP.store")
    }
}
