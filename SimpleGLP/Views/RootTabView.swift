import StoreKit
import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var store: StoreService
    @AppStorage(GLPStorageKey.appearance.rawValue, store: GLPAppGroup.userDefaults) private var appearanceRaw = AppAppearance.system.rawValue
    @AppStorage(GLPStorageKey.hasCompletedOnboarding.rawValue, store: GLPAppGroup.userDefaults) private var hasCompletedOnboarding = false
    @AppStorage(GLPStorageKey.hasSeenFirstRunOffer.rawValue, store: GLPAppGroup.userDefaults) private var hasSeenFirstRunOffer = false
    @AppStorage(GLPStorageKey.hasSeenFirstShotOffer.rawValue, store: GLPAppGroup.userDefaults) private var hasSeenFirstShotOffer = false
    @StateObject private var reviewPromptCoordinator = ReviewPromptCoordinator.shared
    @State private var selectedTab = 0
    @State private var showReviewPrompt = false
    @State private var reviewPromptInitialStep: ReviewPromptSheet.Step = .enjoyment
    @State private var reviewPromptShownThisSession = false
    @State private var pendingNativeReviewAfterDismiss = false
    @State private var showTrialPaywall = false
    @State private var trialPaywallImpressionId = "simpleglp_first_run"
    @State private var paywallShownThisSession = false
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label("One Tap", systemImage: "syringe.fill") }
                .tag(0)

            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(1)

            NavigationStack { InsightsView() }
                .tabItem { Label("Patterns", systemImage: "chart.bar.xaxis") }
                .tag(2)

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                .tag(3)
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
        .sheet(isPresented: $showTrialPaywall) {
            SimplePaywallView(paywallImpressionId: trialPaywallImpressionId)
                .environmentObject(store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .glpFirstShotLogged)) { _ in
            presentFirstShotOfferIfEligible()
        }
        .onAppear { presentFirstRunOfferIfEligible() }
    }

    /// Soft trial offer right after onboarding — the highest-intent moment. Dismissible (the
    /// paywall's own close button) so it never gates the core app. One offer per session, max.
    private func presentFirstRunOfferIfEligible() {
        guard !hasSeenFirstRunOffer,
              !store.isProUnlocked,
              !paywallShownThisSession,
              !AppEnvironment.isUITesting
        else { return }
        // Claim the per-session slot up front so a fast first-shot log can't race in behind us.
        paywallShownThisSession = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !hasSeenFirstRunOffer, !store.isProUnlocked, !showReviewPrompt else { return }
            hasSeenFirstRunOffer = true
            trialPaywallImpressionId = "simpleglp_first_run"
            showTrialPaywall = true
        }
    }

    /// Contextual trial offer right after the first shot is logged — a peak value moment.
    /// Suppressed if any paywall already showed this session (e.g. the post-onboarding one).
    private func presentFirstShotOfferIfEligible() {
        guard !hasSeenFirstShotOffer,
              !store.isProUnlocked,
              !paywallShownThisSession,
              !showReviewPrompt,
              !AppEnvironment.isUITesting
        else { return }
        hasSeenFirstShotOffer = true
        paywallShownThisSession = true
        trialPaywallImpressionId = "simpleglp_first_shot"
        showTrialPaywall = true
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
        selectedTab == 0 || selectedTab == 3
    }
}
