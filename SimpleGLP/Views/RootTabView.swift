import StoreKit
import SwiftData
import SwiftUI
import UIKit
import UserNotifications
@preconcurrency import RevenueCat

struct RootTabView: View {
    @EnvironmentObject private var store: StoreService
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(GLPStorageKey.appearance.rawValue, store: GLPAppGroup.userDefaults) private var appearanceRaw = AppAppearance.system.rawValue
    @AppStorage(GLPStorageKey.hasCompletedOnboarding.rawValue, store: GLPAppGroup.userDefaults) private var hasCompletedOnboarding = false
    @AppStorage(GLPStorageKey.hasSeenFirstRunOffer.rawValue, store: GLPAppGroup.userDefaults) private var hasSeenFirstRunOffer = false
    @AppStorage(GLPStorageKey.hasSeenTrialOffer.rawValue, store: GLPAppGroup.userDefaults) private var hasSeenTrialOffer = false
    @AppStorage(GLPStorageKey.hasSeenPatternsTrialOffer.rawValue, store: GLPAppGroup.userDefaults) private var hasSeenPatternsTrialOffer = false
    @AppStorage(GLPStorageKey.isPillPlan.rawValue, store: GLPAppGroup.userDefaults) private var isPillPlan = false
    /// Count-only awareness of logged shots. Drives the first-shot trial trigger
    /// and the existing-user catch-up without hydrating full events on every change.
    @Query private var events: [ShotEvent]
    @State private var selectedTab = 0
    /// True once the first-run paywall has actually been presented this session
    /// (confirmed by the sheet's `.onAppear`). `hasSeenFirstRunOffer` is consumed only
    /// when a *presented* sheet is dismissed (see `handleRootSheetDismiss`).
    @State private var firstRunPaywallPresented = false
    /// True between requesting the first-run sheet and its `.onAppear` confirming it
    /// actually presented. A watchdog resets a dropped attempt (present rejected because
    /// a permission dialog grabbed the window) so a later scenePhase→active retry works.
    @State private var firstRunPaywallPending = false
    /// Single source of truth for every root-level promo sheet. One
    /// `.sheet(item:)` instead of stacked `.sheet(isPresented:)` modifiers
    /// guarantees only one ever presents — stacked sheets on the same view can
    /// race and present an empty shell.
    @State private var activeSheet: RootPromoSheet?
    @State private var reviewPromptShownThisSession = false
    /// A trial pitch is waiting out its delay. The rating ask never runs into it.
    @State private var trialPitchScheduled = false
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// The container's width and fold, measured so the unfolded iPhone Duo can
    /// put One Tap and History on opposite sides of the fold.
    @State private var paneGeometry = PaneGeometry()
    /// History's month, owned here because History moves between its tab and
    /// its own pane when the Duo folds or unfolds.
    @State private var historyMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var patternsPath = NavigationPath()

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
        var id: String { rawValue }
    }

    private var trialOfferLabel: String? {
        directTrialPackage?.glpProIntroOfferLabel
    }

    private var hasTrialOffer: Bool { directTrialPackage != nil }

    /// The package the direct trial purchase buys: prefer eligible yearly trial,
    /// else any eligible trial-bearing package.
    private var directTrialPackage: Package? {
        let trialPackages = store.products.filter { store.isEligibleForIntroOffer($0) }
        return trialPackages.first { $0.glpProPackageKind == .yearly } ?? trialPackages.first
    }

    /// Unfolded, History has its own pane beside One Tap, so it is never a tab.
    private var split: UnfoldedSplit? {
        UnfoldedSplit.make(
            width: paneGeometry.width,
            isRegularWidth: horizontalSizeClass == .regular,
            fold: paneGeometry.fold
        )
    }

    /// Each unfolded pane is phone-width, so its screen lays out as on a phone.
    /// Applied to the tab contents, not the `TabView`, whose own bar placement
    /// is left to the system.
    private var paneSizeClass: UserInterfaceSizeClass? {
        split == nil ? horizontalSizeClass : .compact
    }

    var body: some View {
        // Opening or closing the Duo only moves these frames, so the tab view is
        // never rebuilt. History's month lives here for its move between tab and pane.
        ZStack(alignment: .topLeading) {
            tabs
                .frame(maxWidth: split?.primaryWidth ?? .infinity, maxHeight: .infinity)
            if let split {
                NavigationStack { HistoryView(shownMonth: $historyMonth) }
                    .environment(\.horizontalSizeClass, .compact)
                    .frame(width: split.secondaryWidth)
                    .frame(maxHeight: .infinity)
                    .padding(.leading, split.secondaryX)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .onGeometryChange(for: PaneGeometry.self) { proxy in
            PaneGeometry(width: proxy.size.width, fold: proxy.verticalFold())
        } action: { paneGeometry = $0 }
        .onChange(of: split != nil) { _, isSplit in
            if isSplit, selectedTab == 1 { selectedTab = 0 }
        }
        #if DEBUG
        .task {
            applyDuoScreen()
            await runDuoTour()
        }
        #endif
        .tint(AppTheme.brand)
        .preferredColorScheme(AppAppearance.from(storageValue: appearanceRaw).preferredColorScheme)
        .sheet(item: $activeSheet, onDismiss: handleRootSheetDismiss) { sheet in
            switch sheet {
            case .firstRunPaywall:
                // First-run moment: the one-tap trial-first sheet (not the full plan
                // picker). One primary action buys the yearly trial directly; "See all
                // plans" chains to SimplePaywallView (monthly/lifetime live there);
                // "Not now" lands in the app with nothing stacked on top.
                //
                // `.onAppear` here means the sheet was *actually added to the hierarchy*
                // — it fires even if the sheet sits behind a permission alert, but it
                // does NOT fire when the present is dropped (SwiftUI silently rejects a
                // sheet raised at the same instant a system dialog takes the window).
                // So it's the reliable "the user will see this" signal: commit the
                // per-session slot, mark presented, and fire the `simpleglp_first_run`
                // impression here. `hasSeenFirstRunOffer` is still consumed only on real
                // dismissal (`handleRootSheetDismiss`), so neither the slot nor the
                // impression is spent on a dropped present.
                TrialOfferSheet(
                    offerLabel: trialOfferLabel,
                    trialPeriodLabel: directTrialPackage?.glpProIntroOfferPeriodLabel,
                    trialDays: directTrialPackage?.glpProIntroOfferDays,
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
                .onAppear {
                    firstRunPaywallPending = false
                    firstRunPaywallPresented = true
                    paywallShownThisSession = true
                    store.trackPaywallImpression(id: "simpleglp_first_run")
                }
            case .trialOffer:
                TrialOfferSheet(
                    offerLabel: trialOfferLabel,
                    trialPeriodLabel: directTrialPackage?.glpProIntroOfferPeriodLabel,
                    trialDays: directTrialPackage?.glpProIntroOfferDays,
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
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glpPositiveMomentForReview)) { _ in
            scheduleReviewRequestAfterPositiveMoment()
        }
        .onReceive(NotificationCenter.default.publisher(for: .glpFirstShotLogged)) { _ in
            evaluateFirstShotTrialOffer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .glpPatternsDidAppear)) { _ in
            evaluatePatternsTrialOffer()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                foregroundEpoch += 1
            case .active:
                // Onboarding permission alerts briefly deactivate the scene. Once we're
                // foreground-active again (every dialog dismissed), retry the deferred
                // first-run offer.
                presentFirstRunOfferIfEligible()
            default:
                break
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
            // Products may load after appear — retry the first-run offer (it waits for
            // the trial package so it never presents degraded) and re-evaluate the
            // existing-user path so a returning user with shots still gets pitched.
            presentFirstRunOfferIfEligible()
            evaluateExistingUserTrialOffer()
        }
        .onChange(of: store.introEligibility) { _, _ in
            presentFirstRunOfferIfEligible()
            evaluateExistingUserTrialOffer()
        }
        .onAppear {
            presentFirstRunOfferIfEligible()
            evaluateExistingUserTrialOffer()
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HomeView() }
                .environment(\.horizontalSizeClass, paneSizeClass)
                .modifier(PaneBarBand(isOn: split != nil, color: AppTheme.bg))
                .tabItem { Label("One Tap", systemImage: isPillPlan ? "pills.fill" : "syringe.fill") }
                .tag(0)

            if split == nil {
                NavigationStack { HistoryView(shownMonth: $historyMonth) }
                    .environment(\.horizontalSizeClass, paneSizeClass)
                    .modifier(PaneBarBand(isOn: split != nil, color: AppTheme.bg))
                    .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                    .tag(1)
            }

            NavigationStack(path: $patternsPath) {
                InsightsView()
                    .navigationDestination(for: PatternsRoute.self) { route in
                        switch route {
                        case .supply: SupplyView()
                        }
                    }
            }
            .environment(\.horizontalSizeClass, paneSizeClass)
            .modifier(PaneBarBand(isOn: split != nil, color: patternsPath.isEmpty ? AppTheme.bg : Color(.systemGroupedBackground)))
            .tabItem { Label("Patterns", systemImage: "chart.bar.xaxis") }
            .tag(2)

            NavigationStack { SettingsView() }
                .environment(\.horizontalSizeClass, paneSizeClass)
                .modifier(PaneBarBand(isOn: split != nil, color: Color(.systemGroupedBackground)))
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                .tag(3)
        }
    }

    #if DEBUG
    /// `-GLPDuoScreen oneTap|history|patterns|supply|settings`: opens one surface
    /// at launch, so a capture run relaunches once per surface instead of timing
    /// shots against the tour.
    private func applyDuoScreen() {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-GLPDuoScreen"), index + 1 < args.count else { return }
        switch args[index + 1] {
        case "history": selectedTab = 1
        case "patterns": selectedTab = 2
        case "supply":
            selectedTab = 2
            patternsPath.append(PatternsRoute.supply)
        case "settings": selectedTab = 3
        default: selectedTab = 0
        }
    }

    /// `-GLPDuoTour`: walks the main screens for headless capture runs, which
    /// can't tap and whose `simctl openurl` stops on a confirmation alert. How
    /// late the first shot lands varies by runner, so the tour loops: 13 s each
    /// on One Tap, History, Patterns and Settings folded, or One Tap, Patterns,
    /// Supply and Settings unfolded, where History already has its own pane. A
    /// 52 s loop keeps shots taken every 10 to 20 s from repeating one screen.
    private func runDuoTour() async {
        guard ProcessInfo.processInfo.arguments.contains("-GLPDuoTour") else { return }
        let start = ContinuousClock.now
        for tick in 1... {
            try? await Task.sleep(until: start + .seconds(13 * tick), clock: .continuous)
            guard !Task.isCancelled else { return }
            let isSplit = split != nil
            let step = tick % 4
            NSLog("GLPDUOTOUR t=%ld split=%ld step=%ld", 13 * tick, isSplit ? 1 : 0, step)
            withAnimation(.easeInOut(duration: 0.3)) {
                switch (isSplit, step) {
                case (_, 0):
                    patternsPath = NavigationPath()
                    selectedTab = 0
                case (false, 1): selectedTab = 1
                case (true, 1), (false, 2): selectedTab = 2
                case (true, 2): patternsPath.append(PatternsRoute.supply)
                default: selectedTab = 3
                }
            }
        }
    }
    #endif

    /// Soft trial offer right after onboarding — the highest-intent moment (most trial
    /// decisions happen on day 0). Dismissible so it never gates the core app.
    private func presentFirstRunOfferIfEligible() {
        guard !hasSeenFirstRunOffer,
              !firstRunPaywallPresented,
              !firstRunPaywallPending,
              store.hasResolvedEntitlements,
              !store.isProUnlocked,
              !paywallShownThisSession,
              !AppEnvironment.isUITesting,
              activeSheet == nil,
              // Never present a degraded first-run sheet: the one-tap offer needs the
              // trial-bearing package (intro label + billed price) resolved. Products
              // loading late is covered by the products.count onChange retry.
              hasTrialOffer,
              // Defer until the scene is foreground-active. Right after Finish the
              // Notifications + HealthKit permission alerts are up, which puts the scene
              // in `.inactive`; presenting now would slide the paywall in *behind* them
              // (or get it dropped). `scenePhase == .active` is only true once every
              // system dialog is gone, and the scenePhase→active handler retries then.
              // Cannot deadlock (unlike waiting on a permission callback that may never
              // resume).
              scenePhase == .active
        else { return }
        let epoch = foregroundEpoch
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard epoch == foregroundEpoch,
                  scenePhase == .active,
                  !hasSeenFirstRunOffer,
                  !firstRunPaywallPresented,
                  !firstRunPaywallPending,
                  !paywallShownThisSession,
                  store.hasResolvedEntitlements,
                  !store.isProUnlocked,
                  !store.hasRecentOrActiveProSignal,
                  hasTrialOffer,
                  activeSheet == nil
            else { return }
            // Request the sheet. The per-session slot and "presented" flag are committed
            // only in the sheet's `.onAppear` (real presentation) — NOT here — so a
            // dropped present never suppresses the first-shot offer nobody saw.
            trialPurchaseError = nil
            trialPurchaseInFlight = false
            firstRunPaywallPending = true
            activeSheet = .firstRunPaywall
            // Watchdog: if the present was dropped (a permission dialog grabbed the
            // window at the same tick), `.onAppear` never fires. Reset so the next
            // scenePhase→active retry can present cleanly once nothing competes.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                guard firstRunPaywallPending,
                      !firstRunPaywallPresented,
                      activeSheet == .firstRunPaywall
                else { return }
                firstRunPaywallPending = false
                activeSheet = nil
            }
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
        trialPitchScheduled = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            trialPitchScheduled = false
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
        trialPitchScheduled = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            trialPitchScheduled = false
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
                case .purchased:
                    hasSeenTrialOffer = true
                    activeSheet = nil
                case .pending:
                    break
                case .cancelled:
                    trialPurchaseError = String(localized: "Trial wasn't started. Tap again, or pick a different plan.")
                }
            } catch {
                trialPurchaseError = String(localized: "Couldn't start your trial. Please try again.")
            }
        }
    }

    /// Single dismissal handler for the root promo sheet. Runs trial-purchase cleanup
    /// and the chained paywall, which must fire only after the sheet has fully
    /// dismissed. Every root sheet is a pitch, so a dismissal never leads into a
    /// rating request.
    private func handleRootSheetDismiss() {
        trialPurchaseInFlight = false
        trialPurchaseError = nil
        firstRunPaywallPending = false
        if firstRunPaywallPresented {
            // The first-run paywall was actually shown and is now dismissed — consume
            // the one-shot here so it's only spent on a sheet the user really saw. A
            // dropped present never sets this flag (its `.onAppear` never fired).
            firstRunPaywallPresented = false
            hasSeenFirstRunOffer = true
        }
        if pendingPaywallAfterTrialDismiss {
            pendingPaywallAfterTrialDismiss = false
            activeSheet = .trialPaywall
        }
    }

    /// The rating ask after a positive moment: Apple's own prompt, no question in
    /// front of it. Waits for the log animation to settle, then asks only if the
    /// screen is still clear and no permission question is open. A blocked ask
    /// keeps the moment pending in the tracker and the next moment asks.
    private func scheduleReviewRequestAfterPositiveMoment() {
        guard ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: hasCompletedOnboarding),
              !reviewPromptShownThisSession,
              isClearForReviewRequest
        else { return }

        let epoch = foregroundEpoch
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            // A foreground log may have raised the notification permission alert.
            // While that question is open, never stack the rating prompt on it. A
            // permission never asked (reminders off) does not block the ask.
            guard epoch == foregroundEpoch,
                  !reviewPromptShownThisSession,
                  isClearForReviewRequest,
                  ReviewPromptTracker.shouldRequestAfterPositiveMoment(
                      hasCompletedSetup: hasCompletedOnboarding,
                      permissionQuestionOpen: ReminderService.isRequestingAuthorization
                  )
            else { return }
            reviewPromptShownThisSession = true
            ReviewPromptTracker.markShown()
            requestReview()
        }
    }

    /// One Tap (dose logged) or Settings (export done) is in front, the app is
    /// active, no trial pitch is queued, and nothing is presented anywhere: no
    /// root promo, Home or Settings sheet, alert, or share sheet.
    private var isClearForReviewRequest: Bool {
        (selectedTab == 0 || selectedTab == 3)
            && scenePhase == .active
            && activeSheet == nil
            && !trialPitchScheduled
            && !Self.isAnythingPresented
    }

    /// Sheets and alerts from any tab present over the window's root controller.
    private static var isAnythingPresented: Bool {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .contains { $0.isKeyWindow && $0.rootViewController?.presentedViewController != nil }
    }
}

/// Screens the Patterns tab pushes by value.
enum PatternsRoute: Hashable {
    case supply
}

/// Unfolded, iOS 27.1 can float the tab bar over the leading pane's last rows.
/// An opaque band behind the bar, as tall as the bar's inset, keeps them from
/// showing through it. Drawn under the bar, which the TabView puts above its tabs.
private struct PaneBarBand: ViewModifier {
    let isOn: Bool
    /// The screen's own background, so the band reads as part of it.
    let color: Color

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if isOn {
                GeometryReader { proxy in
                    let inset = proxy.safeAreaInsets.bottom
                    color
                        .frame(height: inset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .offset(y: inset)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }
}
