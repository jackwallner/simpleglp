import SwiftUI
import WidgetKit

/// Lock Screen and StandBy glance: the next shot, today's pill, or when the wait ends.
/// The ticking countdown stays a Pro Live Activity; this shows the end time.
struct SimpleGLPLockScreenWidget: Widget {
    let kind = "SimpleGLPLockScreen"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SimpleGLPWidgetProvider()) { entry in
            LockScreenWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Next dose")
        .description("Your next shot, today’s pill, or when your wait ends.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}
