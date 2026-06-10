import StoreKit
import SwiftData
import SwiftUI
@preconcurrency import RevenueCat

struct RootTabView: View {
    @EnvironmentObject private var store: StoreService
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(GLPStorageKey.appearance.rawValue, store: GLPAppGroup.userDefaults) private var appearanceRaw = AppAppearance.system.rawValue
    @AppStorage(GLPStorageKey.hasCompletedOnboarding.rawValue, store: GLPAppGroup.userDefaults) private var hasCompletedOnboarding = false
    @AppStorage(GLPStorageKey.hasSeenFirstRunOffer.rawValue, store: GLPAppGroup.userDefaults) private var hasSeenFirstRunOffer = false
    @AppStorage(GLPStorageKey.hasSeenTrialOffer.rawValue, store: GLPAppGroup.userDefaults) private var hasSeenTrialOffer = false
    @AppStorage(GLPStorageKey.hasSeenPatternsTrialOffer.rawValue, store: GLPAppGroup.userDefaults) private var hasSeenPatternsTrialOffer = false
    /// Count-only awareness of logged shots. Drives the first-shot trial trigger
    /// and the existing-user catch-up without hydrating full events on every change.
    @Query private var events: [ShotEvent]
    @StateObject private var reviewPromptCoordinator = ReviewPromptCoordinator.shared
    @State private var selectedTab = 0
    /// Single source of truth for every root-level promo / review sheet. One
    /// `.sheet(item:)` instead of stacked `.sheet(isPresented:)` modifiers
    /// guarantees only one ever presents — stacked sheets on the same view can
    /// race and present an empty shell.
    @State private var activeSheet: RootPromoSheet?
    @State private var reviewPromptInitialStep: ReviewPromptSheet.Step = .enjoyment
    @State private var reviewPromptShownThisSession = false
    @State private var pendingNativeReviewAfterDismiss = false
    @State private var trialPaywallImpressionId = "simpleglp_first_run"
    /// One Pro moment per session, shared across the first-run paywall and every
    /// trial-offer trigger so they never stack back-to-back.
    @State private var paywallShownThisSession = false
    @State private var trialPurchaseInFlight = false
    @State private var trialPurchaseError: String?
    /// Which trigger opened the current trial offer, so dismissal sets the right flag.
    @State private var trialOfferSource: TrialOfferSource = .firstShot
    /// Set when the user opts into the full plan picker from inside the trial-offer
    /// sheet. `.sheet(onDismiss:)` reads this and presents the paywall *after* the
    /// trial sheet has fully dismissed — presenting both in the same runloop tick
    /// is racy in SwiftUI and frequently drops the second sheet.
    @State private var pendingPaywallAfterTrialDismiss = false
    /// Bumped every time the scene leaves the foreground. Delayed presentation tasks
    /// capture it before sleeping and abort if it changed: a timer that slept across a
    /// backgrounding would otherwise fire the instant the app resumes and present a
    /// sheet over a scene that hasn't rendered yet — a blank white shell.
    @State private var foregroundEpoch = 0
    @Environment(\.requestReview) private var requestReview

    private enum TrialOfferSource {
        case firstShot
        case existingUser
        case patterns
    }

    /// The mutually-exclusive root sheet currently presented.
    private enum RootPromoSheet: String, Identifiable {
        case firstRunPaywall
        case trialOffer
        case trialPaywall
        case reviewPrompt
        var id: String { rawValue }
    }

    private var trialOfferLabel: String? {
        directTrialPackage?.glpProIntroOfferLabel
            ?? store.products.compactMap(\.glpProIntroOfferLabel).first
    }

    private var hasTrialOffer: Bool { directTrialPackage != nil }

    /// The package the direct trial purchase buys: prefer eligible yearly trial,
    /// else any eligible trial-bearing package.
    private var directTrialPackage: Package? {
        let trialPackages = store.products.filter { store.isEligibleForIntroOffer($0) }
        return trialPackages.first { $0.glpProPackageKind == .yearly } ?? trialPackages.first
    }

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
        .sheet(item: $activeSheet, onDismiss: handleRootSheetDismiss) { sheet in
            switch sheet {
            case .firstRunPaywall:
                SimplePaywallView(paywallImpressionId: trialPaywallImpressionId)
                    .environmentObject(store)
                    // Persist "seen" only once the sheet actually appears. On a fresh
                    // install the HealthKit permission sheet from onboarding can swallow
                    // this presentation; if the flag were set up front the offer would
                    // be lost forever — this way it retries on the next launch.
                    .onAppear { hasSeenFirstRunOffer = true }
            case .trialOffer:
                TrialOfferSheet(
                    offerLabel: trialOfferLabel,
                    priceLabel: directTrialPackage?.glpProPriceLabel,
                    directPurchase: directTrialPackage != nil,
                    isPurchasing: trialPurchaseInFlight,
                    errorMessage: trialPurchaseError,
                    onStartTrial: {
                        if directTrialPackage != nil {
                            startDirectTrialPurchase()
                        } else {
                            pendingPaywallAfterTrialDismiss = true
                            activeSheet = nil
                        }
                    },
                    onSeeAllPlans: {
                        pendingPaywallAfterTrialDismiss = true
                        activeSheet = nil
                    },
                    onDismiss: { activeSheet = nil }
                )
                .environmentObject(store)
                .presentationDetents([.fraction(0.85), .large])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(trialPurchaseInFlight)
            case .trialPaywall:
                SimplePaywallView(paywallImpressionId: "simpleglp_trial_sheet")
                    .environmentObject(store)
            case .reviewPrompt:
                ReviewPromptSheet(initialStep: reviewPromptInitialStep, onFinish: handleReviewPromptFinish)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glpPositiveMomentForReview)) { _ in
            scheduleReviewPromptAfterPositiveMoment()
        }
        .onChange(of: reviewPromptCoordinator.pendingPresentation) { _, presentation in
            guard let presentation else { return }
            defer { reviewPromptCoordinator.clear() }
            guard activeSheet == nil else { return }
            switch presentation {
            case .enjoymentPrompt:
                presentReviewPrompt(step: .enjoyment)
            case .feedbackOnly:
                presentReviewPrompt(step: .feedback)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glpFirstShotLogged)) { _ in
            evaluateFirstShotTrialOffer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .glpPatternsDidAppear)) { _ in
            evaluatePatternsTrialOffer()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                foregroundEpoch += 1
            }
        }
        .onChange(of: store.isProUnlocked) { _, isPro in
            guard isPro else { return }
            // Once the user is Pro, never pitch again, and dismiss any promo that
            // presented during the entitlement-resolution window. Persisting the
            // flags here keeps a programmatic dismissal from re-firing next launch.
            hasSeenFirstRunOffer = true
            hasSeenTrialOffer = true
            if activeSheet == .firstRunPaywall || activeSheet == .trialOffer {
                activeSheet = nil
            }
        }
        .onChange(of: store.hasResolvedEntitlements) { _, resolved in
            // Entitlements often resolve a beat after the view appears. Re-run the
            // promo paths once we actually know the user isn't Pro.
            guard resolved else { return }
            presentFirstRunOfferIfEligible()
            evaluateExistingUserTrialOffer()
        }
        .onChange(of: store.products.count) { _, _ in
            // Products may load after appear — re-evaluate the existing-user path so a
            // returning user with shots but no products yet still gets pitched.
            evaluateExistingUserTrialOffer()
        }
        .onAppear {
            presentFirstRunOfferIfEligible()
            evaluateExistingUserTrialOffer()
        }
    }

    /// Soft trial offer right after onboarding — the highest-intent moment (most trial
    /// decisions happen on day 0). Dismissible so it never gates the core app.
    private func presentFirstRunOfferIfEligible() {
        guard !hasSeenFirstRunOffer,
              !store.isProUnlocked,
              !paywallShownThisSession,
              !AppEnvironment.isUITesting
        else { return }
        // Claim the per-session slot up front so a fast first-shot log can't race in behind us.
        paywallShownThisSession = true
        let epoch = foregroundEpoch
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard epoch == foregroundEpoch,
                  !hasSeenFirstRunOffer,
                  !store.isProUnlocked,
                  !store.hasRecentOrActiveProSignal,
                  activeSheet == nil
            else {
                // Release the slot if we bailed for a transient reason; a Pro flip
                // makes the guards above permanent anyway.
                paywallShownThisSession = store.isProUnlocked
                return
            }
            trialPaywallImpressionId = "simpleglp_first_run"
            activeSheet = .firstRunPaywall
        }
    }

    /// First-use pitch: just logged their first shot — the peak value moment. Waits
    /// ~4s so the capture animation and Health-context banner settle first; pitching
    /// mid-animation collides with the dashboard and converts worse.
    private func evaluateFirstShotTrialOffer() {
        guard hasCompletedOnboarding,
              !store.isProUnlocked,
              !hasSeenTrialOffer,
              hasTrialOffer
        else { return }
        let epoch = foregroundEpoch
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard epoch == foregroundEpoch else { return }
            presentTrialOfferIfReady(source: .firstShot)
        }
    }

    /// Existing-user catch-up: already has shots logged but has never seen the trial
    /// pitch. Fires ~3s after Home appears so the dashboard renders before the sheet.
    private func evaluateExistingUserTrialOffer() {
        guard hasCompletedOnboarding,
              !store.isProUnlocked,
              !hasSeenTrialOffer,
              hasTrialOffer,
              events.count > 0
        else { return }
        let epoch = foregroundEpoch
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard epoch == foregroundEpoch else { return }
            presentTrialOfferIfReady(source: .existingUser)
        }
    }

    /// Second-touch trial nudge when the Patterns tab appears in a later session.
    /// Own seen-flag: users whose products failed to load during the first-shot path
    /// still get a pitch here. `paywallShownThisSession` keeps it off the same
    /// session as any other promo.
    private func evaluatePatternsTrialOffer() {
        guard hasCompletedOnboarding,
              !store.isProUnlocked,
              !hasSeenPatternsTrialOffer,
              hasTrialOffer,
              activeSheet == nil
        else { return }
        presentTrialOfferIfReady(source: .patterns)
    }

    private func presentTrialOfferIfReady(source: TrialOfferSource) {
        // Never pitch before RevenueCat has said whether the user is already Pro —
        // otherwise a premium user gets a promo (or a blank racing sheet) during the
        // launch window. Recent Pro history can flip isProUnlocked a beat later and
        // yank the sheet mid-presentation, so those accounts are skipped too.
        guard store.hasResolvedEntitlements,
              scenePhase == .active,
              activeSheet == nil,
              !store.isProUnlocked,
              !store.hasRecentOrActiveProSignal,
              !paywallShownThisSession,
              hasTrialOffer,
              !AppEnvironment.isUITesting
        else { return }
        switch source {
        case .firstShot, .existingUser:
            guard !hasSeenTrialOffer else { return }
        case .patterns:
            guard !hasSeenPatternsTrialOffer else { return }
        }
        trialPurchaseError = nil
        trialPurchaseInFlight = false
        trialOfferSource = source
        paywallShownThisSession = true
        // Mark the offer seen at present-time (not on dismiss) so it stays a one-shot
        // even if the app is killed while the sheet is up.
        markTrialOfferSeen()
        trackTrialOfferImpression(source: source)
        activeSheet = .trialOffer
    }

    /// `hasSeenTrialOffer` always flips so the main path won't re-fire.
    /// `hasSeenPatternsTrialOffer` flips only on the Patterns touch — leaving it
    /// false after a first-shot dismissal lets the second touch still fire in a
    /// later session.
    private func markTrialOfferSeen() {
        hasSeenTrialOffer = true
        if trialOfferSource == .patterns {
            hasSeenPatternsTrialOffer = true
        }
    }

    private func trackTrialOfferImpression(source: TrialOfferSource) {
        let id: String
        switch source {
        case .firstShot: id = "simpleglp_trial_offer_first_shot"
        case .existingUser: id = "simpleglp_trial_offer_existing_user"
        case .patterns: id = "simpleglp_trial_offer_patterns"
        }
        store.trackPaywallImpression(id: id)
    }

    private func startDirectTrialPurchase() {
        guard let package = directTrialPackage else {
            pendingPaywallAfterTrialDismiss = true
            activeSheet = nil
            return
        }
        trialPurchaseError = nil
        trialPurchaseInFlight = true
        Task { @MainActor in
            defer { trialPurchaseInFlight = false }
            do {
                switch try await store.purchase(package) {
                case .purchased, .pending:
                    hasSeenTrialOffer = true
                    activeSheet = nil
                case .cancelled:
                    trialPurchaseError = "Trial wasn't started. Tap again, or pick a different plan."
                }
            } catch {
                trialPurchaseError = "Couldn't start your trial. Please try again."
            }
        }
    }

    /// Single dismissal handler for the root promo / review sheet. Runs trial-purchase
    /// cleanup and the two deferred follow-ups (chained paywall, native review prompt)
    /// that must fire only after the sheet has fully dismissed. Both follow-ups are
    /// gated on flags only their own flow sets, so this is safe to run for any sheet.
    private func handleRootSheetDismiss() {
        trialPurchaseInFlight = false
        trialPurchaseError = nil
        if pendingPaywallAfterTrialDismiss {
            pendingPaywallAfterTrialDismiss = false
            activeSheet = .trialPaywall
        }
        if pendingNativeReviewAfterDismiss {
            pendingNativeReviewAfterDismiss = false
            requestReview()
        }
    }

    private func scheduleReviewPromptAfterPositiveMoment() {
        guard ReviewPromptTracker.shouldShowAfterPositiveMoment(hasCompletedSetup: hasCompletedOnboarding),
              !reviewPromptShownThisSession,
              reviewPromptTabAllowed,
              activeSheet == nil
        else { return }

        let epoch = foregroundEpoch
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard epoch == foregroundEpoch,
                  reviewPromptTabAllowed,
                  activeSheet == nil,
                  ReviewPromptTracker.shouldShowAfterPositiveMoment(hasCompletedSetup: hasCompletedOnboarding)
            else { return }
            ReviewPromptTracker.consumePendingPositiveMoment()
            presentReviewPrompt(step: .enjoyment)
        }
    }

    private func handleReviewPromptFinish(_ outcome: ReviewPromptDismissOutcome) {
        // Set the deferred follow-up flag before dismissing so `handleRootSheetDismiss`
        // fires the native review prompt once the sheet closes.
        if outcome == .enjoyedMaybeLater {
            pendingNativeReviewAfterDismiss = true
        }
        activeSheet = nil
    }

    private func presentReviewPrompt(step: ReviewPromptSheet.Step) {
        reviewPromptInitialStep = step
        reviewPromptShownThisSession = true
        activeSheet = .reviewPrompt
    }

    /// Passive prompts only on One Tap (shot logged) or Settings (export success).
    private var reviewPromptTabAllowed: Bool {
        selectedTab == 0 || selectedTab == 3
    }
}
