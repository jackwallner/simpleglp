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
}

extension PhoneWatchSession: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        if type == "logShot", let timestamp = message["timestamp"] as? TimeInterval {
            Task { @MainActor in
                PhoneWatchSession.shared.onWatchRequestedCapture?(Date(timeIntervalSince1970: timestamp))
            }
        }
    }
}
