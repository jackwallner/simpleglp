# Simple GLP audit823

Audit date: 2026-08-23

Audit type: fresh max-reasoning rerun, read-only repository and storefront review

Repository: `/Users/jackwallner/simpleglp`

App Store ID: `6770137909`

Bundle ID: `com.jackwallner.glp`

Product: Simple GLP, GLP-1 shot tracker for iPhone, Apple Watch, and widgets

## Scope and method

This audit covers download growth, App Store metadata, onboarding activation, first-shot value, trial starts, subscription conversion, RevenueCat configuration, native paywall behavior, ratings and feedback, website and legal consistency, release regression signals, and Cursor, Claude, and Codex documentation hygiene.

The evidence set is:

- Local source, configuration, tests, metadata, website files, Git history, and release scripts in this repository.
- A public App Store page read on 2026-08-23.
- An App Store Connect app-list snapshot from the existing signed-in Chrome session on 2026-08-23.
- A RevenueCat project inventory snapshot from the existing signed-in session on 2026-08-23.
- The user's liked-post leads recorded in the broader fleet review. Those are hypotheses and tool leads, not product evidence.

No app code, App Store Connect record, RevenueCat configuration, metadata, website, or release configuration was changed during this audit. The only intended file change is this document.

The audit deliberately does not report a defect about RevenueCat data collection, RevenueCat tracking, or the App Store privacy disclosure saying that data is not collected. That comparison was explicitly excluded from scope. RevenueCat custom-attribute recommendations below are conditional on a separate privacy and App Store disclosure decision.

## Executive assessment

Simple GLP has a strong product wedge: one-tap logging, a free core, no account setup, optional on-device HealthKit context, a widget, and an Apple Watch surface. The current public listing is live at version 1.1.0 and has a 5.0 rating from one rating. The local native paywall work is substantially more thoughtful than the historical audit in `archive/uc528.md`: it has a trial-first sheet, a full plan picker, price disclosures, restore controls, RevenueCat fallback product loading, entitlement fallbacks, and impression IDs.

The immediate growth constraint is not missing product value. It is inability to tell whether the value and purchase funnel are working, combined with several paths that can tell the user or internal analysis that a trial started when RevenueCat has not granted the entitlement. The app also asks for a six-step setup before the first shot can be logged, while the store copy says setup takes nothing. That is likely the largest activation leak to validate.

The highest-priority work for the implementing agent is:

1. Make `pending` a visible unresolved purchase state, not a successful trial or onboarding completion.
2. Do not show trial copy or fire a trial-offer impression until intro eligibility has resolved.
3. Add privacy-safe funnel instrumentation around onboarding, paywall source, trial CTA, purchase result, entitlement resolution, restore, and product-load fallback.
4. Decide whether the six-step onboarding is required before first value. Test a minimal setup path that lets the user log the first shot before optional HealthKit and notification permissions.
5. Reconcile the live listing, local 50-locale metadata, landing page version, price checker, and support subscription instructions.
6. Add an external release health source and a post-release regression watch. MetricKit currently stores diagnostic payloads locally but does not deliver them to an operator.

## Current external snapshot

| Surface | Observation | Confidence and use |
|---|---|---|
| App Store Connect app list | `Simple GLP: GLP-1 Shot Tracker`, app ID `6770137909`, version `1.1.0`, status `Ready for Distribution` in the 2026-08-23 signed-in app-list snapshot | High for the snapshot date. Recheck before implementation because ASC state changes. |
| Public App Store page | Title `Simple GLP: GLP-1 Shot Tracker`, subtitle `Free, Private Injection Log`, free download with in-app purchases, iPhone and Apple Watch availability, English language, version `1.1.0` dated 2026-08-17 | High. URL: <https://apps.apple.com/us/app/simple-glp-glp-1-shot-tracker/id6770137909> |
| Public rating | 5.0 out of 5, `1 Ratings` in the public page markup, aggregate review count 1 | High. This is strong sentiment but almost no social proof. |
| RevenueCat project | SimpleGLP project ID `a722b48d` in the signed-in project inventory | High for project identity. URL: <https://app.revenuecat.com/projects/a722b48d> |
| RevenueCat metrics | No trustworthy SimpleGLP trial, subscription, MRR, or revenue snapshot was captured in the available context | Do not infer performance. Pull a dated project export before making a revenue claim. |
| Local metadata | 50 locale directories plus `review_information`; all checked required fields are present and within limits | High. `scripts/validate-metadata.py` returned 0 failures and 3 duplicate-token warnings. |
| Local product file | Monthly `$9.99` with one-week free trial, yearly `$39.99` with one-week free trial, lifetime `$89.99` | High for the local StoreKit test configuration, not proof of live ASC pricing. |

## P0 and P1 findings

### P0-1: unresolved purchases are counted as completed trials

Evidence:

- `SimpleGLP/Services/StoreService.swift:387-407` maps any non-cancelled purchase without an active Pro entitlement to `PurchaseState.pending`.
- `SimpleGLP/Views/OnboardingView.swift:478-489` handles `.purchased` and `.pending` identically and calls `finishOnboarding()` for both.
- `SimpleGLP/Views/RootTabView.swift:405-426` handles `.purchased` and `.pending` identically, marks the trial offer seen, and dismisses the offer for both.
- `SimpleGLP/Views/SimplePaywallView.swift:547-565` does not display a user-visible pending state. It simply breaks out of the switch for `.pending` and waits for `isProUnlocked` to change.

Why this matters:

- A pending Apple transaction, a delayed RevenueCat entitlement update, or a billing approval state can be reported internally as a trial start even though the user is not yet entitled to Pro.
- Onboarding can be marked complete and the offer can be permanently suppressed while the user is still waiting for the transaction.
- This corrupts trial-start conversion analysis and can produce a poor first-run experience: the user sees a purchase confirmation, returns to a free state, and has no clear explanation.

Required fix direction:

- Preserve three explicit outcomes: `purchased`, `cancelled`, and `pending`.
- For `.pending`, keep the sheet or onboarding trial state visible, show a clear message such as `Purchase is waiting for Apple approval`, and initiate an entitlement refresh with a bounded retry.
- Only mark `hasSeenTrialOffer` or finish onboarding as a purchase-success side effect after an active `GLP Pro` entitlement or verified product ownership is observed.
- If the user chooses the free `Get Started` path, finish onboarding independently of the purchase result.
- Record `purchase_started`, `purchase_cancelled`, `purchase_pending`, `purchase_failed`, `entitlement_granted`, and `entitlement_timeout` as separate funnel states.

Acceptance checks:

- Sandbox or StoreKit test with Ask to Buy or an injected pending result leaves the trial offer open and explains the state.
- A pending result does not increment a local or RevenueCat-derived `trial_started` count.
- A delayed entitlement update unlocks Pro and dismisses the sheet exactly once.
- A failed entitlement refresh leaves a retry path and does not silently suppress the next valid offer.
- Cancelling the purchase does not finish onboarding unless the user explicitly taps `Get Started`.

### P0-2: there is no remote production crash or degraded-UX alert path

Evidence:

- `SimpleGLP/Services/DiagnosticsService.swift:5-59` subscribes to MetricKit and persists metric and diagnostic JSON files into the App Group, pruning to 20 files.
- No code in the repository uploads those files, exports them, polls an external crash provider, or emails an operator.
- The RevenueCat integration logs product and customer-info errors with `os.Logger`, but there is no remote alert or aggregate counter for product-load failures, purchase failures, entitlement timeouts, or fallback product usage.
- The release paths in `scripts/testflight.sh:19-47` and `fastlane/Fastfile:91-151` upload builds but do not establish a release baseline or run a post-release health check.

Why this matters:

- A release regression can affect users for days without a signal to the owner.
- Local MetricKit files are useful for a device-side forensic workflow but cannot detect a spike across users.
- The user explicitly wants oversight after new releases, especially for crashes and degraded flows.

Required fix direction:

- Connect MetricKit or a compatible crash and hang provider with a documented release version, build, device, OS, and country dimension. Keep all notification adapters disabled by default in the future scaffold.
- Add structured counters for `products_load_failed`, `fallback_products_used`, `trial_offer_presented`, `trial_cta_tapped`, `purchase_pending`, `purchase_failed`, `restore_failed`, `entitlement_timeout`, `widget_ingest_failed`, `watch_ingest_failed`, `health_capture_failed`, and `notification_schedule_failed`.
- Establish a release baseline for the prior 7 days and compare the first 1, 6, 24, and 72 hours after a release.
- Alert only on a minimum sample size and a relative plus absolute threshold, for example a crash-free-user drop of at least 2 percentage points and at least 20 affected users, or a 2x increase with at least 10 events. Tune after baseline data exists.

Acceptance checks:

- A synthetic crash, hang, product-load failure, and pending purchase can be identified in the provider or input fixture.
- A release report names the affected version and build and compares it to a baseline.
- A watchdog dry run emits a report without sending email or changing external state.
- Notification delivery is opt-in by explicit configuration and command-line flag.

### P1-1: trial eligibility is optimistic before RevenueCat resolves it

Evidence:

- `SimpleGLP/Services/StoreService.swift:314-328` refreshes eligibility asynchronously but `isEligibleForIntroOffer(_:)` returns `true` when no result exists yet.
- `SimpleGLP/Services/StoreService.swift:263-268` publishes `products` before `refreshIntroEligibility()` finishes.
- `SimpleGLP/Views/RootTabView.swift:69-80` treats an eligible direct trial package as soon as the product list contains one.
- `SimpleGLP/Views/RootTabView.swift:233-238` re-evaluates the offer when product count changes, which can happen before eligibility resolves.

Likely failure mode:

- A returning customer who has already used an introductory offer can briefly see `7-day free trial` and a trial-first CTA. The eligibility result can later change to ineligible.
- A user who is not eligible can receive misleading trial copy, then purchase at the normal subscription price.
- This is an inference from asynchronous ordering and the `?? true` fallback. Confirm with a returning sandbox customer and a slow or offline eligibility response.

Required fix direction:

- Add an explicit `introEligibilityResolved` state.
- Default unknown eligibility to false for presentation purposes, or keep the trial surfaces blocked until the response resolves.
- Keep `directTrialPackage` separate from `yearlyPackage`. A non-eligible yearly package must not be used by a trial-labeled surface.
- Show the full plan picker with price-forward copy when eligibility is false.
- Add a visible, testable state for product loaded, eligibility loading, eligible, ineligible, and unavailable.

Acceptance checks:

- An ineligible customer never sees a free-trial badge, trial timeline, or trial CTA.
- A slow eligibility response shows a loading state rather than optimistic trial copy.
- A product-load fallback still shows correct price and no trial claim until eligibility resolves.

### P1-2: the local ASC subscription audit script is stale and can report the wrong price state

Evidence:

- `SimpleGLP/Services/Products.storekit:6-18` defines lifetime at `$89.99`.
- `SimpleGLP/Services/Products.storekit:43-66` defines monthly at `$9.99` with a one-week free trial.
- `SimpleGLP/Services/Products.storekit:68-90` defines yearly at `$39.99` with a one-week free trial.
- `docs/index.html:30-54` publishes the same three USD prices and trial terms in structured data.
- `fastlane/metadata/en-US/description.txt:24-28` describes monthly, yearly, and lifetime plans with a seven-day trial on subscriptions.
- `scripts/asc-audit-subscriptions.py:14-18` still expects monthly `$2.99` and yearly `$19.99`, and does not verify the lifetime product.
- Git history shows the script was added on 2026-07-31, while the current product file and landing page use a different price set.

Why this matters:

- A release check can fail on a known-good price or pass against an obsolete expected price if the script is not updated with the current decision.
- The script checks subscription trial coverage but not the lifetime product, RevenueCat offering attachment, entitlement mapping, or the version of the copy presented in the app.

Required fix direction:

- Make one versioned product manifest the source for product IDs, plan type, trial duration, and intended reference price. Treat live ASC price as observed data, not a hardcoded assumption, unless the test is explicitly a policy check.
- Add lifetime existence and state checks.
- Compare the live ASC catalog, RevenueCat offering, local StoreKit file, native paywall display, metadata, and site schema in one report.
- If `$9.99`, `$39.99`, and `$89.99` are the intentional prices, update the checker and record the decision date. If the live catalog differs, decide whether the difference is regional, staged, or an error.

Acceptance checks:

- A dry run prints local and live values side by side.
- A deliberate price mismatch produces one actionable finding with product ID and source paths.
- Trial coverage is checked for both recurring products across intended territories.
- Lifetime is checked for presence, price, state, and RevenueCat entitlement mapping.

### P1-3: local metadata breadth and live storefront localization are inconsistent

Evidence:

- The repository contains 50 actual locale directories under `fastlane/metadata`, plus `review_information`.
- `fastlane/Deliverfile:3-54` lists the same broad set of locales for upload.
- The public App Store page currently reports only `English` under Languages.
- `scripts/validate-metadata.py` returned `0 failures, 3 duplicate-token warnings across 50 locales` on 2026-08-23.
- The three warnings are `id/keywords.txt` token `suntik`, `ms/keywords.txt` token `suntikan`, and `nl-NL/keywords.txt` token `injectie` already present in the corresponding name or subtitle.

Interpretation:

- The local translations may be staged, may not be attached to the live version, or may be unavailable in the US public storefront because of App Store localization rules. The repository alone cannot tell which.
- If the translations are intended to drive downloads, the live language list is a release gap. If English-only is intentional, the local metadata set is operational complexity and a source of stale copy.

Required fix direction:

- Pull the ASC app-info and version-localization records and compare their state to each local directory. Label each locale as live, staged, rejected, missing, or intentionally deferred.
- Prioritize high-download locales for native review, especially `de-DE`, `es-ES`, `fr-FR`, `ja`, and `pt-BR`.
- Remove only true duplicate keyword tokens after checking that the localized name and subtitle are the intended current source. Do not blindly delete translated terms.
- Do not claim broad localization on the landing page or in planning docs until ASC confirms it is live.

Acceptance checks:

- A machine-readable locale report lists local, ASC, and public-store state.
- At least five high-priority locales pass a native quality review.
- A metadata upload dry run shows exactly which locales would change.

### P1-4: setup delays the core value moment and asks for permissions before the first log

Evidence:

- `SimpleGLP/Views/OnboardingView.swift:25-103` defines six steps.
- The user must pass medication, schedule, reminder, and Health context screens before the final trial step.
- `SimpleGLP/Views/OnboardingView.swift:284-306` offers HealthKit context before the user has logged a shot.
- `SimpleGLP/Views/OnboardingView.swift:251-280` configures notification reminders before first value.
- `SimpleGLP/Views/OnboardingView.swift:493-536` saves the plan and only then sets `hasCompletedOnboarding`.
- The store description says setup takes nothing to set up, while the actual flow requires a six-step setup and at least a medication plan.

Why this matters:

- A user who downloaded for a quick shot log may leave before reaching the one-tap button.
- HealthKit and notification permission dialogs are high-friction requests before the user has experienced the core job.
- This is a conversion hypothesis, not a measured drop-off yet. The missing step-level funnel telemetry means the repository cannot quantify it.

Testable alternatives:

- Variant A, current six-step setup.
- Variant B, minimal setup: medication plus cadence, then first shot log. Ask about notifications after the first log and HealthKit after the user requests context.
- Variant C, one-tap demo or first shot first, then ask for the plan when the user wants schedule accuracy.

Guardrails:

- Keep the free core usable without HealthKit and without notifications.
- Never imply that the app replaces a clinician, medication label, or a prescribed schedule.
- Explain that reminders are convenience features and can fail if notifications are disabled.

Acceptance checks:

- Measure completion for each onboarding step, first shot within 10 minutes, notification prompt acceptance, HealthKit prompt acceptance, and day-one return.
- Compare trial starts per install and first-shot completion per install, not only purchase rate.
- Confirm that a user who denies either permission can still log, edit, view history, and export.

### P1-5: onboarding Pro copy promises export and pattern depth that the current free product exposes

Evidence:

- `SimpleGLP/Views/OnboardingView.swift:323-327` presents Pro bullets for patterns, `Export a clean history`, smarter reminders, and privacy.
- `SimpleGLP/Views/SettingsView.swift:61-68` exposes Export in the free Data section.
- `SimpleGLP/Views/SettingsView.swift:464-510` implements CSV export without a Pro check.
- `docs/index.html:300-307` describes export as free and says there is no lock-in.
- `docs/index.html:341-345` says everything except proactive nudges stays free, including insights and HealthKit context.
- `SimpleGLP/Views/InsightsView.swift:10-105` currently shows free schedule adherence and weekday timing. It does not show the weight, dose timing, and symptom correlations promised by the onboarding bullet.

Why this matters:

- The user can read the trial screen, enter the app, and discover that the promised paid export is already free.
- Inconsistent value framing lowers trust and makes it harder to learn which feature caused a trial start.

Required fix direction:

- Either make export an explicit free-core bullet and replace it on the trial surface with a real Pro capability, or intentionally gate a defined export enhancement while keeping the basic export promise accurate.
- Align the landing page, onboarding, paywall benefits, screenshots, and metadata from one feature entitlement matrix.
- Avoid claiming cross-domain correlations until the UI actually computes and displays them.

Acceptance checks:

- A feature matrix has one owner for each feature and a free or Pro state.
- Every paywall bullet can be reached in the current build or is clearly labeled as a planned feature.
- A new user can export from Settings without being unexpectedly blocked if export remains free.

### P1-6: trial-offer impressions can be consumed before the sheet is actually visible

Evidence:

- `SimpleGLP/Views/RootTabView.swift:353-382` sets `paywallShownThisSession`, marks the offer seen, tracks the impression, and assigns `activeSheet = .trialOffer` in the same function.
- Unlike the first-run sheet at `RootTabView.swift:144-149`, the generic trial sheet has no `.onAppear` confirmation that it was added to the hierarchy.
- The first-run path has a dropped-presentation watchdog at `RootTabView.swift:288-300`; the first-shot, existing-user, and Patterns paths do not have the same protection.

Why this matters:

- A scene transition, an unexpected system prompt, or a SwiftUI presentation race can consume the only offer and impression without the user seeing it.
- A conversion report can show an impression with no opportunity to tap.

Required fix direction:

- Move `hasSeen` and impression state transitions to a common `onAppear` or explicit presentation-confirmation callback.
- Add a timeout that resets a pending presentation only when the sheet never appears.
- Track requested, presented, dismissed, CTA tapped, and purchase outcome separately.

Acceptance checks:

- Interrupt the app with a permission or background transition at each trial trigger.
- Confirm a dropped presentation can retry on a later eligible active scene.
- Confirm a real presentation is counted once even if SwiftUI re-renders the sheet.

### P1-7: the widget promise says no app launch while the App Intent requests an app launch

Evidence:

- `SimpleGLPWidget/LogShotIntent.swift:5-19` sets `static let openAppWhenRun = true`.
- `SimpleGLPWidget/SimpleGLPWidget.swift:59-101` presents the interactive widget button.
- `docs/index.html:358-363` says the widget logs a shot directly with no app launch.
- `fastlane/metadata/en-US/description.txt:3-5` also promises widget logging and immediate timestamping.

Why this matters:

- `openAppWhenRun = true` may be intentional so the phone ingests the pending widget event, but it can visibly open the app after the tap. That contradicts the strongest acquisition promise and may feel like the widget did not work independently.

Required fix direction:

- Test the shipped widget on a physical device with the app cold, warm, terminated, and offline.
- If the app opens, either remove the launch requirement after proving reliable ingestion or change the public copy to say the shot is captured immediately and the phone may open to finish syncing.
- Add a widget success, ingest latency, and ingest failure signal. Do not count the optimistic widget timestamp as a confirmed phone-side shot until ingestion succeeds.

Acceptance checks:

- Cold phone, app terminated: tap widget, confirm exactly one ShotEvent, correct timestamp, no duplicate after relaunch.
- Offline phone: confirm the user-visible status explains where the pending record is stored and how it will sync.
- If app launch remains required, update site screenshots and copy to match observed behavior.

### P1-8: support documentation contains a removed subscription-management path

Evidence:

- `docs/support.html:40-46` tells users to open `Settings -> Manage subscription` in the app.
- `SimpleGLP/Views/SettingsView.swift:50-59` exposes `Upgrade to Pro` for non-Pro users and `Proactive alerts` for Pro users, plus `Restore purchases`, but no `Manage subscription` action.
- `SimpleGLP/Views/SettingsView.swift:70-77` links Support, Privacy Policy, and Terms of Use but does not provide a subscription-management deep link.
- Git history includes `907a1f2 feat(settings): remove Manage subscription option`, so this is a known documentation drift rather than an unknown UI path.

Required fix direction:

- Replace the stale in-app instruction with the actual Apple subscription-management path and a direct Settings URL where supported.
- Make the in-app subscription status and restore path explicit. A Pro user should understand where to cancel without searching.
- Add a support-page smoke test that checks every named in-app destination still exists.

Acceptance checks:

- A new user can follow the support page without encountering a missing button.
- A subscribed user can reach Apple subscription management from the documented path.
- Terms, support, metadata, and paywall disclosures use the same cancellation wording.

### P1-9: landing-page version and source metadata are stale relative to the live listing

Evidence:

- `docs/index.html:56-65` structured data declares `aggregateRating.ratingCount` 1 and `softwareVersion` `1.0.8`.
- The live public listing reports version `1.1.0` dated 2026-08-17.
- `docs/index.html:30-54` declares product prices that match the local StoreKit file, but live ASC prices were not independently captured in this pass.
- `.github/workflows/sync-landing-page.yml:11-57` mirrors `docs/**` into the portfolio repository on pushes to `main`, so a page can be stale in either the source repo or its mirrored host if the workflow fails.

Required fix direction:

- Make the release process update the site version and structured data from the same version manifest used by ASC.
- Treat rating count as a live value only if there is a safe, documented refresh process. Otherwise remove the aggregate rating from structured data until it can be maintained accurately.
- Smoke-test both `https://jackwallner.github.io/simpleglp/` and `https://jackwallner.com/ios/simpleglp/` after every landing-page change.
- Verify that the canonical URL at `docs/index.html:11` is intentionally the portfolio path and that the canonical page serves the same current content as GitHub Pages.

Acceptance checks:

- A release report shows binary version, ASC version, public listing version, site JSON-LD version, and landing-page mirror commit.
- A version bump cannot leave `softwareVersion` at `1.0.8` when the live app is `1.1.0`.

### P1-10: release automation can push unrelated work and has no health gate

Evidence:

- `scripts/testflight.sh:14-20` edits `project.yml`, regenerates the project, and increments the build.
- `scripts/testflight.sh:35-47` uploads to TestFlight, stages `project.yml`, commits, and pushes automatically.
- `fastlane/Fastfile:112-151` defines a `push` lane that builds, uploads, runs `git_add(path: ".")`, commits, tags, and pushes all repository changes.
- `fastlane/Fastfile:39-66` uses `force: true` for metadata upload, which increases the need for a dry-run and diff review.

Why this matters:

- An agent or developer can unintentionally include audits, screenshots, generated files, or unrelated changes in a release commit.
- A successful upload does not prove the paywall, widget, watch handoff, notification, or entitlement paths work in production.

Required fix direction:

- Split build-number mutation, build/upload, commit, and push into explicit commands with a clean-worktree or allowlist check.
- Require a release manifest containing version, build, commit, ASC app ID, RevenueCat project, expected product IDs, and test cohort.
- Run static metadata checks and a headless/device smoke matrix before upload, then run the release watchdog after processing.
- Keep the audit file out of any automatic release commit unless explicitly selected.

Acceptance checks:

- A release dry run reports every file that would be committed.
- A dirty worktree fails safely or requires an explicit allowlist.
- Upload completion is followed by a dated post-release check rather than being treated as health evidence.

## P2 findings and UX opportunities

### P2-1: native review flow has confusing state transitions and sentiment gating

Evidence:

- `SharedGLP/Services/ReviewPromptTracker.swift:35-103` requires five launches, seven days, and three positive moments in Release builds, with a 120-day cooldown.
- `SimpleGLP/Services/ShotCaptureCoordinator.swift:128-134` records a positive moment on a successful shot.
- `SimpleGLP/Views/SettingsView.swift:70-73` lets the user manually start `Rate or Send Feedback`.
- `SimpleGLP/Views/ReviewPromptSheet.swift:90-218` asks whether the user is enjoying the app, sends the positive path to a direct App Store write-review URL, and sends the negative path to a mail composer.
- `SimpleGLP/Views/RootTabView.swift:474-480` schedules the native `requestReview()` prompt after the user chooses `Maybe later` in the review pitch.
- `SharedGLP/Utilities/AppStoreReviewLinks.swift:5-15` uses the correct current app ID `6770137909`.

Risks and opportunities:

- The user who taps `Rate on the App Store` is sent out of the app, while the user who taps `Maybe later` can receive the native review prompt immediately after dismissal. Those outcomes are semantically reversed and should be tested for user surprise.
- `ReviewPromptTracker.outcome` prevents the passive funnel from showing again after a review or feedback outcome, which is reasonable for consent and annoyance control, but it also limits future review velocity.
- The current live rating count is one, so every legitimate, non-coerced review has high discovery value. Do not ask for a positive rating in exchange for a feature or hide support from dissatisfied users.

Recommended experiment:

- Variant A, current custom enjoyment sheet followed by native `requestReview()` on an explicit positive choice.
- Variant B, no custom sentiment gate: call the native API only after the same objective value thresholds and keep an unconditional Settings feedback row.
- Keep the explicit App Store URL only for a user-initiated Settings action if it is retained.

Acceptance checks:

- The review path is understandable when VoiceOver is enabled and when the native prompt is suppressed by Apple.
- No review prompt appears during an active purchase, permission dialog, error, or first-shot confirmation.
- Ratings, feedback launches, and prompt suppression are measured locally or through an approved privacy-safe system.

### P2-2: paywall animation does not honor Reduce Motion

Evidence:

- `SimpleGLP/Views/TrialOfferSheet.swift:24-25` reads `accessibilityReduceMotion` and suppresses animation at `294-299`.
- `SimpleGLP/Views/SimplePaywallView.swift:294-298` starts the glow and shimmer animations without reading `accessibilityReduceMotion`.
- The full paywall also contains a shimmer overlay at `SimpleGLP/Views/SimplePaywallView.swift:368-385`.

Required fix direction:

- Apply the same Reduce Motion behavior to the full paywall and ensure the animation does not restart on every product or state update.
- Test Dynamic Type at accessibility sizes. Several paywall and trial strings use fixed system sizes, line limits, and minimum scale factors, so the legal disclosure and plan prices need visual verification at large text sizes.

### P2-3: the paywall has good disclosure structure but needs controlled learning around layout and default selection

Evidence:

- `SimpleGLP/Views/SimplePaywallView.swift:12-22` documents a personalized hero, benefit rows, yearly-first plan order, savings anchoring, trial CTA, and Apple billing disclosure.
- `SimpleGLP/Views/SimplePaywallView.swift:292-325` orders yearly, monthly, lifetime, and other packages.
- `SimpleGLP/Views/SimplePaywallView.swift:421-460` computes the CTA and disclosure from the selected package.
- `SimpleGLP/Views/SimplePaywallView.swift:472-515` computes the yearly per-month and savings labels from live localized prices.
- `SimpleGLP/Views/SimplePaywallView.swift:547-565` keeps the selected package state local to the sheet.

Strengths:

- Prices are localized from StoreKit rather than hardcoded in the native view.
- The selected plan is visible, the trial length is named, a renewal disclosure is present, and restore is available.
- The fallback product path means a missing RevenueCat offering does not automatically make the paywall empty.

Learning gaps:

- There is no event for plan-card selection, CTA tap, disclosure visibility, close, restore start, restore result, product fallback, or purchase result.
- A yearly-first default and a lifetime option change both conversion and revenue mix. They should not be changed simultaneously with copy or funnel timing.
- The `SAVE` badge is computed from monthly price and yearly price. Confirm rounding and the phrase in every storefront, especially where tax-inclusive prices or currency precision differ.

### P2-4: HealthKit permission breadth may reduce activation

Evidence:

- `SimpleGLP/Services/HealthKitService.swift:10-34` requests read access for body mass, glucose, steps, active energy, exercise, heart rate, resting heart rate, glucose, sleep, workouts, water, caffeine, dietary energy, and protein.
- `SimpleGLP/Views/OnboardingView.swift:284-306` presents this as an onboarding step.
- `SimpleGLP/Services/HealthKitService.swift:72-87` correctly treats unavailable or empty data as optional and does not block shot logging.

Recommended direction:

- Test a delayed, purpose-specific authorization prompt after first value. Explain exactly which context will be shown and let a user choose a smaller set if the product supports it.
- Keep the current non-blocking behavior for denied, empty, stale, or unavailable HealthKit data.
- Do not send raw HealthKit values, medication names, doses, symptoms, or injection details as RevenueCat attributes. Any future instrumentation must use coarse funnel state only and be reviewed separately for privacy and App Store disclosure.

### P2-5: reminder and proactive-alert failure states are mostly local and silent

Evidence:

- `SimpleGLP/Services/ReminderService.swift:12-32` schedules a local reminder and ignores `UNUserNotificationCenter.add` errors with `try?`.
- `SimpleGLP/Services/ProactiveAlertsEngine.swift:79-94` requests notification authorization, schedules late-dose nudges, and ignores add failures with `try?`.
- `SimpleGLP/Views/SettingsView.swift:190-208` explains denied notifications only inside the plan editor.
- `SimpleGLP/Views/ProAlertsConfigView.swift:27-35` displays a permission status and offers a test alert, which is a good foundation.

Recommended direction:

- Surface a non-blocking status after onboarding and in the main Settings row when reminders are enabled but permission is denied or scheduling fails.
- Record schedule attempts, permission state, add errors, and test-alert results.
- Add a regression test for a fire date in the past, a quiet-hours boundary, a daylight-saving transition, and a user who changes cadence after a reminder is scheduled.

### P2-6: current free and Pro feature names need one entitlement matrix

Evidence:

- Free Insights in `SimpleGLP/Views/InsightsView.swift:13-105` has a five-shot threshold and shows adherence and timing.
- Pro pattern detection in `SimpleGLP/Services/ProactiveAlertsEngine.swift:19-55` has a six-shot minimum and schedules local notifications.
- `SimpleGLP/Views/InsightsView.swift:137-173` shows blurred preview cards with static examples, including a 12-shot claim.
- `docs/index.html:290-313` calls adherence and timing free and proactive alerts Pro.

Recommended direction:

- Create a small feature entitlement table used by onboarding, paywall, site, metadata, screenshots, and review notes.
- Make sample preview copy clearly illustrative when the user has fewer than the sample size.
- Name the exact Pro behavior: late-dose nudge, pattern notification, quiet hours, or a future correlation view. Avoid implying medical outcomes.

## Funnel map and measurement plan

### Current user journey

| Stage | Current implementation | Primary risk | Minimum measurement |
|---|---|---|---|
| Store impression | App Store title, subtitle, screenshots, description, website | English-only public listing and stale site version | Product-page views, source, locale, download rate |
| First launch | `SimpleGLPApp.init`, `StoreService.start`, onboarding | RevenueCat resolution and product loading happen in parallel | Launch, onboarding start, product-load state |
| Setup | Six-step `OnboardingView` | Permission and configuration friction before first shot | Step viewed, step completed, exit step |
| Trial offer in onboarding | Final step, direct eligible package, `Start 7-day free trial` | Unknown eligibility and pending purchase handling | Offer rendered, eligible, CTA tap, purchase outcome |
| Free activation | `Get Started`, plan saved, `hasCompletedOnboarding` | User may not see a one-tap value moment until after setup | Free setup completion, first shot within 10 minutes |
| First shot | Home button, widget, watch, `ShotCaptureCoordinator` | Health enrichment is async, widget may open app | Shot saved, capture status, source, latency |
| First-shot trial offer | Root notification after four seconds | Offer can be consumed before presentation | Requested, visible, dismissed, CTA, outcome |
| Patterns | Free adherence and timing, locked Pro preview | Offer depends on tab visit and product state | Patterns visit, preview tap, plan selection |
| Settings upgrade | Upgrade button or restore | Support says a missing Manage subscription path | Upgrade entry, restore start, restore outcome |
| Paid activation | RevenueCat purchase, entitlement, Pro alerts | Pending and entitlement lag are not separated | Entitlement active, trial start, trial convert, expiration |
| Retention | Reminders, watch, widget, alerts, export, review prompt | No remote degraded-UX signal | Day 1, 7, 30 return, scheduled notification success |

### Events and attributes to add carefully

The code currently has only `trackCustomPaywallImpression` in `StoreService.swift:371-384`, with IDs such as:

- `simpleglp_onboarding_trial`
- `simpleglp_first_run`
- `simpleglp_trial_offer_first_shot`
- `simpleglp_trial_offer_existing_user`
- `simpleglp_trial_offer_patterns`
- `simpleglp_trial_sheet`
- `simpleglp_insights_sheet`
- `simpleglp_settings_sheet`

These IDs are useful but do not form a complete funnel. RevenueCat custom attributes are persistent customer fields, not an event stream. If the product owner approves the data and disclosure changes, use a small wrapper around `Purchases.shared.setAttributes` in `StoreService.swift` and update only coarse, non-health funnel state:

| Attribute | Set or update at | Example values | Why |
|---|---|---|---|
| `app_version` | `StoreService.start()` | `1.1.0` | Segment release regressions |
| `build_number` | `StoreService.start()` | `43` | Separate build from marketing version |
| `locale` | `StoreService.start()` | `en-US` | Compare localization cohorts |
| `onboarding_state` | `OnboardingView.finishOnboarding()` | `started`, `completed`, `skipped_offer` | Activation analysis |
| `paywall_source` | Before each impression in `RootTabView`, `InsightsView`, or `SettingsView` | `onboarding`, `first_shot`, `patterns`, `settings` | Attribute purchase context |
| `paywall_variant` | Immediately before the visible paywall | `trial_first_a`, `plans_first_b` | Read the last exposed variant |
| `trial_eligibility_state` | After RevenueCat eligibility resolves | `eligible`, `ineligible`, `unknown`, `unavailable` | Explain trial display and conversion |
| `shot_count_bucket` | On paywall entry | `zero`, `one`, `two_to_five`, `six_plus` | Value-moment segmentation without raw health data |
| `purchase_context` | Immediately before purchase | `onboarding_trial`, `first_shot_trial`, `plans` | Last purchase intent |
| `last_purchase_state` | After result | `purchased`, `cancelled`, `pending`, `failed` | Operational visibility |

Do not use RevenueCat attributes for medication name, dose, symptoms, injection site, weight, glucose, sleep, HealthKit values, notes, or free-form feedback. Do not treat an attribute update as a conversion event. If a reliable event stream is needed, add a separate approved, privacy-reviewed funnel event mechanism or export the local state machine for testing.

Recommended insertion points:

1. `StoreService.start()`: set version, build, locale, and initialize a resolved-state machine.
2. `OnboardingView.handleTrialStepAppear()` and `finishOnboarding()`: record offer rendered and onboarding completion only after actual presentation or completion.
3. `RootTabView.presentTrialOfferIfReady(source:)`: set the source after eligibility and presentation confirmation, not before.
4. `SimplePaywallView.task`: set the surface ID and variant before `trackPaywallImpression`.
5. `StoreService.purchase(_:)`: set purchase context before the SDK call and persist the exact result afterward.
6. `StoreService.updateCustomerProductStatus` and the RevenueCat delegate: record entitlement resolution and transition latency.
7. `restorePurchases()`: record restore start, success, not-found, and error separately.

## RevenueCat and StoreKit audit

### Product and entitlement matrix

| Plan | Product ID | Local test price | Trial | Code path |
|---|---|---:|---|---|
| Lifetime | `com.jackwallner.glp.pro.lifetime` | `$89.99` | None | Non-consumable, `StoreService.swift:5-9` |
| Monthly | `com.jackwallner.glp.pro.monthly` | `$9.99` | One week | Auto-renewing, `Products.storekit:43-66` |
| Yearly | `com.jackwallner.glp.pro.yearly` | `$39.99` | One week | Auto-renewing, `Products.storekit:68-90` |

Configured entitlement: `GLP Pro`, `StoreService.swift:26-32`.

Fallback entitlements retained for historical customers: `SimpleGLPPro` and `pro`.

Offering resolution: `default`, then RevenueCat `current`, then the first non-empty offering, `StoreService.swift:176-187`.

Fallback product resolution: direct product fetch by ID when the offering is empty or unavailable, `StoreService.swift:249-312`.

The fallback is valuable resilience, but it can hide a broken RevenueCat dashboard. Treat `usingFallbackProducts == true` as a release-health finding and alert the owner in the report even when the user can still purchase.

### External configuration checks for the implementing agent

Verify in RevenueCat and ASC before changing prices or testing conversion:

- RevenueCat project `a722b48d` is connected to bundle ID `com.jackwallner.glp`.
- Offering `default` contains all three intended products.
- `GLP Pro` entitlement contains lifetime, monthly, and yearly products.
- Fallback entitlement names are still needed and do not mask a product mapping error.
- Monthly and yearly products are approved or in the correct live state for version 1.1.0.
- One-week introductory offers exist in all intended priced territories.
- Live USD prices are compared with the local product decision. Do not assume the local StoreKit file is the live catalog.
- Restore returns the same Pro state as a fresh customer-info fetch.
- A trial purchase, an ineligible account, a cancelled purchase, a pending purchase, and an expired subscription each produce a distinct local state.
- RevenueCat experiment or offering-experiment state is exported with a date, enrollment, variant, and sufficient sample size. No reliable SimpleGLP experiment result was present in the available context.

### Purchase-flow edge cases

Test the following on a physical device or an approved sandbox configuration, never with the production key on a simulator:

1. Offerings load normally.
2. Offerings are empty and direct product fallback succeeds.
3. Offerings and direct products both fail.
4. Eligibility is delayed.
5. The user is trial eligible.
6. The user has already used the introductory offer.
7. Apple purchase is cancelled.
8. Apple purchase is pending.
9. RevenueCat returns customer info without the configured entitlement but with verified product ownership.
10. A subscription expires or enters a grace or billing-retry state.
11. Restore succeeds on a new install.
12. Restore finds no purchase.
13. A Pro customer opens the app during entitlement resolution and is not shown a promo sheet.

## Native paywall A/B backlog

The current paywall is a custom SwiftUI native paywall, not a RevenueCat-hosted visual paywall. Use RevenueCat offering experiments for product, price, and trial policy tests, and use a small local variant enum for copy, timing, and layout tests. Never run more than one major variable change in the same cohort.

| Test | Control | Variant | Primary metric | Guardrails |
|---|---|---|---|---|
| Trial timing | Onboarding trial step only | First-shot trial sheet after value confirmation | Trial starts per install | First-shot completion, dismiss rate, refund or complaint rate |
| Trial surface | Full plan stack | One-decision yearly trial sheet with `See all plans` | Trial CTA to trial start | Purchase cancellation, pending rate, plan mix |
| First plan | Yearly selected | Monthly selected or no default | Paid conversion and net revenue per install | Trial-to-paid, lifetime cannibalization |
| Plan order | Yearly, monthly, lifetime | Lifetime, yearly, monthly | Net revenue per paywall impression | Trial starts, annual share, refund rate |
| Hero | Personalized shot count and adherence | One clear dose-day outcome | CTA tap rate | Close rate, trust feedback |
| Benefits | Alerts, drift, privacy | One primary outcome plus proof | Paywall-to-purchase | Support contacts and review sentiment |
| Pricing anchor | Savings badge and per-month anchor | Plain price with no anchor | Net revenue per visitor | Refunds, cancellations, complaints |
| CTA copy | `Start My 7-Day Free Trial` | `Try Pro for 7 Days, Then $X / Year` | CTA tap and purchase completion | Apple disclosure comprehension |
| Permission timing | HealthKit and notifications in setup | Permission after first shot | Onboarding completion | HealthKit and notification acceptance |
| Patterns entry | Locked preview tap | Explicit `See Plans` button plus preview | Patterns-to-paywall conversion | Patterns engagement, not just taps |

Instrumentation requirements for each test:

- `variant_requested`, `variant_presented`, `variant_dismissed`, `plan_selected`, `cta_tapped`, `purchase_result`, `entitlement_active`, `trial_converted`, `restore_result`.
- Store source, app version, build, locale, product ID, trial eligibility state, and shot-count bucket.
- Do not send raw medication, dose, symptom, HealthKit, or free-text feedback values to RevenueCat.
- Set a minimum sample size and a fixed analysis window before declaring a winner.
- Stop a variant if crash-free users, purchase error rate, entitlement unlock latency, or support complaints degrade.

## Ratings, feedback, and social proof

Current state:

- Public App Store state is 5.0 with one rating.
- `ReviewPromptTracker` waits for five launches, seven days, and three positive moments in Release builds.
- Positive moments currently include successful shot capture and successful CSV export.
- The prompt has a 120-day cooldown and stores a terminal outcome.
- Settings has a manual `Rate or Send Feedback` entry.
- The current App Store deep link uses the correct app ID.

Recommendations:

- Keep the objective value gate, but test whether three positive moments is too slow for a weekly app. A user may not reach three in the first month.
- The best automatic moment is after a successful first or second completed shot and a calm return to the Home screen, not during the capture banner, HealthKit enrichment, purchase, or permission flow.
- Keep a visible feedback path for unhappy users, but make the labels and post-dismiss behavior semantically consistent.
- Track prompt shown, prompt suppressed, feedback opened, and App Store link opened without treating an App Store link open as a review.
- Use the public one-rating state as a reason to prioritize review velocity, not as a reason to pressure users.

Validation scenarios:

- First shot with HealthKit still enriching.
- Third positive moment after export.
- User chooses `Not really`, submits feedback, and returns.
- User chooses `Yes`, then taps `Rate on the App Store`.
- User chooses `Maybe later` and sees whether a native prompt appears unexpectedly.
- User uses the Settings row after an earlier terminal outcome.

## Download and ASO analysis

### Current en-US metadata

| Field | Local value or measurement | Assessment |
|---|---|---|
| Name | `Simple GLP: GLP-1 Shot Tracker`, 30 characters | Matches the live title and uses the core intent. |
| Subtitle | `Free, Private Injection Log`, 27 characters | Matches the live subtitle and communicates the free and privacy wedge. |
| Keywords | `ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,peptide,weekly,reminder,dose,compounded`, 96 characters | Strong intent coverage, but validate trademark and guideline posture before keeping every brand term. |
| Promotional text | `Log every GLP-1 shot in one tap. Free, private, and it reminds you before the next one is due.`, 94 characters | Clear core action; could use Apple Watch and widget differentiation in a controlled test. |
| Description | 2,199 characters | Detailed and compliant in the current text. It includes subscription terms and a medical disclaimer. |
| Category | `HEALTH_AND_FITNESS` | Consistent with the public category snapshot. |
| Marketing URL | GitHub Pages site | Must remain synchronized with the portfolio mirror. |
| Privacy URL | `https://jackwallner.github.io/simpleglp/privacy-policy.html` | Live local legal page path. |
| Support URL | `https://jackwallner.github.io/simpleglp/support.html` | Contains the stale Manage subscription instruction described above. |

Metadata opportunities:

- Use screenshots and promotional text to own the product's strongest wedge: one-tap, widget, and Apple Watch capture. The current description contains these, but the subtitle does not.
- Test a Watch or widget-led promotional message against the privacy-led message. The liked-post ASO material suggests measuring keyword rank, impression share, and conversion together rather than optimizing only keyword position.
- Keep generic drug terms and use trademarks only after reviewing current Apple policy and the app's nominative use. Do not make a medical efficacy claim.
- Add a metadata lint rule that detects duplicate keyword tokens in each locale, compares local character counts to ASC limits, and checks that URLs return the expected page title and status.
- Maintain a single source for the feature matrix and subscription terms so a description update cannot diverge from the paywall or site.

### Live and local consistency checks

- Live title and subtitle match the current en-US source.
- Live public language is English only while local metadata includes 50 locales. This is the largest storefront consistency gap.
- Live public version is 1.1.0 while site JSON-LD still says 1.0.8.
- Local release notes and live release notes for 1.1.0 match the current copy after the public page was read. Keep the version-history check in the scanner.
- Local product prices and site schema match each other, but live ASC price parity remains unverified.
- The site advertises free export, while onboarding's Pro bullet describes export as a Pro benefit.
- The support page advertises a missing in-app subscription management screen.
- Legal pages were updated August 17, 2026 and disclose Apple and RevenueCat purchase verification. No RevenueCat disclosure mismatch is raised here by scope request.

## Website, terms, and privacy consistency

### Landing page

Source: `docs/index.html`.

Strengths:

- App ID `6770137909` and App Store links are consistent.
- The landing page explains one-tap logging, schedule, history, optional HealthKit context, widget, watch, export, privacy, and Pro alerts.
- The page includes clear non-medical language and does not claim to diagnose, treat, cure, or prevent a condition.
- The GitHub Pages to portfolio mirror workflow is explicit and scoped to this app's page.

Findings:

- JSON-LD `softwareVersion` is stale at `1.0.8`.
- JSON-LD prices should be verified against live ASC, especially after price changes.
- The canonical URL points to `https://jackwallner.com/ios/simpleglp/` while the metadata URLs point to GitHub Pages. Confirm both are healthy and content-equivalent.
- The page says the widget requires no app launch, while the App Intent sets `openAppWhenRun = true`.
- The page says export is free while onboarding suggests export is a Pro feature.
- The page has an English-only experience even though local metadata planning is broad.

### Terms and privacy

Sources: `docs/privacy-policy.html`, `docs/terms.html`, `SimpleGLP/Views/SimplePaywallView.swift`, `SimpleGLP/Views/TrialOfferSheet.swift`, `SimpleGLP/Views/OnboardingView.swift`, and `SimpleGLP/Views/SettingsView.swift`.

Strengths:

- The legal pages are dated August 17, 2026.
- The Terms include the Apple Standard Licensed Application EULA.
- The Terms say prices, periods, and any trial are shown before purchase.
- The app and legal pages consistently avoid medical advice, diagnosis, and treatment claims.
- The privacy page describes local SwiftData, UserDefaults, App Group, HealthKit handling, Apple purchases, and RevenueCat purchase verification.

Consistency opportunity:

- Onboarding and the native paywall label the Terms link with `PaywallLinks.standardEULA`, which goes directly to Apple's standard EULA.
- Settings labels its local legal link `Terms of Use` and routes to `PaywallLinks.termsOfUse`, which goes to `docs/terms.html`.
- This is defensible because the local Terms incorporate Apple's EULA, but the two purchase surfaces do not present the same legal destination. Use explicit labels such as `Terms of Use` and `Apple Standard EULA`, or make the product's intended primary terms route consistent everywhere.
- Keep the RevenueCat privacy explanation synchronized with any future customer-attribute instrumentation. This is a follow-up boundary, not a finding in this audit.

## Production regression and watchdog signals

### Signals already available in code

- MetricKit metrics and diagnostic payloads: `SimpleGLP/Services/DiagnosticsService.swift:11-34`.
- Product loading and fallback path: `StoreService.swift:249-312`.
- Entitlement fetch error: `StoreService.swift:410-425`.
- Restore error and not-found state: `StoreService.swift:429-445`.
- Purchase cancellation and unresolved state: `StoreService.swift:387-407`.
- Shot capture save failure, HealthKit enrichment failure, and partial capture: `ShotCaptureCoordinator.swift:93-194`.
- Watch request ingestion: `PhoneWatchSession.swift:61-78`.
- Widget pending-shot queue: `SimpleGLPWidget/LogShotIntent.swift:10-19` and `GLPAppGroup.swift`.
- Notification permission and scheduling: `ReminderService.swift:12-55` and `ProactiveAlertsEngine.swift:40-180`.

### Signals the future MacBook watchdog should ingest

The repository-level watchdog requested for the broader fleet should accept normalized JSON or CSV from these sources:

1. ASC app analytics and App Store acquisition, product-page, subscription, retention, and crash or hang data where available.
2. RevenueCat customer, transaction, entitlement, offering, and experiment exports.
3. MetricKit diagnostic or metric payload exports from devices or a remote provider.
4. Release manifest with app ID, bundle ID, version, build, commit, upload time, and rollout window.
5. Local scanner results for metadata, URL, product-ID, paywall, privacy, agent-doc, and release-script drift.

The report should flag:

- Crash-free users or sessions below baseline.
- New crash or hang signatures after a version or build change.
- Launch-time failures, widget and watch ingestion failures, and repeated HealthKit capture failures.
- Product-load failures, fallback-product usage, purchase cancellations, pending durations, entitlement timeouts, restore failures, and trial-start drops.
- A sudden paywall impression increase with no product availability.
- A sudden trial-start increase without entitlement activation, which can reveal false attribution.
- Rating count drops, rating-average changes, or negative review clusters after a release.
- ASC public version or language drift from local metadata and site schema.

Do not send notifications from the scaffold by default. The future script should support `--dry-run`, a config file, JSON and Markdown reports, and explicitly gated email or webhook adapters.

## Agent documentation hygiene

### Current good structure

- Root `CLAUDE.md` is short and app-specific.
- Root `AGENTS.md` is a symlink to `CLAUDE.md`, so Claude Code and Codex see one canonical guide.
- The guide identifies the XcodeGen project, scheme, simulator lease owner, shared iOS skill, and subagent limits.
- `README.md` is a human-facing product and build overview.
- `archive/README.md` explicitly says archived notes are historical and not current instructions.

### Documents that can confuse an agent

| Path | Evidence of staleness or scope | Recommended handling |
|---|---|---|
| `archive/uc528.md` | 2026-05-28, build 21, version 1.0.0, says the paywall is hidden and recommends adding post-onboarding and first-shot offers that now exist | Keep as historical audit, but add a dated index or move under `docs/audits/archive/` so search results do not look like current work. Do not carry its old Easy GLP, price, or paywall findings forward. |
| `archive/forcursor.md` | Historical setup guide; test command uses a named simulator destination and it contains old TODOs | Keep archived. Create one current agent guide later with headless simulator instructions and current release rules. |
| `archive/ONBOARDING.md` | Claude onboarding prompt with personal usage statistics and TODO placeholders | Keep outside the agent instruction path. It is not a reliable operational guide. |
| `aso-plan.md` | Updated 2026-06-26 and contains future v1.0.2 tasks, earlier ranking snapshots, and old rollout language | Move to dated ASO history or add a current status header and link from a maintained ASO plan. |
| `docs/aso-keyword-strategy.md` | Data snapshot 2026-06-09 and prelaunch framing | Keep as strategy history or mark the current winning terms and next review date. |
| `docs/localization-aso.md` | Describes 50 ASC locales as an active state while public App Store currently reports English only | Add local versus live status and an owner before relying on it for release work. |
| `ios27SimpleGLP.md` | Dated runtime audit from 2026-08-05, not a current release health report | Move to `docs/audits/2026-08-05-ios27.md` or add an explicit historical banner. |
| `claude-design/README.md` and related handoff files | Design-session instructions and generated assets, not current product or release rules | Keep in the design directory and make the root agent guide point there only when design work is requested. |

### Current guide gaps for Cursor, Claude, and Codex

- There is no single current agent-facing map of the purchase state machine, product manifest, live ASC and RevenueCat IDs, or release health checks.
- The app guide says to use the shared `ios-dev` skill but does not describe the current headless simulator pool or the explicit rule not to use the production RevenueCat key on a simulator. Those rules exist globally, but repeating the app-specific risk would prevent mistakes.
- The release guide does not warn that `scripts/testflight.sh` and the `fastlane push` lane commit and push automatically.
- There is no current documentation of the widget pending queue, watch transfer behavior, or the requirement to test cold, warm, offline, and terminated states.

Recommended future layout:

```text
CLAUDE.md                 canonical short agent entrypoint
AGENTS.md                 symlink to CLAUDE.md
README.md                 human product and setup overview
docs/agent-guide.md       current runtime, purchase, release, and test map
docs/product-matrix.md    free versus Pro entitlement source of truth
docs/release-health.md    release checklist and watchdog inputs
docs/audits/              dated audit outputs
docs/handoffs/            active handoffs only
archive/                  historical material, never current instructions
```

Do not make these documentation moves as part of this audit. The implementing agent should move or rename files only after checking links and current worktree changes.

## Useful leads from the user's liked posts

These are external leads observed in the user's likes. They are not evidence that a tactic will work for Simple GLP.

| Lead | How to use it for Simple GLP | Source |
|---|---|---|
| ASO and paid-UA skill collection | Adapt the keyword, screenshot, and paid acquisition checklists into the scanner, but validate every suggestion against ASC data | <https://github.com/appeeky/ua-skills> |
| App Store screenshot tooling | Evaluate a reproducible screenshot bundle with exact App Store sizes, locale variants, and a checked-in manifest | <https://github.com/ParthJadhav/app-store-screenshots> |
| Apple Search Ads impression-share and keyword-rank discussion | Use impression share, search-term popularity, product-page conversion, and download conversion together. The liked post's percentages are not a SimpleGLP benchmark | <https://x.com/kedytcom/status/2091479387958866254> |
| Navigation simplification A/B test claim | Test one feature first versus exposing all four tabs in a controlled cohort. The liked post's reported revenue lift is a hypothesis, not a result for this app | <https://x.com/carlmonkft/status/2091037062971412944> |
| Apple Retention Messaging API lead | Investigate as a future win-back channel after entitlement and cancellation states are reliable. Do not build a message campaign on false pending conversions | <https://x.com/MarioSaputra/status/2089407941644534062> |

## Prioritized implementation backlog

### Do first

1. Fix pending purchase handling in `StoreService`, `OnboardingView`, `RootTabView`, and `SimplePaywallView`.
2. Add resolved intro eligibility state and block trial copy until it is known.
3. Verify live ASC and RevenueCat product mappings, price, trial, entitlement, and offering state.
4. Add a product and entitlement manifest and repair `scripts/asc-audit-subscriptions.py`.
5. Add the minimum funnel state machine and paywall-source measurements.
6. Reconcile the live language list with the 50 local metadata locales.
7. Correct support's missing Manage subscription instruction and the landing-page version.
8. Run the widget and watch cold, warm, terminated, offline, and duplicate-ingestion tests.

### Do next

1. Test minimal setup versus six-step setup with first-shot activation as the primary metric.
2. Align onboarding Pro bullets with the free versus Pro entitlement matrix.
3. Add Reduce Motion support to the full paywall and verify Dynamic Type and VoiceOver.
4. Repair the review-flow state semantics and measure prompt outcomes.
5. Add release manifest, crash and hang source, post-release baseline, and dry-run watchdog reporting.

### Defer until measurement is trustworthy

1. Price or lifetime changes.
2. Yearly versus monthly default changes.
3. Major paywall copy rewrites.
4. Retention messaging or win-back campaigns.
5. Broad localization expansion or removal.

## Validation runbook for the implementing agent

### Static repository checks

```bash
python3 scripts/validate-metadata.py
git diff --check
git status --short
```

Add scanner checks for:

- Product IDs across `StoreService.swift`, `Products.storekit`, ASC, RevenueCat, and metadata copy.
- Price and trial durations across local StoreKit, site JSON-LD, metadata, and live catalogs.
- App ID and bundle ID across review URLs, site links, App Store metadata, and Xcode settings.
- URLs, page titles, update dates, and support instructions.
- `openAppWhenRun`, widget and watch bundle IDs, App Group IDs, and pending-event identifiers.
- `pending` purchase branches and any branch that marks trial or onboarding complete.
- `setAttributes` or future telemetry additions that include health or medication fields.
- `MetricKit` payload storage with no remote sink.
- Agent docs with dates, named simulator destinations, old versions, old product prices, or stale TODOs.

### Funnel smoke matrix

1. Fresh install, no permissions, no network.
2. Fresh install, notification denied.
3. Fresh install, HealthKit denied.
4. Fresh install, both permissions granted.
5. Complete setup with `Get Started` and log a shot.
6. Complete setup with eligible yearly trial.
7. Complete setup with ineligible subscription account.
8. Cancel trial purchase.
9. Pending purchase.
10. RevenueCat offering empty, direct product fallback succeeds.
11. RevenueCat and direct product fetch both fail.
12. Existing Pro customer launches during entitlement resolution.
13. First shot, then wait for the four-second trial offer.
14. Patterns tab on a later session.
15. Settings upgrade and restore.
16. Widget tap when the phone app is terminated.
17. Watch tap when the phone is unreachable.
18. Duplicate widget or watch event delivery.
19. HealthKit returns empty, stale, partial, and failed data.
20. Notification schedule around quiet hours and daylight-saving changes.

For every case record screen state, CTA text, product ID, displayed price, trial claim, entitlement state, and whether the user can continue with the free core.

### Release regression gate

Before a production release:

- Run metadata and URL checks.
- Confirm the generated Xcode project matches `project.yml` without committing unrelated files.
- Use the shared headless simulator pool for non-purchase UI and unit tests. Never configure the production RevenueCat `appl_` key for a simulator run.
- Use a physical device or approved sandbox account for Apple purchase flows.
- Verify app, widget, watch, and App Group entitlements.
- Upload a release manifest and capture the ASC processing state.
- After release, compare crash, hang, launch, product-load, entitlement, trial, restore, rating, and download signals at 1, 6, 24, and 72 hours.

## Bottom line

The product proposition is clear and the current native purchase UI has a good foundation. The urgent work is correctness and observability: a pending transaction must never be counted as a completed trial, trial copy must not precede eligibility, and a production release must have a remote signal when users cannot launch, log, purchase, restore, or receive a promised reminder. Once those are fixed, test minimal setup versus the current six-step onboarding and use the public Watch, widget, and privacy wedge to improve downloads without changing the free core prematurely.

## Activity and success context, 2026-08-23

Classification: **low-scale monetizing**. Confidence: **medium**. Trend: **no ASC comparison displayed**.

ASC release state: `iOS 1.1.0 Ready for Distribution`. ASC evidence: [Analytics Overview](https://appstoreconnect.apple.com/apps/6770137909/analytics/overview?dateSpec=d90), selected range `dateSpec=d90`.
RevenueCat evidence: [Project Overview](https://app.revenuecat.com/projects/a722b48d/overview), production mode, selected range `Last 28 days, 2026-07-27 through 2026-08-23`.

### Observed activity

| Source | Metric | Value | Window or comparison |
| --- | --- | ---: | --- |
| ASC | First-time downloads | 43 | 90-day Analytics Overview |
| ASC | Redownloads | 2 | 90-day Analytics Overview |
| ASC | Conversion rate | 1.04% | comparison not displayed |
| ASC | Proceeds | $2 | 90-day Analytics Overview |
| ASC | In-app purchases | 2 | 90-day Analytics Overview |
| RevenueCat | New customers | 33 | last 28 days |
| RevenueCat | Active customers | 36 | last 28 days |
| RevenueCat | Active trials | 0 | current total |
| RevenueCat | Active subscriptions | 0 | current total |
| RevenueCat | MRR | $0 | current total |
| RevenueCat | Revenue | $0 | last 28 days |

A missing value above means the source did not expose that metric in this read-only snapshot. It is not a zero.

### Interpretation and implementation focus

Simple GLP has 43 ASC first-time downloads, 33 RevenueCat new customers, 2 ASC in-app purchases, and no current RevenueCat subscription or revenue card. The product has activity and a small purchase signal, but no stable recurring funnel. Prioritize first log, reminder value, trial eligibility, and purchase-state instrumentation, while keeping health claims complementary and non-diagnostic.

The deterministic classifier recommends: Protect the current paid path, then use release and cohort baselines to decide whether acquisition or conversion is the next constraint.

- Join ASC first-time download, first launch, first value, paywall shown, offer loaded, trial started, trial canceled, trial converted, entitlement active, restore, and purchase failure events with the app version and build.
- Keep ASC's 90-day acquisition and proceeds window separate from RevenueCat's 28-day customer and revenue window. Do not calculate a conversion rate by dividing values from different windows.
- Use a mature trial cohort and a minimum sample before choosing a native paywall or onboarding A/B winner. Record the offering identifier, package, placement, experiment variant, and build.
- Put the app's classification and the next baseline date in the release handoff so Cursor, Claude, and Codex do not optimize from an old qualitative audit.

### Boundary on success or death

This snapshot supports the label **low-scale monetizing**, not a lifetime verdict. The app has current paid activity, but ASC does not expose a positive comparison for the selected window. A later decision should include a clean 28-day RevenueCat trend, ASC acquisition and conversion trend, ratings and review count, crash and hang evidence, and a release-specific cohort.
This dated section supersedes earlier statements in this file that per-app ASC or RevenueCat activity was unavailable as of 2026-08-23. Earlier statements remain historical evidence boundaries for their original audit pass.
