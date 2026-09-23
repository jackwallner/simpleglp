import ActivityKit
import Foundation

/// Pro: the wait-before-eating countdown on the Lock Screen and in the Dynamic Island.
/// iOS also mirrors it to the Apple Watch Smart Stack. Started only from the foreground;
/// a pill logged from the Watch while the phone is locked falls back to the notification.
@MainActor
enum LiveActivityService {
    static var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    static func startWait(medicationName: String, takenAt: Date, endsAt: Date) {
        guard endsAt > .now, isAvailable else {
            endAll()
            return
        }
        let attributes = GLPWaitActivityAttributes(medicationName: medicationName)
        let state = GLPWaitActivityAttributes.ContentState(takenAt: takenAt, endsAt: endsAt)
        let started = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: endsAt),
            pushType: nil
        )
        // Only one countdown at a time: retire any earlier one, never the one just started.
        let keepID = started?.id
        Task { await end { activity in activity.id != keepID } }
    }

    static func endAll() {
        Task { await end { _ in true } }
    }

    /// Clears countdowns that already finished, so the Lock Screen doesn't keep a 0:00.
    static func endFinished(now: Date = .now) {
        Task { await end { activity in activity.content.state.endsAt <= now } }
    }

    nonisolated private static func end(where shouldEnd: @Sendable (Activity<GLPWaitActivityAttributes>) -> Bool) async {
        for activity in Activity<GLPWaitActivityAttributes>.activities where shouldEnd(activity) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
