# State machine fixes, 2026-11-06

Fixes for `state-machines-2026-11-06.md`, as corrected by `state-machines-2026-11-06-review.md`. Branch `fleet/20261106-195641-16eb-claude`, from `b511227`. The fixes were first made in fleet run `20261106-165427-dd19-claude` and carried onto `b511227`. A second run (`20261106-195641-16eb-claude`) checked them against the hold rules, settled S10 with a headless test on `b511227`, and reran the suite.

**Summary: 10 claims in scope (1 CONFIRMED, 8 CONFIRMED-MINOR, 1 UNVERIFIED that failed its test on `b511227`). 10 fixed, 0 held, 0 skipped. 3 decisions held for Jack (one part of the S6 fix that was backed out, and 2 product calls). Full suite (`SimpleGLP` scheme): 143 passed, 0 failed, 0 skipped, nothing newly failing. S10 UI test: fails on `b511227`, passes on the fix.**

## Claims

In the review's ranked order. Regression tests are in `SimpleGLPTests/StateMachineFixTests.swift` (pure schedule and Home tests), `SimpleGLPTests/StateMachineNotificationFixTests.swift` (tests that need the notification fake, copied from the audit's repro suite) and `SimpleGLPUITests/WeeklyHomeClockUITests.swift` (S10).

| Id | Result | Commit | Regression test | What changed |
|---|---|---|---|---|
| S1 | Fixed | `af591be` | `StateMachineFixTests`: `testLoggedShotStaysClaimedAfterTravellingWest` (audit test, plus the nudge target), `testLoggedShotStaysClaimedAcrossALargeWestwardShift`, `testSecondShotInTheNewZoneStaysExtra`, `testDailyPillLoggedInNewYorkIsClaimedInLosAngeles` (review's pill variant), controls `testControlEastwardTravelKeepsTheClaim`, `testControlSameZoneClaimNamesOnlyItsOwnSlot` | `ScheduleEngine.claim(_:names:cadenceDays:calendar:)`: a stored claim names a slot when it is within 60 s, or when it no longer falls on the plan's time of day in the current zone and sits a whole number of quarter hours from the slot, closer than half the cadence (at most 26 h). Every claim check (`match`, the daily match, `nextUnclaimedOccurrence`, reminder slots, refill slots) goes through it. Stored data is unchanged and read as before in the same zone |
| S8 | Fixed | `79f41f1` | `StateMachineNotificationFixTests`: `testShorteningTheWaitMidCountdownRetimesThePing` (audit test), `testLengtheningTheWaitMidCountdownRetimesThePing` (review's harmful direction), `testSwitchingThePlanToAShotDropsThePing` | `DoseRoutineService.refresh` (plan save, launch, resume) now syncs `simpleglp.wait-end` and the Live Activity to the published glance, the same helper `historyDidChange` uses, and drops both when no wait is running |
| S3 | Fixed | `7c4d436` | `testUndoRestoresTheLateDoseNudgeForTheUnloggedDose`, `testDeletingTodaysDoseRestoresTheLateDoseNudge` (audit tests), `testHomeUndoAfterHealthSettlesRestoresTodaysNudge` (review's Home route), control `testControlSchedulerRunningAgainRestoresTheNudgeAfterUndo` | `historyDidChange` (Undo, History delete, Details edit and delete, import) runs the Pro alerts pass after the reminders |
| S2 | Fixed | `193852c` | `testLateDoseNudgeNeverFiresInsideQuietHours` (audit test), `testColdLaunchPassKeepsTheNudgeOutOfQuietHours` (review's cold-launch pass with stored quiet hours) | `lateDoseFireDate(for:prefs:notBefore:calendar:)` applies the `now + 60 s` floor before the quiet-hour shift |
| S4 | Fixed | `7c4d436` | `testLateDoseNudgeReconcilesWhenPermissionIsGrantedLater` (audit test), control `testControlDoseReminderReconcilesWhenPermissionIsGrantedLater` | `refresh` (scene active) runs the Pro alerts pass, so permission granted in iOS Settings reaches the nudge on return |
| S5 | Fixed | `7c4d436` | `testPlanSaveRetimesTheLateDoseNudge` (audit test) | Plan save ends with `refresh`, which now runs the Pro alerts pass |
| S9 | Fixed | `3d59f4a` | `testDeletingClaimingShotHandsTheSlotToTheSameWeekSibling` (review's route), `testUndoOfTheClaimingShotHandsTheSlotToTheSibling`, control `testControlExistingClaimsAreLeftAlone` | `PlanStore.rematchExtraEvents` runs at the top of `historyDidChange`: events stored as `extra` are re-matched oldest first and take a slot that is now free. Existing claims are never rewritten |
| S7 | Fixed | `fb85667` | `testBackdatedLogKeepsTodaysSnoozedReminder` (audit test, with the real `ReminderService.snooze` handler as the review asked), control `testControlLoggingTodaysDoseClearsTheSnooze` | `captureShot` records `ScheduleEngine.nextDue` before the log. `didLogDose` clears dose reminders and the snooze only when the log changed the dose owed (or there is no plan) |
| S6 | Fixed | `4e589a1`, `d9448f8` | `testRefillAfterOfflineLaunchReschedulesTheHeadsUp`, `testStopTrackingAfterOfflineLaunchDropsTheHeadsUp`, control `testControlUnresolvedFreeReadingLeavesTheRefillAlone` | The refill guard in `rescheduleReminders` also passes when Pro is already on from cached customer info. It exists to protect a Pro user who reads as free, which a Pro reading cannot be, so nothing is torn down on an inferred state. Test seam: `setLocalOverride(isPro:resolved:)` (DEBUG). `4e589a1` also marked entitlements resolved after a restore; `d9448f8` backs that out (see Held for Jack). The route the review describes does not need it |
| S10 | Fixed (was UNVERIFIED, failed its test on `b511227`) | `ac88856`, test `53a5e57` | `WeeklyHomeClockUITests.testWeeklyCardTurnsOverdueWhileOneTapStaysOpen` (UI test, `SimpleGLPUITests` scheme), plus `StateMachineFixTests.testWeeklyHomeCardTurnsOverAtMidnightAndAtTheDoseTime` | The weekly card sits in `TimelineView(.everyMinute)` like the pill card and derives next dose, headline and overdue mark from the timeline date (`HomeView.nextShot(plan:events:now:)`). Test seam: DEBUG-only `-GLPScreenshotDueSoon` puts today's weekly dose 90 to 150 s after launch |

### Notes

- **S10 settled headless.** The UI test launches the weekly seed with the dose due a minute or two out, checks One Tap reads "Due today" with no overdue mark, then waits for the mark. On `b511227` plus only the seed and the test (GitHub run 42336583653) it failed at the final assertion: four minutes after launch the card still read "Due today, 4:47 AM" with no warning icon, after 4:47 had passed. With the fix (GitHub run 42340221424) it passes.
- **S3, S4 and S5 share one cause** (no nudge pass after a history change, a plan save or a resume) and one commit. Running the pass on every resume would have repeated "Dose slipping?" a minute after each app open while a dose stays overdue (product call 9). So these new passes (`rearmPastDue: false`) schedule only a nudge still ahead and leave a passed one as it is. The cold-launch, log and Pro alerts screen passes behave as before. Guarded by `testControlResumeDoesNotRearmAPastDueNudge`.
- **S1 upgrade.** No stored data changes. Claims written in the current zone match exactly as before (the 60 s rule comes first, and a claim still on the plan's time of day never matches another slot). Only claims that a zone change moved off the plan's time of day are read differently. `testControlSameZoneClaimNamesOnlyItsOwnSlot` covers existing same-zone data.
- **S9 upgrade.** The re-match only promotes `extra` events whose slot is free, which is what a plan save would compute. It never clears or rewrites a claim and never deletes data.
- **Project file.** Three test files were added. The gh-sim runner runs `xcodegen generate`; the tracked `SimpleGLP.xcodeproj` was not regenerated here (no Xcode or XcodeGen on the fleet machine). Run `xcodegen generate` after pulling.
- The audit's repro suite was never added to the test target. Its sound tests are now permanent in the files above.

## Held for Jack

- **Mark entitlements resolved after a successful restore.** The first run added `hasResolvedEntitlements = true` after `Purchases.shared.restorePurchases()` succeeds (`StoreService.swift`, `restorePurchases`). It is a fresh network answer, but `hasResolvedEntitlements` gates every promo and trial sheet in `RootTabView`, so it changes when those sheets can appear. Backed out in `d9448f8`; S6 is fixed without it. Decision: should a successful restore count as resolved entitlements, the same as a successful customer info fetch?
- **Product call 9: re-arm "Dose slipping?" at now + 60 s while a dose stays overdue.** The cold-launch pass still does this (now outside quiet hours). The new resume, history and plan-save passes do not. Decision: should a cold launch while a dose is overdue repeat the nudge a minute later, or should a nudge whose time passed never be re-armed?
- **Product call 8: paywall copy "Apple reminds you before your trial ends." and "Reminder day N"** (`SimplePaywallView.swift:214`, `:487`, `TrialOfferSheet.swift:299`). The review calls it a bigger risk than a product call because the app schedules no reminder. It is paywall copy. Decision: keep the line, reword it, or add an in-app trial-end reminder.

## Skipped

None.

## Test runs

All on gh-sim.

| Run | Code | Result |
|---|---|---|
| GitHub run 42321084959 (`simpleglp@20261106-165427-dd19-claude-mbproe9a6-1106-165453-32657`), `--scheme SimpleGLP` | First run's baseline, `474aefe`, before any fix (that run's base, not in this branch's history) | 115 passed, 0 failed, 0 skipped. Nothing failed before the fixes |
| GitHub run 42336583653, `--scheme SimpleGLPUITests --only SimpleGLPUITests/WeeklyHomeClockUITests` | `b511227` plus the S10 seed and UI test only | 0 passed, 1 failed (expected: proves S10) |
| GitHub run 42340221424, same | Head with the S10 fix | 1 passed, 0 failed |
| GitHub run 42344134561 (`simpleglp@20261106-195641-16eb-claude-mbpro3c946-1106-214623-24926`), `--scheme SimpleGLP` | Final, `53a5e57` | 143 passed (115 plus 28 new), 0 failed, 0 skipped. No test newly fails, and none failed on the baseline |

Xcode 27.1, iPhone 17, iOS 27.2, runner clock UTC.
