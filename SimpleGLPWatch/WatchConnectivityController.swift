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
        let now = Date()
        triggerConfirmation()
        // Optimistically insert into the local recent shots so the list updates immediately.
        let optimistic = RecentShot(timestamp: now)
        recentShots = RecentShotsStore.record(optimistic)
        glance.lastDoseAt = now
        pendingLocalDoseAt = now
        GLPGlanceStore.save(glance)

        let payload: [String: Any] = [
            "type": "logShot",
            "timestamp": now.timeIntervalSince1970,
            "id": optimistic.id.uuidString
        ]
        guard session.activationState == .activated else {
            statusMessage = "Saved on Watch. Open iPhone to sync."
            return
        }
        // transferUserInfo queues and delivers in the background even when the phone
        // isn't reachable right now, so a shot logged offline still reaches the iPhone.
        session.transferUserInfo(payload)
        statusMessage = session.isReachable ? "Sent to iPhone." : "Saved — will sync to iPhone."
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

    fileprivate func applyShots(_ decoded: [RecentShot]) {
        guard !decoded.isEmpty else { return }
        recentShots = RecentShotsStore.replaceAll(decoded)
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

    nonisolated static func decodeShots(from context: [String: Any]) -> [RecentShot] {
        guard let raw = context["recentShots"] as? [[String: Any]] else { return [] }
        return raw.compactMap { entry in
            guard let idString = entry["id"] as? String, let id = UUID(uuidString: idString),
                  let ts = entry["timestamp"] as? TimeInterval else { return nil }
            return RecentShot(
                id: id,
                timestamp: Date(timeIntervalSince1970: ts),
                scheduleStatusRaw: entry["scheduleStatusRaw"] as? String ?? "unknown",
                medicationName: entry["medicationName"] as? String,
                doseMg: entry["doseMg"] as? Double
            )
        }
    }
}

extension WatchConnectivityController: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let shots = Self.decodeShots(from: session.receivedApplicationContext)
        let glance = GLPGlanceStore.decode(session.receivedApplicationContext["glance"] as? Data)
        Task { @MainActor in
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
