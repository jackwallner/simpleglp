import StoreKit
import SwiftUI

struct RootTabView: View {
    @AppStorage(GLPStorageKey.appearance.rawValue, store: GLPAppGroup.userDefaults) private var appearanceRaw = AppAppearance.system.rawValue
    @AppStorage(GLPStorageKey.hasCompletedOnboarding.rawValue, store: GLPAppGroup.userDefaults) private var hasCompletedOnboarding = false
    @StateObject private var reviewPromptCoordinator = ReviewPromptCoordinator.shared
    @State private var selectedTab = 0
    @State private var showReviewPrompt = false
    @State private var reviewPromptInitialStep: ReviewPromptSheet.Step = .enjoyment
    @State private var reviewPromptShownThisSession = false
    @State private var pendingNativeReviewAfterDismiss = false
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label("One Tap", systemImage: "syringe.fill") }
                .tag(0)

            NavigationStack { LogHubView() }
                .tabItem { Label("Optional", systemImage: "plus.circle") }
                .tag(1)

            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(2)

            NavigationStack { InsightsView() }
                .tabItem { Label("Patterns", systemImage: "chart.bar.xaxis") }
                .tag(3)

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                .tag(4)
        }
        .tint(AppTheme.brand)
        .preferredColorScheme(AppAppearance.from(storageValue: appearanceRaw).preferredColorScheme)
        .onReceive(NotificationCenter.default.publisher(for: .glpPositiveMomentForReview)) { _ in
            scheduleReviewPromptAfterPositiveMoment()
        }
        .onChange(of: reviewPromptCoordinator.pendingPresentation) { _, presentation in
            guard let presentation else { return }
            defer { reviewPromptCoordinator.clear() }
            guard !showReviewPrompt else { return }
            switch presentation {
            case .enjoymentPrompt:
                presentReviewPrompt(step: .enjoyment)
            case .feedbackOnly:
                presentReviewPrompt(step: .feedback)
            }
        }
        .sheet(isPresented: $showReviewPrompt, onDismiss: {
            if pendingNativeReviewAfterDismiss {
                pendingNativeReviewAfterDismiss = false
                requestReview()
            }
        }) {
            ReviewPromptSheet(initialStep: reviewPromptInitialStep, onFinish: handleReviewPromptFinish)
        }
    }

    private func scheduleReviewPromptAfterPositiveMoment() {
        guard ReviewPromptTracker.shouldShowAfterPositiveMoment(hasCompletedSetup: hasCompletedOnboarding),
              !reviewPromptShownThisSession,
              reviewPromptTabAllowed,
              !showReviewPrompt
        else { return }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard reviewPromptTabAllowed,
                  !showReviewPrompt,
                  ReviewPromptTracker.shouldShowAfterPositiveMoment(hasCompletedSetup: hasCompletedOnboarding)
            else { return }
            ReviewPromptTracker.consumePendingPositiveMoment()
            reviewPromptInitialStep = .enjoyment
            reviewPromptShownThisSession = true
            showReviewPrompt = true
        }
    }

    private func handleReviewPromptFinish(_ outcome: ReviewPromptDismissOutcome) {
        showReviewPrompt = false
        if outcome == .enjoyedMaybeLater {
            pendingNativeReviewAfterDismiss = true
        }
    }

    private func presentReviewPrompt(step: ReviewPromptSheet.Step) {
        reviewPromptInitialStep = step
        reviewPromptShownThisSession = true
        showReviewPrompt = true
    }

    /// Passive prompts only on One Tap (shot logged) or Settings (export success).
    private var reviewPromptTabAllowed: Bool {
        selectedTab == 0 || selectedTab == 4
    }
}
