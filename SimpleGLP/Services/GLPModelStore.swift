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

        let storeFiles = [url, url.appendingPathExtension("wal"), url.appendingPathExtension("shm")]
        for file in storeFiles {
            try? FileManager.default.removeItem(at: file)
        }

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
