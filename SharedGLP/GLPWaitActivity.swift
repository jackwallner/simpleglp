#if os(iOS)
import ActivityKit
import Foundation

/// Lock Screen / Dynamic Island countdown for the wait after a pill. Compiled into the app
/// (which starts and ends it) and the widget extension (which draws it).
struct GLPWaitActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var takenAt: Date
        var endsAt: Date
    }

    var medicationName: String
}
#endif
