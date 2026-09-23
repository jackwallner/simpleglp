import SwiftUI

struct WatchRootView: View {
    @StateObject private var controller = WatchConnectivityController()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ScrollView {
                VStack(spacing: 14) {
                    if let end = controller.glance.waitEndsAt(now: context.date), let taken = controller.glance.lastDoseAt {
                        WatchWaitView(takenAt: taken, endsAt: end, now: context.date)
                    } else if controller.glance.isPill, controller.glance.takenToday(now: context.date), !controller.showConfirmation {
                        doneToday
                    } else {
                        logButton
                    }

                    if let status = controller.statusMessage, !controller.showConfirmation {
                        Text(status)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if !controller.recentShots.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(controller.glance.isPill ? "Recent pills" : "Last few shots")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ForEach(controller.recentShots) { shot in
                                WatchRecentShotRow(shot: shot)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
    }

    private var logButton: some View {
        Button {
            controller.requestShotLog()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: controller.showConfirmation ? "checkmark.circle.fill" : controller.glance.symbolName)
                    .font(.system(size: 30, weight: .bold))
                Text(controller.showConfirmation ? "Logged" : controller.glance.logButtonTitle)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                (controller.showConfirmation ? AppTheme.brandPressed : AppTheme.brand),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: controller.showConfirmation)
    }

    private var doneToday: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(AppTheme.brand)
            Text("Done for today")
                .font(.headline)
            if let last = controller.glance.lastDoseAt {
                Text("Taken \(last.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// Ring countdown for the wait after a pill.
private struct WatchWaitView: View {
    let takenAt: Date
    let endsAt: Date
    let now: Date

    var body: some View {
        let total = endsAt.timeIntervalSince(takenAt)
        let progress = total > 0 ? min(1, max(0, now.timeIntervalSince(takenAt) / total)) : 1
        ZStack {
            Circle()
                .stroke(AppTheme.brandSoft, lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(AppTheme.brand, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("Wait")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(timerInterval: now...endsAt, countsDown: true)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                Text("until \(endsAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 130, height: 130)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Waiting until \(endsAt.formatted(date: .omitted, time: .shortened)) before food and drink")
    }
}

private struct WatchRecentShotRow: View {
    let shot: RecentShot

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(AppTheme.brand)
            VStack(alignment: .leading, spacing: 1) {
                Text(shot.timestamp, style: .date)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(shot.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
