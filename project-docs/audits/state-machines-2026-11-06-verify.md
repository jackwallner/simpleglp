VERDICT: PASS

# Verification of the state machine fixes, 2026-11-06 (second round)

Independent check of `state-machines-2026-11-06-fixes.md` against `state-machines-2026-11-06-review.md` and the whole change `git diff b5112273a5cc3b704de0fc3ef2ee2b76a4d360f7..2b06a06`. This replaces the first verify (FAIL on an S1 daily pill regression). I read the app code myself and ran the tests on gh-sim. No app code or tests were changed on this branch.

**Summary: all 10 fixes work on the review's routes and no regression was found. The first verify's S1 daily pill regression is fixed: a daily claim is now read by the calendar day of the pill in the current zone, the same rule Home, the widget, the Watch and Siri use. Full suite on HEAD: 147 passed, 0 failed, 0 skipped, including all 32 added unit tests and the one edited test. S10 UI test passes on HEAD. Fail-without-fix proved for S1, S8 and S3 (7 tests, each fails at its final assertion with the fix reverted).**

## Fixes

| Id | Works | Regression check | Evidence |
|---|---|---|---|
| S1 | Yes (weekly and daily) | Pass. Daily (`cadenceDays == 1`): a claim names the slot on the calendar day the pill was taken, in the current zone (`ScheduleEngine.swift:163`), the rule `nextDue` reads (`:148`). In the same zone `dailyMatch` always stores the slot of the timestamp's own day (`:99-104`), so existing daily data reads exactly as before; only zone changes read differently, and now agree with Home. Other cadences: `claim` (`:173-185`) keeps the 60 s rule first; a claim off the plan's time of day and a whole quarter hour away, under `min(26 h, cadence x 12 h)`, reads as a zone shift. Same-zone claims sit on the plan's time of day (plan saves recompute every match, `SettingsView.swift:373`), so they match only their own slot. Every claim reader goes through the one function: `match` (`:65`), `dailyMatch` (`:107`), `nextUnclaimedOccurrence` (`:200`, `:211`), reminder slots (`ReminderService.swift:106`), refill slots (`ScheduleEngine.swift:399`); Home, widget and Watch read `nextDue` through `publishGlance` (`DoseRoutineService.swift:170`). No stored format change | With the fix reverted (run 42374806892): `testLoggedShotStaysClaimedAfterTravellingWest` fails at its final assertion ("Home reads \"Overdue by 1 day\" for a shot already taken"), `testDailyPillLoggedInNewYorkIsClaimedInLosAngeles` fails ("late-dose nudge targets today's pill, already logged"). Both pass on HEAD (run 42373065543). The first verify's two daily regression cases are permanent tests (`testDailyPillOwedInTokyoKeepsItsReminderAndMatch`, `testDailyPillOwedAfterFlyingDelhiToNewYorkKeepsItsReminder`) and pass on HEAD. All assert what Home, reminders and the nudge read, which is behaviour |
| S8 | Yes | Pass. `refresh` (launch, resume, plan save, onboarding) now calls `syncWait` (`DoseRoutineService.swift:86`, helper `:47-57`): with a wait running it re-adds the same ping (`mayPrompt: false`) and, for Pro, `LiveActivityService.sync` starts or updates the countdown, which covers what the removed `startLiveActivityIfWaiting` call did. With no wait it cancels the pending ping (pending only, `ReminderService.swift:130-132`) and ends activities. Waits exist only for pills (`GLPGlance.waitEndsAt`, `GLPModels.swift:289`). A widget log is ingested before `refresh` (`SimpleGLPApp.swift:175-177`, `:184-186`). Free users keep the ping; Live Activity stays Pro-gated | With the fix reverted (run 42374806892): `testLengtheningTheWaitMidCountdownRetimesThePing` fails at its final assertion ("the wait-over ping fires at 13:44:55, before Home's end 14:14:55"), `testShorteningTheWaitMidCountdownRetimesThePing` fails ("Home says the wait ends 13:25:00, the ping fires 13:45:00"). Both pass on HEAD. They assert the pending ping's fire time against the glance's wait end |
| S3 | Yes | Pass. `historyDidChange` runs the nudge pass with `rearmPastDue: false` after the reminders (`DoseRoutineService.swift:37-42`). Callers: Undo (`ShotCaptureCoordinator.swift:199`), History delete (`HistoryView.swift:181`), Details save and delete (`EditEventSheet.swift:211`, `:226`), CSV import (`SettingsView.swift:685`); each saves first. The pass tears down only on `isActive == false` (`ProactiveAlertsEngine.swift:53-57`), the existing rule (a resolved non-Pro reading or alerts off) | With the fix reverted (run 42374806892): `testUndoRestoresTheLateDoseNudgeForTheUnloggedDose`, `testDeletingTodaysDoseRestoresTheLateDoseNudge` and the Home-route `testHomeUndoAfterHealthSettlesRestoresTodaysNudge` all fail at the final assertion ("nudge stays at 2026-11-08 16:44, should be 2026-11-07 16:44"); the Home-route preconditions held this time. All pass on HEAD |
| S2 | Yes | Pass. `lateDoseFireDate` takes `notBefore` and applies it before the quiet-hour shift (`ProactiveAlertsEngine.swift:131-140`); the scheduler passes `now + 60 s` (`:98`). Its other callers pass no floor and are unchanged | `testColdLaunchPassKeepsTheNudgeOutOfQuietHours` drives the real pass with stored quiet hours and asserts the scheduled fire date is outside them; passes on HEAD. Not reverted by me; the review records the same assertion failing on the base |
| S4 | Yes | Pass. `refresh` (scene active) runs the nudge pass (`DoseRoutineService.swift:87-92`) with `ensureAuthorization(mayPrompt: false)` (`ProactiveAlertsEngine.swift:95`), so no prompt from a background path. `rearmPastDue: false` (`:92`) leaves a passed nudge alone, so product call 9 is not widened to every resume (`testControlResumeDoesNotRearmAPastDueNudge` passes) | `testLateDoseNudgeReconcilesWhenPermissionIsGrantedLater` asserts a pending nudge after `refresh`; passes on HEAD |
| S5 | Yes | Pass. Plan save ends with `refresh` (`SettingsView.swift:380`), which now retimes the nudge | `testPlanSaveRetimesTheLateDoseNudge` asserts the new fire date; passes on HEAD. It moves the time earlier; later uses the same path |
| S9 | Yes | Pass. `rematchExtraEvents` (`PlanStore.swift:33-48`) runs first in `historyDidChange` and only promotes `.extra` events, oldest first, to a slot that is now free; it never clears a claim or deletes data. On an existing user's first undo, delete, edit or import after the update, old extras next to a free slot are promoted, which is what a plan save already computes | `testDeletingClaimingShotHandsTheSlotToTheSameWeekSibling`, `testUndoOfTheClaimingShotHandsTheSlotToTheSibling`, control `testControlExistingClaimsAreLeftAlone`; assert stored status; pass on HEAD |
| S7 | Yes | Pass. `captureShot` records `nextDue` before the log (`ShotCaptureCoordinator.swift:95`); `didLogDose` clears reminders and the snooze only when the published `nextDoseAt` changed or there is no plan (`DoseRoutineService.swift:17`). Today's log, a "Took it" action, a widget ingest of today's pill, a late-night pill after midnight and a weekly log for the owed slot all change `nextDue` and still clear. A backfill for another day leaves the snooze and delivered reminders, which is right while the dose is still owed | `testBackdatedLogKeepsTodaysSnoozedReminder` uses the real `ReminderService.snooze` and asserts the pending snooze survives; control `testControlLoggingTodaysDoseClearsTheSnooze`; pass on HEAD |
| S6 | Yes | Pass, scope clean. The refill guard also passes on cached Pro (`DoseRoutineService.swift:155`); a Pro reading only reschedules the alert, and a free reading before resolution still leaves it alone. Nothing is torn down on an inferred non-member state. The net `StoreService` diff is the DEBUG-only `setLocalOverride(isPro:resolved:)` with the old default (`StoreService.swift:320-324`); the restore change stays backed out | `testRefillAfterOfflineLaunchReschedulesTheHeadsUp`, `testStopTrackingAfterOfflineLaunchDropsTheHeadsUp`, control `testControlUnresolvedFreeReadingLeavesTheRefillAlone`; pass on HEAD |
| S10 | Yes, in the foreground | Pass. `nextShotSection` sits in `TimelineView(.everyMinute)` (`HomeView.swift:181`) and reads `nextDue` at `max(tick, now)` (`:188-190`), so the first verify's one-minute lag after a mid-minute daily-shot log is gone. The `else` branch keeps the "No plan yet" card, so the section always renders a view. No new strings. iPhone Duo: the card only gains a wrapper; `RootTabView` layout is untouched | `WeeklyHomeClockUITests.testWeeklyCardTurnsOverdueWhileOneTapStaysOpen` passes on HEAD (run 42378905250; two earlier attempts hit runner UI query timeouts, see Test results). On the base plus seed and test it failed at its final assertion (run 42336583653, log: "One Tap still shows the weekly dose as upcoming after its planned time passed"). `testDailyShotCardTurnsOverRightAfterAMidMinuteLog` and `testWeeklyHomeCardTurnsOverAtMidnightAndAtTheDoseTime` pass on HEAD |

## Must change

Nothing.

## Disputed and held items

- The fixes doc lists "Disputed: None", so there is nothing to rule on.
- Held for Jack, all held correctly and untouched by the diff: (1) marking entitlements resolved after a restore would change when promo and trial sheets can appear; the net diff has no `restorePurchases` change. (2) Product call 9: the cold-launch passes still call the nudge pass with the default `rearmPastDue: true` (`SimpleGLPApp.swift:192`, `:199`); the new passes use `false`. (3) Product call 8: no paywall or trial sheet file is in the diff.

## Scope (check 4)

No failure. Every app change maps to a listed claim. Test seams only: the DEBUG `-GLPScreenshotDueSoon` seed (`SimpleGLPApp.swift:221-232`) and the DEBUG `setLocalOverride(isPro:resolved:)`. No change to prices, offers, paywall or trial timing, onboarding order, or how membership is judged. No backend, App Store Connect or RevenueCat change. No stored format change, and nothing is cleared on an inferred entitlement state. S10 (the one UNVERIFIED claim) failed its test on `b511227` (run 42336583653). All 10 in-scope claims are in the fixes table; none skipped.

## Test results

All on gh-sim, Xcode 27.1, iPhone 17, iOS 27.2, runner clock UTC.

| GitHub run | Code | What | Result |
|---|---|---|---|
| 42373065543 | HEAD `2b06a06` | `gh-sim all --scheme SimpleGLP`, full suite plus launch screenshots | 147 passed, 0 failed, 0 skipped. Matches the fixes doc (147). All 32 tests in `StateMachineFixTests` and `StateMachineNotificationFixTests` passed (none skipped), and the edited `SimpleGLPTests.testLateDoseOccurrenceClaimedByLoggedShot` passed |
| 42374806892 | Throwaway branch: HEAD with S1 (`isOccurrenceClaimed` back to the 60 s rule), S8 (`refresh` back to `startLiveActivityIfWaiting`) and S3 (no nudge pass in `historyDidChange`) reverted, tests kept | `--only` the 7 S1, S8 and S3 tests | 0 passed, 7 failed, each at its final assertion after every precondition held (messages above). Fail-without-fix proved for all three |
| 42376267153 | HEAD | `--scheme SimpleGLPUITests --only SimpleGLPUITests/WeeklyHomeClockUITests` | Infrastructure failure, proves nothing: "Failed to get matching snapshots: Timed out while evaluating UI query". The attached spindump shows the app idle in its run loop (CPU under 1 ms) while the runner sat in kernel I/O throttling |
| 42377637618 | HEAD | Same | Same infrastructure failure: "App event loop idle notification not received" at launch, then the same query timeout. The spindump shows the app's main thread inside XCTest's snapshot code, blocked in a kernel `writev` (app CPU 0.04 s; kernel_task and spindump used most of the CPU) |
| 42378905250 | HEAD | Same | 1 passed, 0 failed (118 s). The same app and UI test code (unchanged since `c6f652f`) also passed in the fixes doc's run 42370992505 |

No newly failing test, so no rerun on `b511227` was needed. Two UI test attempts failed from the runner and were rerun until a run completed. The throwaway branch was deleted; this branch has only this doc commit on top of what I was given.

## Screens

Run 42373065543, weekly seed, real screenshots:
- `-uitesting -GLPScreenshotSeed`: One Tap card reads "Due today" with the warning triangle, November 7, 2026, 8:30 AM, with the runner clock past 8:30. Layout unchanged.
- `-uitesting -GLPScreenshotSeed -GLPScreenshotDueSoon`: "Due today", 12:59 PM, no triangle while the dose is still ahead.

## Device checks left open

- S10 across midnight and across the dose time with the app backgrounded or the phone locked, then unlocked. The tests prove only the foreground minute tick.
- S8 Live Activity end time after a wait change (the tests keep Pro off to leave Live Activities out).
- S4 on a device: allow notifications in iOS Settings, return, then `pendingNotificationRequests()`.
- S6 airplane-mode cold start, "I refilled", then `pendingNotificationRequests()` (the test fakes the unresolved state with the DEBUG seam).
- S7 on a device: snooze a real reminder, backfill another day, confirm the snooze still fires.
- S1 on a device with automatic time zone across a real flight (the tests use explicit calendars).

## Notes

- Minor, not a failure: for cadences above one day the zone-shift reading needs the claim off the plan's time of day. Two zones exactly 24 h apart (Line Islands UTC+14 and Hawaii UTC-10) fall back to the old exact rule. Practically unreachable.
- Minor, not a failure: during a plan save `recalculateScheduleMatches` compares an event against later events that still hold the old plan's claims. With the shift reading, an old claim within 26 h of a new slot can now leave a different duplicate as Manual than before (for example a weekday move with a shot logged four days late). Statuses only, nothing deleted; product call 2 already says a plan save rewrites past statuses.
- Android parity: the claim rules changed on iOS only. `.claude/rules/android.md` keeps iOS as the specification; the Android port does not have the zone-change reading yet.
- `WeeklyHomeClockUITests` polls an image query for up to 240 s on a loaded runner. Two of my three attempts hit XCTest UI query timeouts with the app idle. Not a product fault, but expect occasional reruns on GitHub's Macs.
- The tracked `SimpleGLP.xcodeproj` was not regenerated for the three new test files; gh-sim runs `xcodegen generate`. Run it after pulling.
