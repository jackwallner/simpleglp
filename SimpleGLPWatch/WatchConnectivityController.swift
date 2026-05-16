import Foundation
import WatchConnectivity

@MainActor
final class WatchConnectivityController: NSObject, ObservableObject {
    @Published var statusMessage: String?

    private let session = WCSession.default

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    func requestShotLog() {
        guard session.isReachable else {
            statusMessage = "iPhone not reachable. Open the app on your phone."
            return
        }
        let message: [String: Any] = [
            "type": "logShot",
            "timestamp": Date().timeIntervalSince1970
        ]
        session.sendMessage(message, replyHandler: nil) { [weak self] _ in
            Task { @MainActor in
                self?.statusMessage = "Sent to iPhone."
            }
        }
    }
}

extension WatchConnectivityController: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
}
