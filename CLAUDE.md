# Simple GLP — Project Guide

GLP-1 tracker for weekly shots and daily pills (Wegovy pill, Foundayo, Rybelsus):
log the dose, see the schedule, and for pills run the wait-before-eating
countdown (Home, Lock Screen Live Activity, widget, Watch). XcodeGen project/scheme: `SimpleGLP`,
sim lease owner `simpleglp`. App Store ID `6770137909`.

## Tech Stack
- Swift 6 / SwiftUI (strict concurrency)
- HealthKit (read), WidgetKit, watchOS companion, local notifications
- XcodeGen (`project.yml`). Targets: iOS 17+, watchOS
- RevenueCat, gate is `StoreService.isProUnlocked`

## Targets / bundle IDs
- `SimpleGLP` — `com.jackwallner.glp`
- `SimpleGLPWidget` — `.widget`
- `SimpleGLPWatch` — `.watch`
- `SimpleGLPTests` — `.tests`, `SimpleGLPUITests` — `.uitests`
- App Group: `group.com.jackwallner.glp`

## Architecture
`SharedGLP/` is the small module the phone, watch and widget all compile:
`GLPAppGroup`, `RecentShotsStore`, `GLPGlance` (shot vs pill + running wait, what
the widget and Watch render), `GLPWaitActivityAttributes`, `ReviewPromptTracker`,
`AppStoreReviewLinks`.
Anything a glance surface needs has to live there or reach it through the App
Group.

`SimpleGLP/` is the phone app:
- `Models/` — `GLPModels`, `ProAlertPreferences`
- `Services/`
  - `ShotCaptureCoordinator` — the log path every surface goes through
  - `DoseRoutineService`: everything after a log/undo/delete (wait notification,
    Live Activity via `LiveActivityService`, reminders, refill alert, glance publish)
  - `GLPModelStore`, `PlanStore`, `ScheduleEngine` — the dose plan, its cadence,
    and the next-dose arithmetic. Daily plans match by calendar day; `DailyAdherence`
    (streak) and `SupplyMath` (refills) live in `ScheduleEngine.swift`
  - `ReminderService`, `ProactiveAlertsEngine` — local notifications
  - `HealthKitService` — the optional Health reads behind Insights
  - `ExportService` / `ImportService`, `StoreService`, `PhoneWatchSession`,
    `DiagnosticsService`, `ConversionDiagnostics`
- `Views/` — `RootTabView`, `HomeView` (`PillRoutineView` for pills), `SupplyView`,
  `HistoryView`, `InsightsView`,
  `OnboardingView`, `SimplePaywallView`, `TrialOfferSheet`, `SettingsView`,
  `ProAlertsConfigView`
- `Utilities/` — `AppTheme`, `AppEnvironment`, `PaywallScreenshotMode`

## Rules that hold everywhere
- **Free vs Pro.** Logging, the schedule, reminders, the in-app pill countdown +
  "wait's over" notification, streak, history and Insights are free; Insights
  needs `ProactiveAlertsEngine.minimumSampleSize` logs before it says anything.
  Pro (`StoreService.isProUnlocked`) opens the Lock Screen/Dynamic Island wait
  countdown, supply tracking + refill reminders, and Proactive Alerts. Pro copy
  lives in one place, `ProFeatures`, worded per dose form. Products:
  subscriptions `com.jackwallner.glp.pro.monthly` /
  `.pro.yearly` plus the non-consumable `.pro.lifetime`
  (`SimpleGLP/Services/Products.storekit`).
- **Never present a promo or trial sheet before entitlements resolve.**
  `RootTabView` gates every sheet on resolved entitlements and `!isProUnlocked`,
  because a recent purchase can flip Pro a beat after launch and pull a sheet out
  from under the layout.
- **This is a medication tracker, not medical advice.** It records what the user
  says they took and when. Never phrase a schedule, a reminder, the wait timer or
  an insight as a dosing recommendation (App Review 1.4.1). Pill strengths and the
  30-minute wait are only picker defaults the user sets to match their prescriber.
- **Vocabulary follows the plan.** `DoseForm.noun` / `GLPStorageKey.isPillPlan`
  ("shot" vs "pill"); never hardcode "shot" in shared UI.
- Debug seeds: `-uitesting -GLPScreenshotSeed` (weekly shot); add
  `-GLPScreenshotPill` for a pill user mid-countdown.
- **Review funnel:** `ReviewPromptTracker.recordPositiveMoment()` after a logged
  shot (`ShotCaptureCoordinator`) and from Settings. App Store ID above.
- **`scripts/aso-apply-locale-optimizations.py` is stale and renames the app.**
  Do not run it blindly; read it first and prefer the current ASC upload flow.
  Keyword reasoning lives in `aso-plan.md`.

---
Shared iOS conventions (build, simulator, release/TestFlight, ASC key, signing,
review funnel, gotchas): always-loaded global CLAUDE.md + the `ios-dev` skill.
