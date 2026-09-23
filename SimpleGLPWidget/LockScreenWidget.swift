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

/// What the Lock Screen should say right now.
enum LockScreenGlance: Equatable {
    case waiting(until: Date, takenAt: Date)
    case pillTaken(at: Date)
    case pillDue(planned: Date?)
    case shot(next: Date)
    case noPlan

    init(glance: GLPGlance, now: Date) {
        if let end = glance.waitEndsAt(now: now), let taken = glance.lastDoseAt {
            self = .waiting(until: end, takenAt: taken)
        } else if glance.isPill {
            if glance.takenToday(now: now), let taken = glance.lastDoseAt {
                self = .pillTaken(at: taken)
            } else {
                self = .pillDue(planned: glance.upcomingDose(now: now))
            }
        } else if let next = glance.upcomingDose(now: now) {
            self = .shot(next: next)
        } else {
            self = .noPlan
        }
    }
}

struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SimpleGLPWidgetEntry

    private var state: LockScreenGlance { LockScreenGlance(glance: entry.glance, now: entry.date) }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryInline: inline
        default: rectangular
        }
    }

    // MARK: - Rectangular

    private var rectangular: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Label(rectTitle, systemImage: icon)
                    .font(.caption.weight(.semibold))
                    .widgetAccentable()
                Text(rectHeadline)
                    .font(.headline)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                Text(rectDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var rectTitle: String {
        switch state {
        case .waiting: "Wait before eating"
        case .pillTaken: "Pill taken"
        case .pillDue: "Pill not logged"
        case .shot: "Next shot"
        case .noPlan: "Simple GLP"
        }
    }

    private var rectHeadline: String {
        switch state {
        case .waiting(let end, _): "Until \(time(end))"
        case .pillTaken(let at): time(at)
        case .pillDue(let planned): planned.map { "Planned \(time($0))" } ?? "Tap to log"
        case .shot(let next): "\(next.formatted(.dateTime.weekday(.abbreviated))) \(time(next))"
        case .noPlan: "Set up your plan"
        }
    }

    private var rectDetail: String {
        switch state {
        case .waiting(_, let taken): "\(entry.glance.medicationName) at \(time(taken))"
        case .pillTaken: tomorrowDetail
        case .pillDue: entry.glance.medicationName
        case .shot(let next): GLPGlance.dayDistance(to: next, now: entry.date)
        case .noPlan: "Open the app"
        }
    }

    private var tomorrowDetail: String {
        guard let next = entry.glance.upcomingDose(now: entry.date) else { return "Done for today" }
        return "Next tomorrow, \(time(next))"
    }

    // MARK: - Circular

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: icon)
                    .font(.system(size: circularText == nil ? 22 : 14, weight: .semibold))
                    .widgetAccentable()
                if let circularText {
                    Text(circularText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            .padding(4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rectTitle), \(rectHeadline)")
    }

    private var circularText: String? {
        switch state {
        case .waiting(let end, _): shortTime(end)
        case .pillTaken: nil
        case .pillDue(let planned): planned.map(shortTime)
        case .shot(let next): shortDays(to: next)
        case .noPlan: nil
        }
    }

    // MARK: - Inline

    private var inline: some View {
        Label(inlineText, systemImage: icon)
    }

    private var inlineText: String {
        switch state {
        case .waiting(let end, _): "Wait until \(time(end))"
        case .pillTaken(let at): "Pill taken \(time(at))"
        case .pillDue(let planned): planned.map { "Pill planned \(time($0))" } ?? "Pill not logged"
        case .shot(let next): "Shot \(GLPGlance.dayDistance(to: next, now: entry.date).lowercased())"
        case .noPlan: "Simple GLP"
        }
    }

    // MARK: - Helpers

    private var icon: String {
        switch state {
        case .waiting: "hourglass"
        case .pillTaken: "checkmark.circle.fill"
        case .pillDue: "pills.fill"
        case .shot: "syringe.fill"
        case .noPlan: "cross.case.fill"
        }
    }

    private func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "7:32" without the AM/PM, for the tiny circular face.
    private func shortTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
    }

    /// "Today", "1d", "3d", "late".
    private func shortDays(to date: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: entry.date), to: calendar.startOfDay(for: date)).day ?? 0
        if days < 0 { return "Late" }
        if days == 0 { return "Today" }
        return "\(days)d"
    }
}
