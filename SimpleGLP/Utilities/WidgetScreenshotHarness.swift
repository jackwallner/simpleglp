#if DEBUG
import SwiftUI
import WidgetKit

struct SimpleGLPWidgetScreenshotHarness: View {
    private var entry: SimpleGLPWidgetEntry {
        let now = Date.now
        return SimpleGLPWidgetEntry(
            date: now,
            lastShotDate: now.addingTimeInterval(-8 * 60),
            recentShots: [],
            showConfirmation: false,
            glance: GLPGlance(
                isPill: true,
                medicationName: "Wegovy pill",
                waitMinutes: 30,
                lastDoseAt: now.addingTimeInterval(-8 * 60),
                nextDoseAt: Calendar.current.date(byAdding: .day, value: 1, to: now)
            )
        )
    }

    var body: some View {
        LockScreenWidgetView(entry: entry, familyOverride: .accessoryRectangular)
            .frame(width: 330, height: 100)
            .containerBackground(.clear, for: .widget)
            .padding(24)
            .background(AppTheme.bg.ignoresSafeArea())
    }
}
#endif
