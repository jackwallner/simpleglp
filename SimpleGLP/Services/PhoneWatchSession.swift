import Foundation
import WatchConnectivity

@MainActor
final class PhoneWatchSession: NSObject, ObservableObject {
    static let shared = PhoneWatchSession()

    var onWatchRequestedCapture: ((Date) -> Void)?

    private override init() {
        super.init()
    }

    func start() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func send(_ message: [String: Any]) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(message, replyHandler: nil) { _ in }
    }

    func syncRecentShots() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let shots = RecentShotsStore.load()
        let payload: [[String: Any]] = shots.map { shot in
            var entry: [String: Any] = [
                "id": shot.id.uuidString,
                "timestamp": shot.timestamp.timeIntervalSince1970,
                "scheduleStatusRaw": shot.scheduleStatusRaw
            ]
            if let medicationName = shot.medicationName { entry["medicationName"] = medicationName }
            if let doseMg = shot.doseMg { entry["doseMg"] = doseMg }
            return entry
        }
        let context: [String: Any] = [
            "recentShots": payload,
            "updatedAt": Date().timeIntervalSince1970
        ]
        do {
            try session.updateApplicationContext(context)
        } catch {
            // Best-effort sync; ignore failures.
        }
    }
}

extension PhoneWatchSession: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncoming(message)
    }

    // Delivered for queued transferUserInfo payloads — the reliable path the watch
    // uses so an offline-logged shot still reaches the phone after reconnection.
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleIncoming(userInfo)
    }

    nonisolated private func handleIncoming(_ payload: [String: Any]) {
        guard let type = payload["type"] as? String, type == "logShot",
              let timestamp = payload["timestamp"] as? TimeInterval else { return }
        Task { @MainActor in
            PhoneWatchSession.shared.onWatchRequestedCapture?(Date(timeIntervalSince1970: timestamp))
        }
    }
}
