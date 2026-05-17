import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var coordinator: ShotCaptureCoordinator
    @Query(sort: \ShotEvent.timestamp, order: .reverse) private var events: [ShotEvent]
    @State private var showUndo = false
    @State private var showConfirmation = false
    @State private var confirmationTask: Task<Void, Never>?

    private var recentEvents: [ShotEvent] { Array(events.prefix(5)) }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let message = coordinator.bannerMessage, !message.isEmpty {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                }

                nextShotSection

                shotButton

                if showUndo, coordinator.lastCapturedEventID != nil {
                    Button("Undo") {
                        coordinator.undoLastCapture(in: modelContext)
                        showUndo = false
                        showConfirmation = false
                        confirmationTask?.cancel()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
                }

                recentShotsSection

                Spacer(minLength: 40)
            }
            .padding(.top, 16)
        }
        .background(AppTheme.bg.ignoresSafeArea())
    }

    private var shotButton: some View {
        Button {
            coordinator.captureShot(in: modelContext)
            showUndo = true
            triggerConfirmation()
        } label: {
            ZStack {
                Circle()
                    .fill(showConfirmation ? AppTheme.brandPressed : AppTheme.brand)
                    .frame(width: 220, height: 220)
                    .shadow(color: AppTheme.brand.opacity(0.28), radius: 22, x: 0, y: 12)
                VStack(spacing: 8) {
                    Image(systemName: showConfirmation ? "checkmark.circle.fill" : "syringe.fill")
                        .font(.system(size: 44, weight: .bold))
                    Text(showConfirmation ? "Logged" : "I took my shot")
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(coordinator.isCapturing && !showConfirmation)
        .padding(.vertical, 24)
        .animation(.easeInOut(duration: 0.2), value: showConfirmation)
    }

    @ViewBuilder
    private var recentShotsSection: some View {
        if !recentEvents.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Last few shots")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                ForEach(recentEvents) { event in
                    RecentShotRow(timestamp: event.timestamp, status: event.scheduleStatus)
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var nextShotSection: some View {
        if let plan = PlanStore.currentPlan(in: modelContext),
           let next = ScheduleEngine.nextExpectedDate(plan: plan) {
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next shot")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.muted)
                        Text(next, style: .date)
                            .font(.headline)
                        Text(next, style: .time)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Dose")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.muted)
                        Text("\(ScheduleEngine.dose(on: next, plan: plan), specifier: "%.2f") mg")
                            .font(.headline)
                    }
                }
            }
            .padding(.horizontal)
        } else {
            Card {
                Text("Set up your plan in Settings to see upcoming shots.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            }
            .padding(.horizontal)
        }
    }

    private func triggerConfirmation() {
        confirmationTask?.cancel()
        showConfirmation = true
        confirmationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if !Task.isCancelled { showConfirmation = false }
        }
    }
}

struct RecentShotRow: View {
    let timestamp: Date
    let status: ScheduleMatchStatus

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(timestamp, style: .date)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Text(timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
            Text(status.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(tint.opacity(0.14), in: Capsule())
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppTheme.surfaceStroke.opacity(0.5), lineWidth: 1)
        )
    }

    private var tint: Color {
        switch status {
        case .onSchedule: AppTheme.brand
        case .early, .late: AppTheme.warm
        case .extra, .unknown: AppTheme.muted
        }
    }
}
