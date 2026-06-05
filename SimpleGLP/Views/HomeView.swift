import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var coordinator: ShotCaptureCoordinator
    @Query(sort: \ShotEvent.timestamp, order: .reverse) private var events: [ShotEvent]
    @AppStorage(GLPStorageKey.promptForDetails.rawValue, store: GLPAppGroup.userDefaults) private var promptForDetails = false
    @State private var showConfirmation = false
    @State private var confirmationTask: Task<Void, Never>?
    @State private var selectedEvent: ShotEvent?

    private var recentEvents: [ShotEvent] { Array(events.prefix(5)) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
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

                if coordinator.showUndoOption, coordinator.lastCapturedEventID != nil {
                    Button("Undo") {
                        coordinator.undoLastCapture(in: modelContext)
                        showConfirmation = false
                        confirmationTask?.cancel()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
                }

                recentShotsSection

                Spacer(minLength: 32)
            }
            .padding(.top, 12)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .sheet(item: $selectedEvent) { event in
            EditEventSheet(event: event)
        }
    }

    private var shotButton: some View {
        Button {
            let ok = coordinator.captureShot(in: modelContext)
            triggerConfirmation()
            if ok, promptForDetails, let id = coordinator.lastCapturedEventID {
                // The @Query array hasn't refreshed yet in this run loop turn, so
                // fetch the just-saved event straight from the context.
                var descriptor = FetchDescriptor<ShotEvent>(predicate: #Predicate { $0.id == id })
                descriptor.fetchLimit = 1
                selectedEvent = try? modelContext.fetch(descriptor).first
            }
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
        // Stay disabled through the whole confirmation window so a second tap
        // during the "Logged" flash can't write a duplicate shot.
        .disabled(coordinator.isCapturing || showConfirmation)
        .padding(.vertical, 8)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showConfirmation)
    }

    @ViewBuilder
    private var recentShotsSection: some View {
        if !recentEvents.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Last few shots")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                ForEach(recentEvents) { event in
                    Button {
                        selectedEvent = event
                    } label: {
                        RecentShotRow(event: event)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var nextShotSection: some View {
        if let plan = PlanStore.currentPlan(in: modelContext),
           let next = ScheduleEngine.nextExpectedDate(plan: plan) {
            let copy = relativeShotCopy(plan: plan, nextExpected: next)
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            if copy.isOverdue {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                            }
                            Text(copy.headline)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(copy.isOverdue ? AppTheme.warm : AppTheme.muted)
                        Text(copy.dateToShow, style: .date)
                            .font(.headline)
                        Text(copy.dateToShow, style: .time)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Dose")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.muted)
                        Text("\(ScheduleEngine.dose(on: copy.dateToShow, plan: plan), specifier: "%.2f") mg")
                            .font(.headline)
                    }
                }
            }
            .padding(.horizontal)
        } else {
            Card {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No plan yet")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                    Text("Add your medication and shot day in Settings to see what’s next.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal)
        }
    }

    private struct ShotCopy {
        var headline: String
        var dateToShow: Date
        var isOverdue: Bool
    }

    private func relativeShotCopy(plan: MedicationPlan, nextExpected: Date) -> ShotCopy {
        let calendar = Calendar.current
        let now = Date()
        let lastShot = events.first?.timestamp
        if let prior = ScheduleEngine.scheduledDate(onOrBefore: now, plan: plan, calendar: calendar),
           prior >= plan.scheduleStartDate,
           (lastShot ?? .distantPast) < prior {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: prior), to: calendar.startOfDay(for: now)).day ?? 0
            let headline: String
            switch days {
            case 0: headline = "Due today"
            case 1: headline = "Overdue by 1 day"
            default: headline = "Overdue by \(days) days"
            }
            return ShotCopy(headline: headline, dateToShow: prior, isOverdue: true)
        }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: nextExpected)).day ?? 0
        let headline: String
        switch days {
        case 0: headline = "Due today"
        case 1: headline = "Tomorrow"
        default: headline = "In \(days) days"
        }
        return ShotCopy(headline: headline, dateToShow: nextExpected, isOverdue: false)
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
    let event: ShotEvent

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.timestamp, style: .date)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Text(event.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(event.scheduleStatus.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(tint.opacity(0.14), in: Capsule())
                if let rationale = event.scheduleRationale {
                    Text(rationale)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.muted)
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(AppTheme.surfaceStroke.opacity(0.5), lineWidth: 1)
        )
    }

    private var tint: Color {
        switch event.scheduleStatus {
        case .onSchedule: AppTheme.brand
        case .early, .late: AppTheme.warm
        case .extra, .unknown: AppTheme.muted
        }
    }
}
