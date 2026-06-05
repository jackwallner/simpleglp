import SwiftUI

struct WatchRootView: View {
    @StateObject private var controller = WatchConnectivityController()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Button {
                    controller.requestShotLog()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: controller.showConfirmation ? "checkmark.circle.fill" : "syringe.fill")
                            .font(.system(size: 30, weight: .bold))
                        Text(controller.showConfirmation ? "Logged" : "I took my shot")
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

                if let status = controller.statusMessage, !controller.showConfirmation {
                    Text(status)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if !controller.recentShots.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Last few shots")
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
        .background(AppTheme.bg.ignoresSafeArea())
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
