import SwiftUI
import WidgetKit

struct SimpleGLPWidgetEntry: TimelineEntry {
    let date: Date
    let lastShotDate: Date?
    let recentShots: [RecentShot]
    let showConfirmation: Bool
    var glance = GLPGlance()

    var waitEndsAt: Date? { glance.waitEndsAt(now: date) }
    /// A daily pill already logged today: the button would only create a duplicate.
    var pillDoneToday: Bool { glance.isPill && glance.takenToday(now: date) }
}

struct SimpleGLPWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleGLPWidgetEntry {
        SimpleGLPWidgetEntry(date: .now, lastShotDate: nil, recentShots: [], showConfirmation: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleGLPWidgetEntry) -> Void) {
        completion(makeEntry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleGLPWidgetEntry>) -> Void) {
        let now = Date()
        let entry = makeEntry(at: now)
        var entries = [entry]
        if entry.showConfirmation {
            // Flip out of confirmation a couple seconds later.
            entries.append(entry.at(now.addingTimeInterval(3)))
        }
        // Flip from countdown to "done" when the wait ends, and back to the button at midnight.
        if let end = entry.waitEndsAt {
            entries.append(entry.at(end))
        }
        if entry.glance.isPill, let midnight = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) {
            entries.append(entry.at(midnight))
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60))))
    }

    private func makeEntry(at date: Date) -> SimpleGLPWidgetEntry {
        let defaults = GLPAppGroup.userDefaults
        let last = defaults.object(forKey: GLPStorageKey.widgetLastLoggedAt.rawValue) as? Date
        let shots = RecentShotsStore.load()
        let recentlyLogged = last.map { date.timeIntervalSince($0) < 3 } ?? false
        return SimpleGLPWidgetEntry(
            date: date,
            lastShotDate: last,
            recentShots: shots,
            showConfirmation: recentlyLogged,
            glance: GLPGlanceStore.load()
        )
    }
}

private extension SimpleGLPWidgetEntry {
    func at(_ date: Date) -> SimpleGLPWidgetEntry {
        SimpleGLPWidgetEntry(date: date, lastShotDate: lastShotDate, recentShots: recentShots, showConfirmation: false, glance: glance)
    }
}

struct SimpleGLPWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: SimpleGLPWidgetProvider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            smallBody
        default:
            mediumBody
        }
    }

    @ViewBuilder
    private var smallBody: some View {
        if let end = entry.waitEndsAt {
            waitBody(end: end)
                .containerBackground(AppTheme.bg, for: .widget)
        } else if entry.pillDoneToday {
            doneBody
                .containerBackground(AppTheme.bg, for: .widget)
        } else {
            smallButton
        }
    }

    private func waitBody(end: Date) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "pills.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.brand)
            Text(timerInterval: entry.date...end, countsDown: true)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.text)
            Text("until \(end.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var doneBody: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(AppTheme.brand)
            Text("Done for today")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.text)
                .multilineTextAlignment(.center)
            if let last = entry.glance.lastDoseAt {
                Text(last.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var smallButton: some View {
        Button(intent: LogShotIntent()) {
            VStack(spacing: 8) {
                Image(systemName: entry.showConfirmation ? "checkmark.circle.fill" : entry.glance.symbolName)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                Text(entry.showConfirmation ? "Logged" : entry.glance.logButtonTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                if let last = entry.lastShotDate, !entry.showConfirmation {
                    Text(last, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(10)
        }
        .buttonStyle(.plain)
        .containerBackground(for: .widget) {
            (entry.showConfirmation ? AppTheme.brandPressed : AppTheme.brand)
        }
    }

    @ViewBuilder
    private var mediumLeading: some View {
        if let end = entry.waitEndsAt {
            waitBody(end: end)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else if entry.pillDoneToday {
            doneBody
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            Button(intent: LogShotIntent()) {
                VStack(spacing: 6) {
                    Image(systemName: entry.showConfirmation ? "checkmark.circle.fill" : entry.glance.symbolName)
                        .font(.system(size: 28, weight: .bold))
                    Text(entry.showConfirmation ? "Logged" : entry.glance.logButtonTitle)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(12)
                .background(
                    (entry.showConfirmation ? AppTheme.brandPressed : AppTheme.brand),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var mediumBody: some View {
        HStack(alignment: .top, spacing: 12) {
            mediumLeading
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.glance.isPill ? "Recent pills" : "Last few shots")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
                if entry.recentShots.isEmpty {
                    Text("Nothing yet")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                } else {
                    ForEach(entry.recentShots.prefix(3)) { shot in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(AppTheme.brand)
                            Text(shot.timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
                                .font(.caption2)
                                .foregroundStyle(AppTheme.text)
                            Spacer(minLength: 0)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .containerBackground(AppTheme.bg, for: .widget)
    }
}

@main
struct SimpleGLPWidgets: WidgetBundle {
    var body: some Widget {
        SimpleGLPWidget()
        WaitLiveActivity()
    }
}

struct SimpleGLPWidget: Widget {
    let kind: String = "SimpleGLPWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SimpleGLPWidgetProvider()) { entry in
            SimpleGLPWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Simple GLP")
        .description("One tap to log your dose, plus your pill countdown.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
