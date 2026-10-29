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
    var pillDoneToday: Bool { glance.isPill && glance.takenToday(now: date) }
}
#endif
