import Foundation
import Observation
import SwiftData
import os

enum GLPModelStore {
    static let appGroupID = "group.com.jackwallner.glp"

    nonisolated(unsafe) static let schema = Schema([ShotEvent.self, MedicationPlan.self, DoseStep.self])

    /// The open store. Read through `GLPStoreState` so a Try Again that
    /// reaches the real file reaches every screen too.
    static var sharedModelContainer: ModelContainer { GLPStoreState.shared.container }

    /// False while the real file cannot be opened. Nothing may be logged into
    /// the empty stand-in: it would vanish, and the history would look lost.
    static var isAvailable: Bool { GLPStoreState.shared.status != .unavailable }

    /// Opens the store. Shot history exists nowhere else, so a failed open
    /// never trades it for an empty file.
    static func openStore(countsAsLaunch: Bool = true) -> (container: ModelContainer, status: LocalStoreStatus) {
        storeOpener(url: storeURL).run(countsAsLaunch: countsAsLaunch)
    }

    static func storeOpener(url: URL, defaults: UserDefaults = .standard) -> LocalStoreOpener {
        LocalStoreOpener(
            url: url,
            open: { try makeContainer(url: $0) },
            hasUserData: hasUserData(in:),
            makeStandIn: {
                let inMemory = ModelConfiguration("SimpleGLP", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                return try ModelContainer(for: schema, configurations: [inMemory])
            },
            protectedDataAvailable: { GLPStoreState.protectedDataAvailable() },
            defaults: defaults,
            failureCountKey: "storeOpenFailedLaunches",
            logger: Logger(subsystem: "com.jackwallner.glp", category: "GLPModelStore")
        )
    }

    static func makeContainer(url: URL) throws -> ModelContainer {
        let config = ModelConfiguration("SimpleGLP", schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    static func hasUserData(in container: ModelContainer) -> Bool {
        let context = ModelContext(container)
        let shots = (try? context.fetchCount(FetchDescriptor<ShotEvent>())) ?? 0
        let plans = (try? context.fetchCount(FetchDescriptor<MedicationPlan>())) ?? 0
        return shots + plans > 0
    }

    static var storeURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("SimpleGLP.store")
    }
}

/// The store every screen reads, and what happened when it was opened. While
/// the real file cannot be opened, `status` is `.unavailable` and the app
/// shows `StoreUnavailableView` instead of the empty stand-in.
@Observable
final class GLPStoreState: @unchecked Sendable {
    static let shared = GLPStoreState()

    /// Whether the device is unlocked. The app sets this before the store is
    /// first opened; extensions keep the default, so they never count a launch.
    nonisolated(unsafe) static var protectedDataAvailable: () -> Bool = { false }

    private(set) var container: ModelContainer
    private(set) var status: LocalStoreStatus
    /// Set when a launch set the file aside or put a copy back; shown once.
    var notice: LocalStoreStatus?

    private init() {
        let result = GLPModelStore.openStore()
        container = result.container
        status = result.status
        if result.status == .movedAside || result.status == .recovered { notice = result.status }
    }

    /// Tries the real file again. Returns true once it is open.
    @discardableResult
    func retry() -> Bool {
        guard status == .unavailable else { return true }
        let result = GLPModelStore.openStore(countsAsLaunch: false)
        guard result.status != .unavailable else { return false }
        container = result.container
        status = result.status
        if result.status == .movedAside || result.status == .recovered { notice = result.status }
        return true
    }
}
