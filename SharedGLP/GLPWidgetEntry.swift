#if os(iOS)
import Foundation
import WidgetKit

struct SimpleGLPWidgetEntry: TimelineEntry {
    let date: Date
    let lastShotDate: Date?
    let recentShots: [RecentShot]
    let showConfirmation: Bool
    var glance = GLPGlance()

    var waitEndsAt: Date? { glance.waitEndsAt(now: date) }
    /// A dose already logged today, pill or shot. The log button stays hidden
    /// so a second tap can't write a second dose.
    var doneToday: Bool { glance.takenToday(now: date) }
}
#endif
