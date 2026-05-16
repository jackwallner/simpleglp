import SwiftUI
import WidgetKit

struct SimpleGLPWidgetEntry: TimelineEntry {
    let date: Date
    let lastShotDate: Date?
    let nextShotDate: Date?
}

struct SimpleGLPWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleGLPWidgetEntry {
        SimpleGLPWidgetEntry(date: .now, lastShotDate: nil, nextShotDate: .now.addingTimeInterval(86400 * 3))
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleGLPWidgetEntry) -> Void) {
        let defaults = GLPAppGroup.userDefaults
        let last = defaults.object(forKey: GLPStorageKey.widgetLastLoggedAt.rawValue) as? Date
        completion(SimpleGLPWidgetEntry(date: .now, lastShotDate: last, nextShotDate: nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleGLPWidgetEntry>) -> Void) {
        let defaults = GLPAppGroup.userDefaults
        let last = defaults.object(forKey: GLPStorageKey.widgetLastLoggedAt.rawValue) as? Date
        let entry = SimpleGLPWidgetEntry(date: .now, lastShotDate: last, nextShotDate: nil)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60))))
    }
}

struct SimpleGLPWidgetEntryView: View {
    var entry: SimpleGLPWidgetProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "syringe.fill")
                    .foregroundStyle(AppTheme.brand)
                Spacer()
                if let last = entry.lastShotDate {
                    Text(last, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text("Log shot")
                .font(.headline)
                .foregroundStyle(AppTheme.text)
            Button(intent: LogShotIntent()) {
                Text("Tap to log")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(AppTheme.brand, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .containerBackground(AppTheme.bg, for: .widget)
    }
}

@main
struct SimpleGLPWidget: Widget {
    let kind: String = "SimpleGLPWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SimpleGLPWidgetProvider()) { entry in
            SimpleGLPWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Simple GLP")
        .description("One tap to log your shot.")
        .supportedFamilies([.systemSmall])
    }
}
