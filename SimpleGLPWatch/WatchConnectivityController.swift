import Foundation
import WatchConnectivity

@MainActor
final class WatchConnectivityController: NSObject, ObservableObject {
    @Published var statusMessage: String?
    @Published var showConfirmation = false
    @Published var recentShots: [RecentShot] = []

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
        applyShots(Self.decodeShots(from: session.receivedApplicationContext))
    }

    func requestShotLog() {
        let now = Date()
        triggerConfirmation()
        // Optimistically insert into the local recent shots so the list updates immediately.
        let optimistic = RecentShot(timestamp: now)
        recentShots = RecentShotsStore.record(optimistic)

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
        Task { @MainActor in
            self.applyShots(shots)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let shots = Self.decodeShots(from: applicationContext)
        Task { @MainActor in
            self.applyShots(shots)
        }
    }
}
