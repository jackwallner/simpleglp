import Foundation
import WatchConnectivity

@MainActor
final class WatchConnectivityController: NSObject, ObservableObject {
    @Published var statusMessage: String?
    @Published var showConfirmation = false
    @Published var recentShots: [RecentShot] = []
    @Published var glance = GLPGlanceStore.load()
    /// A dose logged here that the phone may not have seen yet.
    private var pendingLocalDoseAt: Date?
    /// Every dose logged here until the phone lists it, sent or not.
    private var outbox = WatchShotOutbox.load()

    private let session = WCSession.default
    private var confirmationTask: Task<Void, Never>?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
        loadCachedRecentShots()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        if session.activationState != .activated {
            session.activate()
        }
        applyContext(session.receivedApplicationContext)
    }

    func requestShotLog() {
        guard !showConfirmation else { return }
        let now = Date()
        triggerConfirmation()
        // Optimistically insert into the local recent shots so the list updates immediately.
        let optimistic = RecentShot(timestamp: now)
        recentShots = RecentShotsStore.record(optimistic)
        glance.lastDoseAt = now
        pendingLocalDoseAt = now
        GLPGlanceStore.save(glance)

        outbox.add(id: optimistic.id, timestamp: now)
        outbox.save()
        guard session.activationState == .activated else {
            // Held in the outbox and sent the moment the session activates.
            statusMessage = String(localized: "Saved on Watch. Open iPhone to sync.")
            return
        }
        flushOutbox()
        statusMessage = session.isReachable
            ? String(localized: "Sent to iPhone.")
            : String(localized: "Saved. It will sync to iPhone.")
    }

    /// transferUserInfo queues and delivers in the background even when the phone
    /// isn't reachable right now, so a shot logged offline still reaches the iPhone.
    fileprivate func flushOutbox() {
        guard session.activationState == .activated else { return }
        for entry in outbox.unsent {
            session.transferUserInfo(WatchShotOutbox.payload(for: entry))
            outbox.markSent(entry.id)
        }
        outbox.save()
    }

    private func triggerConfirmation() {
        confirmationTask?.cancel()
        showConfirmation = true
        confirmationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if !Task.isCancelled { showConfirmation = false }
        }
    }

    private func loadCachedRecentShots() {
        recentShots = RecentShotsStore.load()
    }

    /// nil leaves the list alone; an empty list from the phone clears it.
    fileprivate func applyShots(_ decoded: [RecentShot]?) {
        guard let decoded else { return }
        // The phone's list wins, except for doses logged here it hasn't seen yet.
        let merged = outbox.merge(phone: decoded)
        outbox.save()
        recentShots = RecentShotsStore.replaceAll(merged)
    }

    fileprivate func applyGlance(_ decoded: GLPGlance?) {
        guard let decoded else { return }
        // Keep a dose logged here that the phone hasn't acknowledged yet, but only briefly:
        // after that the phone is the source of truth (it may have been undone there).
        var merged = decoded
        if let pending = pendingLocalDoseAt {
            if pending > (decoded.lastDoseAt ?? .distantPast), Date().timeIntervalSince(pending) < 10 * 60 {
                merged.lastDoseAt = pending
            } else {
                pendingLocalDoseAt = nil
            }
        }
        glance = merged
        GLPGlanceStore.save(merged)
    }

    private func applyContext(_ context: [String: Any]) {
        applyShots(Self.decodeShots(from: context))
        applyGlance(GLPGlanceStore.decode(context["glance"] as? Data))
    }

    nonisolated static func decodeShots(from context: [String: Any]) -> [RecentShot]? {
        RecentShotsSync.shots(fromContext: context)
    }
}

extension WatchConnectivityController: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let shots = Self.decodeShots(from: session.receivedApplicationContext)
        let glance = GLPGlanceStore.decode(session.receivedApplicationContext["glance"] as? Data)
        Task { @MainActor in
            self.flushOutbox()
            self.applyShots(shots)
            self.applyGlance(glance)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let shots = Self.decodeShots(from: applicationContext)
        let glance = GLPGlanceStore.decode(applicationContext["glance"] as? Data)
        Task { @MainActor in
            self.applyShots(shots)
            self.applyGlance(glance)
        }
    }
}
