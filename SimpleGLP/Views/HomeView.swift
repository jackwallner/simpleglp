import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var coordinator: ShotCaptureCoordinator
    @State private var showUndo = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let message = coordinator.bannerMessage, !message.isEmpty {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                }

                nextShotSection

                Button {
                    coordinator.captureShot(in: modelContext)
                    showUndo = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(AppTheme.brand)
                            .frame(width: 160, height: 160)
                            .shadow(color: AppTheme.brand.opacity(0.3), radius: 16, x: 0, y: 8)
                        VStack(spacing: 4) {
                            Image(systemName: "syringe.fill")
                                .font(.title2)
                            Text("I took my shot")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                    }
                }
                .disabled(coordinator.isCapturing)
                .padding(.vertical, 24)

                if showUndo, coordinator.lastCapturedEventID != nil {
                    Button("Undo") {
                        coordinator.undoLastCapture(in: modelContext)
                        showUndo = false
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 40)
            }
            .padding(.top, 16)
        }
        .background(AppTheme.bg.ignoresSafeArea())
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
                            .foregroundStyle(.secondary)
                        Text(next, style: .date)
                            .font(.headline)
                        Text(next, style: .time)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Dose")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        }
    }
}
