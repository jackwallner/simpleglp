VERDICT: FAIL

# Verification of the state machine fixes, 2026-11-06

Independent check of `state-machines-2026-11-06-fixes.md` against `state-machines-2026-11-06-review.md` and the whole change `git diff b5112273a5cc3b704de0fc3ef2ee2b76a4d360f7..90f504c`. I read the app code myself and ran every test on gh-sim. No app code or tests were changed on this branch.

**Summary: 9 of 10 fixes work with no regression found. S1 works for the weekly route the review describes but adds a regression for daily pill users: after a time zone change of the right size, the next morning's dose reminder and late-dose nudge are dropped and the pill they log is stored as "Manual", while Home says the pill is due. Proved by a test that fails on HEAD and passes with the S1 fix reverted. Full suite on HEAD: 143 passed, 0 failed. S10 UI test passes on HEAD. Fail-without-fix proved for S1, S8 and S3.**

## Fixes

| Id | Works | Regression check | Evidence |
|---|---|---|---|
| S1 | Weekly: yes. Daily pills: no, regression | **FAIL.** `ScheduleEngine.claim` reads any stored claim within `min(26 h, cadence x 12 h)` that is off the plan's time of day as a zone shift. For a daily plan the limit is 12 h, so it picks the nearest slot, while Home, the widget, the Watch and Siri use the calendar day of the log (`ScheduleEngine.swift:148`). When the two disagree, every claim check (reminder slots, the nudge, `dailyMatch`, refill slots) treats a dose that is still owed as taken | `ScheduleEngine.swift:170-181` (limit at `:173`), used by `:107` (daily match), `:197`, `:208`, `:396`, `ReminderService.swift:106`. Route: daily pill at 9:00, logged 9:05 in New York, then Tokyo the next morning (the same happens Delhi to New York, Europe to the US West Coast for pills before 9:00, and so on). Home says today's pill is due. `upcomingReminderSlots` skips today's slot, `nextUnclaimedOccurrence` skips it, and the pill logged in Tokyo stores as `.extra`. Test `VerifyDailyTravelClaimTests` (scratch, below): fails on HEAD (run 42355350677), passes with S1 reverted (run 42352043280). Before the fix, the exact 60 s rule left that slot unclaimed, so the reminder fired and the log matched. The weekly fix itself holds: `testLoggedShotStaysClaimedAfterTravellingWest` fails without the fix at its final assertion ("Home reads \"Overdue by 1 day\" for a shot already taken") and passes with it |
| S8 | Yes | Pass. `refresh` now runs `syncWait` on every launch, resume, plan save and onboarding (`DoseRoutineService.swift:86`). With a wait running it re-adds the same ping (`ReminderService.swift:115-128`, `mayPrompt: false`, so no prompt) and `LiveActivityService.sync` updates only a changed state (`LiveActivityService.swift:41-44`). With no wait it cancels the ping and ends activities. No route leaves a ping pending while the glance shows no wait: the widget's pending dose is ingested before `refresh` at `SimpleGLPApp.swift:175-177` and `:184-186`, and the widget intent schedules no ping (`LogShotIntent.swift`). Free users keep the ping; Live Activity stays Pro-gated (`:50`) | `testLengtheningTheWaitMidCountdownRetimesThePing` fails without the fix at its final assertion ("the wait-over ping fires at 08:48:58, before Home's end 09:18:58") and passes on HEAD. The test asserts the pending notification's fire time against the glance's wait end, which is behaviour |
| S3 | Yes | Pass. `historyDidChange` runs the nudge pass with `rearmPastDue: false` (`DoseRoutineService.swift:38-42`); callers are Undo (`ShotCaptureCoordinator.swift:199`), History delete (`HistoryView.swift:181`), Details edit and delete (`EditEventSheet.swift:211`, `:226`) and CSV import (`SettingsView.swift:685`). The pass tears down only on `isActive == false`, the same rule as the existing passes (`ProactiveAlertsEngine.swift:41-58`) | `testUndoRestoresTheLateDoseNudgeForTheUnloggedDose`, `testDeletingTodaysDoseRestoresTheLateDoseNudge` and `testHomeUndoAfterHealthSettlesRestoresTodaysNudge` all fail without the fix at the final assertion ("nudge stays at 2026-11-08 13:29, should be 2026-11-07 13:29", run 42358742084) and pass on HEAD |
| S2 | Yes | Pass. `lateDoseFireDate` applies the `now + 60 s` floor before the quiet-hour shift (`ProactiveAlertsEngine.swift:131-140`); its other callers pass no `notBefore` and are unchanged | `testColdLaunchPassKeepsTheNudgeOutOfQuietHours` drives the real pass with stored quiet hours and asserts the scheduled fire date; passes on HEAD. Not reverted by me; the review records the same assertion failing on the base |
| S4 | Yes | Pass. Resume now runs the nudge pass (`DoseRoutineService.swift:87-92`) with `ensureAuthorization(mayPrompt: false)`, so no prompt from a background path | `testLateDoseNudgeReconcilesWhenPermissionIsGrantedLater` asserts a pending nudge after `refresh`; passes on HEAD |
| S5 | Yes | Pass. Plan save calls `refresh` (`SettingsView.swift:380`), which now retimes the nudge | `testPlanSaveRetimesTheLateDoseNudge` asserts the new fire date; passes on HEAD. It covers moving the time earlier; moving it later uses the same path |
| S9 | Yes | Pass, with an upgrade note. `rematchExtraEvents` (`PlanStore.swift:33-48`) only promotes `.extra` events to a free slot and never clears a claim. On the first undo, delete, edit or import after the update, an existing user's old extras that the current rules would match (for example ones stored by an older matcher) are promoted too. That is what a plan save already computes, and no data is lost | `testDeletingClaimingShotHandsTheSlotToTheSameWeekSibling`, `testUndoOfTheClaimingShotHandsTheSlotToTheSibling`, control `testControlExistingClaimsAreLeftAlone`; all assert stored status; pass on HEAD |
| S7 | Yes | Pass. `didLogDose` clears reminders and the snooze only when `nextDue` changed (`DoseRoutineService.swift:15-19`, `owedBefore` from `ShotCaptureCoordinator.swift:95`). Today's log, a "Took it" action and an early weekly log all change `nextDue` and still clear. A backfill for another day leaves delivered reminders in Notification Center too, which is right while the dose is still owed | `testBackdatedLogKeepsTodaysSnoozedReminder` uses the real `ReminderService.snooze`; passes on HEAD; control `testControlLoggingTodaysDoseClearsTheSnooze` passes |
| S6 | Yes | Pass, scope clean. The guard now also passes on cached Pro (`DoseRoutineService.swift:155`). A Pro reading never tears anything down for a non-member; a free reading before resolution still leaves the alert alone. The restore change was backed out (`3506196`); the net `StoreService` diff is the DEBUG-only `setLocalOverride(isPro:resolved:)` with the old default | `testRefillAfterOfflineLaunchReschedulesTheHeadsUp`, `testStopTrackingAfterOfflineLaunchDropsTheHeadsUp`, control `testControlUnresolvedFreeReadingLeavesTheRefillAlone`; pass on HEAD |
| S10 | Yes, in the foreground | Pass. `nextShotSection` sits in `TimelineView(.everyMinute)` (`HomeView.swift:181`) and reads `nextDue` at the timeline date (`:188`). No new strings. iPhone Duo: the card only gains a wrapper; `RootTabView` layout is untouched | `WeeklyHomeClockUITests.testWeeklyCardTurnsOverdueWhileOneTapStaysOpen` passes on HEAD (run 42362236611). The base failure (run 42336583653) failed at the final assertion; its snapshot ref is gone, so I relied on that run's log. Screenshots below |

## Must change

1. **S1 daily claims.** For `cadenceDays == 1`, a stored claim must name the same slot that Home's calendar-day rule does. For example, treat a daily slot as claimed when the claiming event's timestamp falls on that slot's calendar day in the current zone (the rule at `ScheduleEngine.swift:148`), or keep the zone-shift reading for cadences above one day only and handle pills by calendar day. Add the two cases in `VerifyDailyTravelClaimTests` below as permanent regression tests: they must fail on HEAD and pass after the change. Keep `testDailyPillLoggedInNewYorkIsClaimedInLosAngeles` passing.

## Disputed and held items

- The fixes doc has no "Disputed" section, so there is nothing to rule on.
- Held for Jack, all held correctly and untouched by the diff: (1) marking entitlements resolved after a restore would change when promo and trial sheets may appear, so it is a membership decision; (2) product call 9 (the cold-launch re-arm at now + 60 s): the new passes use `rearmPastDue: false` and the cold-launch pass is unchanged; (3) product call 8 (paywall trial-reminder copy): no paywall file is in the diff.

## Scope (check 4)

No failure. Every change maps to a listed claim. The DEBUG-only seed flag `-GLPScreenshotDueSoon` (`SimpleGLPApp.swift:223`) and `setLocalOverride(isPro:resolved:)` are test seams. No paywall, price, offer, onboarding or trial-flow change. No backend, App Store Connect or RevenueCat change. No stored format change. S10 (UNVERIFIED) has a failing test on `b511227` (run 42336583653). All 10 in-scope claims are in the fixes table; nothing skipped.

## Test results

All on gh-sim, Xcode 27.1, iPhone 17, iOS 27.2.

| GitHub run | Code | What | Result |
|---|---|---|---|
| 42349168423 | HEAD `90f504c` | Full suite, `--scheme SimpleGLP` | 143 passed, 0 failed, 0 skipped. Matches the fixes doc (143). All 28 added unit tests and the edited `SimpleGLPTests` case pass |
| 42362236611 | HEAD | `gh-sim all --scheme SimpleGLPUITests --only SimpleGLPUITests/WeeklyHomeClockUITests`, plus launch screenshots | 1 passed, 0 failed |
| 42352043280 | Throwaway branch: HEAD with S1, S8 and S3 behaviour reverted, tests kept, plus my scratch test | `--only` the three top-ranked fix tests and `VerifyDailyTravelClaimTests` | S1 and S8 tests fail at their final assertions (fix proven). The S3 Home-route test failed only at a precondition (the Health read had not settled within 10 s), so it proved nothing and I reran S3. Scratch tests: 2 passed (no regression without S1) |
| 42358742084 | Throwaway branch: HEAD with only the S3 nudge pass removed | `--only` the three S3 tests | 0 passed, 3 failed, each at its final assertion (fix proven) |
| 42355350677 | HEAD plus `VerifyDailyTravelClaimTests` (not committed) | `--only SimpleGLPTests/VerifyDailyTravelClaimTests` | 0 passed, 2 failed after their preconditions held: "today's reminder was dropped as already claimed", "today's pill logged in Tokyo reads Manual", "the late-dose nudge skips today's unlogged pill" (regression proven) |

No newly failing test in the suite and no infrastructure failures. The throwaway branch was deleted; this branch has only this doc commit on top of what I was given.

Scratch test `VerifyDailyTravelClaimTests` (daily pill at 9:00, plan started in the first zone):
- New York log Oct 22 9:05 EDT, Tokyo Oct 23 7:00 JST. Precondition: `nextDue` (Home) is Oct 23 9:00 JST. Asserts the first reminder slot is Oct 23 9:00 JST (HEAD: Oct 24), a log at 9:05 JST is not `.extra` (HEAD: `.extra`), and the 14:00 nudge target is Oct 23 9:00 (HEAD: Oct 24).
- Delhi log Oct 22 9:05 IST, New York Oct 22 7:00 EDT. Precondition: Home says Oct 22 9:00 EDT is due. Asserts the first reminder slot is Oct 22 9:00 EDT (HEAD: Oct 23).

## Screens

`gh-sim all` run 42362236611, weekly seed:
- `-uitesting -GLPScreenshotSeed`: One Tap card reads "Due today" with the warning triangle, November 7, 8:30 AM, with the clock past 8:30. Overdue mark and headline render in the new `TimelineView`; layout unchanged.
- `-uitesting -GLPScreenshotSeed -GLPScreenshotDueSoon`: "Due today", 10:35 AM, no triangle while the dose is still ahead.

## Device checks left open

- S10 across midnight and across the dose time with the app backgrounded or the phone locked, then unlocked. The UI test proves only the foreground minute tick.
- S8 Live Activity end time after a wait change (the test keeps Pro off to leave Live Activities out).
- S6 airplane-mode cold start, "I refilled", then `pendingNotificationRequests()` (the test fakes the unresolved state with the DEBUG seam).
- S7 on a device: snooze a real reminder, backfill another day, confirm the snooze still fires.

## Notes

- Minor, not a failure: `TimelineView(.everyMinute)` passes the start of the current minute as `timeline.date`. For a non-pill plan with a 1-day cadence, the daily rule at `ScheduleEngine.swift:148` needs `timestamp <= now`, so for up to a minute after logging, the card can still show today's dose as due. Weekly plans are unaffected.
- `testHomeUndoAfterHealthSettlesRestoresTodaysNudge` waits at most 10 s for the Health read (`StateMachineNotificationFixTests.swift:330`). On one runner it did not settle in time. It passed on HEAD and in the S3 proof run, but it can flake on a slow runner.
- The fixes doc cites commits `d9448f8` and `53a5e57` and branch `fleet/20261106-195641-16eb-claude`. On this branch those are `3506196` and `ccfac84`.
- The tracked `SimpleGLP.xcodeproj` was not regenerated for the three new test files; gh-sim runs `xcodegen generate`. Run it after pulling.
