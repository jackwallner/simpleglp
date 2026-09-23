import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen and Dynamic Island countdown for the wait after a pill.
struct WaitLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GLPWaitActivityAttributes.self) { context in
            WaitLockScreenView(context: context)
                .activityBackgroundTint(AppTheme.surface)
                .activitySystemActionForegroundColor(AppTheme.brand)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.medicationName, systemImage: "pills.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.brand)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdownText(state, isStale: context.isStale)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(timerInterval: state.takenAt...state.endsAt, countsDown: false) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .tint(AppTheme.brand)
                        Text(context.isStale ? "Wait's over" : "Wait before food & drink, until \(state.endsAt.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "pills.fill")
                    .foregroundStyle(AppTheme.brand)
            } compactTrailing: {
                countdownText(state, isStale: context.isStale)
                    .monospacedDigit()
                    .frame(maxWidth: 48)
                    .foregroundStyle(AppTheme.brand)
            } minimal: {
                Image(systemName: context.isStale ? "checkmark" : "pills.fill")
                    .foregroundStyle(AppTheme.brand)
            }
        }
    }

    @ViewBuilder
    private func countdownText(_ state: GLPWaitActivityAttributes.ContentState, isStale: Bool) -> some View {
        if isStale || state.endsAt <= .now {
            Text("Done")
        } else {
            Text(timerInterval: state.takenAt...state.endsAt, countsDown: true)
        }
    }
}

private struct WaitLockScreenView: View {
    let context: ActivityViewContext<GLPWaitActivityAttributes>

    var body: some View {
        let state = context.state
        let done = context.isStale || state.endsAt <= .now
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.brandSoft)
                        .frame(width: 40, height: 40)
                    Image(systemName: done ? "checkmark" : "pills.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.brand)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(done ? "Wait's over" : "Wait before food & drink")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                    Text("\(context.attributes.medicationName) · taken \(state.takenAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    if done {
                        Text("Done")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.brand)
                    } else {
                        Text(timerInterval: state.takenAt...state.endsAt, countsDown: true)
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100, alignment: .trailing)
                            .foregroundStyle(AppTheme.text)
                    }
                    Text("until \(state.endsAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            ProgressView(timerInterval: state.takenAt...state.endsAt, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(AppTheme.brand)
        }
        .padding(16)
    }
}
