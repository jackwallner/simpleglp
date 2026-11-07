# State machine fixes, 2026-11-06

Fixes for `state-machines-2026-11-06.md`, as corrected by `state-machines-2026-11-06-review.md`. Branch `fleet/20261106-165427-dd19-claude`, from `474aefe`.

**Summary: 10 claims in scope (1 CONFIRMED, 8 CONFIRMED-MINOR, 1 UNVERIFIED settled as real). 10 fixed, 0 held, 0 skipped. 2 product calls held for Jack. Full suite: baseline 115 passed, 0 failed; final 143 passed (115 plus 28 new), 0 failed, 0 skipped.**

## Claims

In the review's ranked order. Regression tests are in `SimpleGLPTests/StateMachineFixTests.swift` (pure schedule and Home tests) and `SimpleGLPTests/StateMachineNotificationFixTests.swift` (tests that need the notification fake, copied from the audit's repro suite).

| Id | Result | Commit | Regression test | What changed |
|---|---|---|---|---|
| S1 | Fixed | `cf63b42` | `StateMachineFixTests`: `testLoggedShotStaysClaimedAfterTravellingWest` (audit test, plus the nudge target), `testLoggedShotStaysClaimedAcrossALargeWestwardShift`, `testSecondShotInTheNewZoneStaysExtra`, `testDailyPillLoggedInNewYorkIsClaimedInLosAngeles` (review's pill variant), controls `testControlEastwardTravelKeepsTheClaim`, `testControlSameZoneClaimNamesOnlyItsOwnSlot` | `ScheduleEngine.claim(_:names:cadenceDays:calendar:)`: a stored claim names a slot when it is within 60 s, or when it no longer falls on the plan's time of day in the current zone and sits a whole number of quarter hours from the slot, closer than half the cadence (at most 26 h). Every claim check (`match`, the daily match, `nextUnclaimedOccurrence`, reminder slots, refill slots) goes through it. Stored data is unchanged and read as before in the same zone |
| S8 | Fixed | `0054021` | `StateMachineNotificationFixTests`: `testShorteningTheWaitMidCountdownRetimesThePing` (audit test), `testLengtheningTheWaitMidCountdownRetimesThePing` (review's harmful direction), `testSwitchingThePlanToAShotDropsThePing` | `DoseRoutineService.refresh` (plan save, launch, resume) now syncs `simpleglp.wait-end` and the Live Activity to the published glance, the same helper `historyDidChange` uses, and drops both when no wait is running |
| S3 | Fixed | `767f958` | `testUndoRestoresTheLateDoseNudgeForTheUnloggedDose`, `testDeletingTodaysDoseRestoresTheLateDoseNudge` (audit tests), `testHomeUndoAfterHealthSettlesRestoresTodaysNudge` (review's Home route), control `testControlSchedulerRunningAgainRestoresTheNudgeAfterUndo` | `historyDidChange` (Undo, History delete, Details edit and delete, import) runs the Pro alerts pass after the reminders |
| S2 | Fixed | `a258034` | `testLateDoseNudgeNeverFiresInsideQuietHours` (audit test), `testColdLaunchPassKeepsTheNudgeOutOfQuietHours` (review's cold-launch pass with stored quiet hours) | `lateDoseFireDate(for:prefs:notBefore:calendar:)` applies the `now + 60 s` floor before the quiet-hour shift |
| S4 | Fixed | `767f958` | `testLateDoseNudgeReconcilesWhenPermissionIsGrantedLater` (audit test), control `testControlDoseReminderReconcilesWhenPermissionIsGrantedLater` | `refresh` (scene active) runs the Pro alerts pass, so permission granted in iOS Settings reaches the nudge on return |
| S5 | Fixed | `767f958` | `testPlanSaveRetimesTheLateDoseNudge` (audit test) | Plan save ends with `refresh`, which now runs the Pro alerts pass |
| S9 | Fixed | `db8b52a` | `testDeletingClaimingShotHandsTheSlotToTheSameWeekSibling` (review's route), `testUndoOfTheClaimingShotHandsTheSlotToTheSibling`, control `testControlExistingClaimsAreLeftAlone` | `PlanStore.rematchExtraEvents` runs at the top of `historyDidChange`: events stored as `extra` are re-matched oldest first and take a slot that is now free. Existing claims are never rewritten |
| S7 | Fixed | `1d58382` | `testBackdatedLogKeepsTodaysSnoozedReminder` (audit test, with the real `ReminderService.snooze` handler as the review asked), control `testControlLoggingTodaysDoseClearsTheSnooze` | `captureShot` records `ScheduleEngine.nextDue` before the log. `didLogDose` clears dose reminders and the snooze only when the log changed the dose owed (or there is no plan) |
| S6 | Fixed | `f2f2c28` | `testRefillAfterOfflineLaunchReschedulesTheHeadsUp`, `testStopTrackingAfterOfflineLaunchDropsTheHeadsUp`, control `testControlUnresolvedFreeReadingLeavesTheRefillAlone` | The refill guard in `rescheduleReminders` also passes when Pro is already on from cached customer info. It exists to protect a Pro user who reads as free, which a Pro reading cannot be. A successful restore now sets `hasResolvedEntitlements`. Test seam: `setLocalOverride(isPro:resolved:)` (DEBUG) |
| S10 | Fixed (was UNVERIFIED) | `facd370` | `StateMachineFixTests.testWeeklyHomeCardTurnsOverAtMidnightAndAtTheDoseTime` | The weekly card sits in `TimelineView(.everyMinute)` like the pill card and derives next dose, headline and overdue mark from the timeline date (`HomeView.nextShot(plan:events:now:)`) |

### Notes

- **S3, S4 and S5 share one cause** (no nudge pass after a history change, a plan save or a resume) and one commit. Running the pass on every resume would have repeated "Dose slipping?" a minute after each app open while a dose stays overdue (product call 9). So these new passes (`rearmPastDue: false`) schedule only a nudge still ahead and leave a passed one as it is. The cold-launch, log and Pro alerts screen passes behave as before. Guarded by `testControlResumeDoesNotRearmAPastDueNudge`.
- **S10 settled.** `HomeView` has no input that changes on resume or with the clock: `refresh` publishes the glance to the App Group (not observed), widget ingest and enrichment return without publishing when nothing is pending, and `HomeView` does not read `scenePhase`. SwiftUI only re-runs `body` on a dependency change, so the card stays as first drawn. A customer leaving One Tap open across the dose time reaches it with certainty. The test proves the card's state follows the clock it is given. The per-minute redraw itself has no headless seam (the review said the same), so it is covered by the code change, not a test.
- **S1 upgrade.** No stored data changes. Claims written in the current zone match exactly as before (the 60 s rule comes first, and a claim still on the plan's time of day never matches another slot). Only claims that a zone change moved off the plan's time of day are read differently. `testControlSameZoneClaimNamesOnlyItsOwnSlot` covers existing same-zone data.
- **S9 upgrade.** The re-match only promotes `extra` events whose slot is free, which is what a plan save would compute. It never clears or rewrites a claim and never deletes data.
- **Project file.** Two test files were added. The gh-sim runner runs `xcodegen generate`; the tracked `SimpleGLP.xcodeproj` was not regenerated here (no Xcode on this machine). Run `xcodegen generate` after pulling.
- The audit's repro suite was never added to the test target. Its sound tests are now permanent in the two files above.

## Held for Jack

- **Product call 9: re-arm "Dose slipping?" at now + 60 s while a dose stays overdue.** The cold-launch pass still does this (now outside quiet hours). The new resume, history and plan-save passes do not. Decision: should a cold launch while a dose is overdue repeat the nudge a minute later, or should a nudge whose time passed never be re-armed?
- **Product call 8: paywall copy "Apple reminds you before your trial ends." and "Reminder day N"** (`SimplePaywallView.swift:214`, `:487`, `TrialOfferSheet.swift:299`). The review calls it a bigger risk than a product call because the app schedules no reminder. It is paywall copy. Decision: keep the line, reword it, or add an in-app trial-end reminder.

## Skipped

None.

## Test runs

All on gh-sim, `gh-sim test --scheme SimpleGLP`.

| Run | Code | Result |
|---|---|---|
| `simpleglp@20261106-165427-dd19-claude-mbproe9a6-1106-165453-32657` (GitHub run 42321084959) | Baseline, `474aefe`, before any change | 115 passed, 0 failed, 0 skipped. Nothing failed before the fixes |
| `simpleglp@20261106-165427-dd19-claude-mbproe9a6-1106-175304-28646` (GitHub run 42326404729) | Final, `facd370` | 143 passed, 0 failed, 0 skipped. No test newly fails |
WITHOUT_ROW

Xcode 27.1, iPhone 17, iOS 27.2, runner clock UTC.
