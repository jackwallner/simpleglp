# State machine audit, 2026-11-06

Scope: iOS app, `SharedGLP`, widget and Watch targets, committed code at `b7a790b` (working tree was clean, nothing to stash). No backend function exists in the repo; entitlements come from RevenueCat through `StoreService`. Nothing was fixed. Android is out of scope.

**Summary: 10 bugs. 7 proved by a failing test (each with a passing control), 3 code path only. Plus 9 product calls (not counted).**

Run: `gh-sim test --scheme SimpleGLP --only SimpleGLPTests/StateMachineAuditRepro`, run id `simpleglp@20261106-114403-a9bc-claude-mbpro8acf-1106-121438-29727`, Xcode 27.1, iPhone 17, iOS 27.2, runner clock and zone UTC. Result: 12 tests, 4 passed (all controls), 8 failed (the 8 bug assertions). Suite: `state-machines-2026-11-06-repro.swift` (copy into `SimpleGLPTests/` to run). Every failing test asserts its own preconditions first, so each failure message below is the claim line and not a broken setup.

## Test seams in this repo

Existing: in-memory `ModelContainer` (`SimpleGLPTests.swift`), `StoreService(products:introEligibility:defaults:)` with a throwaway defaults suite, `StoreService.setLocalOverride(isPro:)` (DEBUG), `TestStoreProduct`/`Package` fixtures (`PaywallFunnelTests`), `ConversionDiagnostics.defaultsOverride`, explicit `calendar:` and `now:` parameters on `ScheduleEngine`, `DailyAdherence`, `SupplyMath`, and `GLPAppGroup.userDefaults` (real suite, saved and restored by the suite). Not available: any injection point for `UNUserNotificationCenter` (every scheduler calls `.current()`), a constructible `CustomerInfo`, a clock. For notifications the suite adds `FakeNotificationCenter`, which swaps the six `UNUserNotificationCenter` instance methods the app uses for an in-memory request table (and a fake `UNNotificationSettings`) inside the test process only, and restores them in `tearDown`. The Pro flag is set with `setLocalOverride`. No RevenueCat key is configured (simulator branch of `StoreService`). The three code-path bugs need a real `CustomerInfo` failure, a UI clock or sibling-event edit, none of which any seam reaches.

## Bugs, ranked by users reached times cost

| Id | Bug | What the user sees | Promise | User route | Impact | Evidence | file:line |
|---|---|---|---|---|---|---|---|
| S1 | A logged weekly shot reads unclaimed after the device moves west | Home says "Overdue by 1 day", widget, Watch and Siri say the shot is not logged, until the next dose is logged | `ScheduleEngine.swift:145-148` "the overdue or next slot no logged shot has claimed, so a shot taken a day early doesn't leave that week reading 'due'" | Weekly shot plan, log on time on One Tap, fly or drive to a zone behind the old one (New York to Los Angeles), open Home | Weekly shot users who cross a westward zone within a dosing week, up to 6 days of a false overdue for a dose already taken (risk of a second shot); no Pro needed | Test, failing | `ScheduleEngine.swift:64-69`, `:182-190`; stored claim `ShotCaptureCoordinator.swift:101` |
| S2 | "Dose slipping?" nudge fires inside quiet hours | A push at night for an overdue dose with "Don't alert at night" on | `ProAlertsConfigView.swift:46` toggle "Don’t alert at night"; `ProactiveAlertsEngine.swift:123` "shifted forward out of quiet hours if needed" | Pro, Proactive Alerts on, quiet hours on (default 22:00 to 07:00), a dose more than 4 h overdue, open or log in the app between 22:00 and 07:00 | Pro with alerts on who miss a dose and use the app at night; every scheduler pass re-arms it | Test, failing | `ProactiveAlertsEngine.swift:90-91` |
| S3 | Undo, delete and edit never restore the late-dose nudge | After Undo of today's pill, no "Dose slipping?" comes today although the pill is unlogged | `ProAlertsConfigView.swift:25` "you get a second nudge if today’s pill isn’t logged a few hours after its time"; `ProactiveAlertsEngine.swift:65-67` nudge follows the occurrence | Pro, alerts on, daily pill: One Tap, "I took my pill", Undo (or History swipe delete, or import) | Pro with alerts on who undo or delete a dose; nudge reappears only on the next log or cold launch | Test, failing (undo and delete), control passing | `DoseRoutineService.swift:29-43`, call-site list in M4 |
| S4 | Permission granted later never reaches the nudge | Alerts toggle on, notifications enabled in iOS Settings afterwards, nudge never scheduled until a log or cold launch | `ProAlertsConfigView.swift:25`; `ReminderService.swift:169-171` background refreshes schedule when already allowed | Pro, alerts on while notifications denied, iOS Settings > Notifications > allow, return to the app | Pro with alerts on who denied the first prompt; dose reminders do reconcile (control), the nudge does not | Test, failing, control passing | `DoseRoutineService.swift:66-73`, `SimpleGLPApp.swift:182-188` |
| S5 | Plan save does not retime the nudge | Nudge keeps the old time after the user moves the pill time | `ProactiveAlertsEngine.swift:65-67`; `SettingsView.swift:350` refresh after save | Pro, alerts on: Settings > Medication & schedule > change Time > Save | Pro with alerts on who edit the time; self-heals at next log or cold launch | Test, failing | `SettingsView.swift:350`, `DoseRoutineService.swift:66-73` |
| S6 | Offline cold start leaves entitlements unresolved for the whole process | After refilling, an old "Refill soon" still fires; refill alerts never reschedule | `SupplyView.swift:90-91` footer "You’ll get a heads-up about 7 days before you run out"; `StoreService.swift:259-263` resolved flag | Pro with supply tracking, launch in airplane mode, Settings > Supply & refills > "I refilled: set to 30", restore network | Pro with refill tracking launching offline while the app stays alive | Code path | `StoreService.swift:596-606`, `:627-635`, `DoseRoutineService.swift:134`, `ReminderService.swift:138` |
| S7 | A backdated log cancels today's snoozed reminder | The "Remind me in 15 min" reminder for a dose still owed vanishes | `ReminderService.swift:39-40` "Once a dose is logged, its reminders are stale" (that dose's) | Tap Snooze on today's reminder, History > Log a past dose for two days ago | Users who snooze and backfill in the same 15 minutes; tiny | Test, failing | `DoseRoutineService.swift:15`, `ReminderService.swift:41-45` |
| S8 | Changing the wait mid-countdown leaves the ping at the old time | Home counts down to 10 minutes, the "wait is over" ping arrives 20 minutes later | `PillRoutineView.swift:215` "We’ll ping you when it’s over." | Pill with a wait running: Settings > Medication & schedule > change the wait > Save | Pill users editing the wait during a countdown; tiny | Test, failing | `DoseRoutineService.swift:66-73`, `ReminderService.swift:115-128` |
| S9 | Editing or deleting a claiming dose leaves its sibling "Manual" | History and "% on schedule" keep a duplicate as Manual, the slot reads unclaimed | `InsightsView.swift:104` "Schedule adherence", `:110-111` "logged within the expected window" | Weekly: log, log again the same week (second is Manual), History > open the first > move its date a week earlier or delete it | Users with a duplicate log they fix by editing or deleting the first one; small drift in adherence | Code path | `EditEventSheet.swift:195-203`, `HistoryView.swift:168-182`, `ScheduleEngine.swift:64-80` |
| S10 | Home shot card is not re-derived when the clock passes midnight or the dose time | "Tomorrow" or "In 1 days" stays after the day rolled over; the overdue marker does not appear | `SimpleGLPWidget.swift:25` the widget refreshes "midnight rolls every day count"; `HomeView.swift:238` "Due today" | Weekly shot plan, leave Home on screen (or the app suspended) across midnight or across the planned time, return to One Tap | All weekly shot users who return to a long-lived process; cost is a stale label | Code path | `HomeView.swift:179-181`, `:238-247` (no `TimelineView`, compare `PillRoutineView.swift:25`) |

### Evidence and detail

**S1** `testLoggedShotStaysClaimedAfterTravellingWest` failed with: `after flying to Los Angeles the logged shot is not claimed: nextDue = 2026-10-22 16:00:00 +0000, Home reads "Overdue by 1 day"` (expected `2026-10-29 16:00:00 +0000`). Preconditions asserted: the shot matched `.onSchedule` in New York, and the same instant read with the New York calendar gives next Thursday (control). `testControlEastwardTravelKeepsTheClaim` passed: eastward the recomputed slot is earlier than the log, so the `timestamp >= overdue` guard at `ScheduleEngine.swift:189` hides the problem. Cause: `scheduledDate` is stored as an absolute instant (13:00 UTC for Thursday 9:00 EDT) and `isOccurrenceClaimed` (`:164-170`) and `isClaimed` (`:64-69`) compare it with a slot recomputed in the current zone (16:00 UTC for 9:00 PDT). The test uses explicit calendars rather than `NSTimeZone.default`. Related effects of the same mismatch: the next log in the new zone does not see the old claim, so a second shot in the same week can be marked on schedule; the Pro nudge fires for the already-logged dose (`ProactiveAlertsEngine.swift:78`).

**S2** `testLateDoseNudgeNeverFiresInsideQuietHours` failed: `nudge scheduled for 2026-11-06 20:42:00 +0000, inside quiet hours 20:00-22:00`. Preconditions: now is inside the window, `lateDoseFireDate` pushes a slot whose +4 h lands in quiet hours out of it (control inside the same test), the dose is overdue by more than 4 h. Cause: `max(requestedFireDate, now + 60 s)` runs after the quiet-hour shift. Note the same line re-arms the nudge at now + 60 s on every scheduler pass while the dose stays overdue (product call 9).

**S3** `testUndoRestoresTheLateDoseNudgeForTheUnloggedDose` failed: `today's pill is unlogged again, nudge should fire at 2026-11-07 00:11:00 +0000 but is at 2026-11-08 00:11:00 +0000 (log had moved it to 2026-11-08 00:11:00 +0000)`. `testDeletingTodaysDoseRestoresTheLateDoseNudge` failed the same way (`stays at 2026-11-08 00:10:00 +0000, should be 2026-11-07 00:10:00 +0000`). Preconditions asserted: nudge exists, the log moves it a day, the event is gone. `testControlSchedulerRunningAgainRestoresTheNudgeAfterUndo` passed: a scheduler pass fixes it, none runs. Import and Edit (time change) route through the same `historyDidChange`.

**S4** `testLateDoseNudgeReconcilesWhenPermissionIsGrantedLater` failed: `enabled Proactive Alerts nudge never scheduled after permission was granted`, after asserting nothing was pending while denied, the toggle on, and the dose reminder `simpleglp.next-shot` reconciled by the same `refresh`. `testControlDoseReminderReconcilesWhenPermissionIsGrantedLater` passed.

**S5** `testPlanSaveRetimesTheLateDoseNudge` failed: `nudge still at 2026-11-07 00:11:00 +0000 (old slot), plan now says 2026-11-06 22:41:00 +0000` (90 minutes off; the precondition asserts the edit moves the correct answer by more than 20 minutes).

**S6** Code path. `updateCustomerProductStatus` sets `hasResolvedEntitlements = true` only in its success branch (`StoreService.swift:600`). Its callers are `start()` (`:310`), `refreshPendingPurchaseStatus` (`:579`) and `LogDoseIntent`; none runs on foreground. `apply(customerInfo:)` (the delegate path) never sets it. With the flag false `rescheduleReminders` returns at `DoseRoutineService.swift:134` before `scheduleRefillReminder`, whose first line (`ReminderService.swift:138`) is the only thing that removes the old `simpleglp.refill` request. Promo sheets are also withheld (`RootTabView.swift:477`), which is the safe side. What would settle it: a `Purchases` seam that throws on `customerInfo(fetchPolicy:)`, or a device run in airplane mode through the route above and `UNUserNotificationCenter.pendingNotificationRequests()` afterwards. Not tested because the simulator branch of `StoreService` sets the flag unconditionally (`:305`, `:339`, `:591`).

**S7** `testBackdatedLogKeepsTodaysSnoozedReminder` failed: `today's snoozed reminder was cancelled by a log for another day`, after asserting the snooze was pending and no dose exists for today.

**S8** `testChangingTheWaitMidCountdownRetimesThePing` failed: `Home says the wait ends 2026-11-06 20:50:46 +0000, the ping fires 2026-11-06 21:10:46 +0000` (1200 s apart). Precondition asserted: before the edit Home and the ping agree within 60 s.

**S9** Code path. `EditEventSheet.save` re-matches only the edited event (`:195-203`); `HistoryView.performPendingDeletion` re-matches nothing; only a plan save runs `PlanStore.recalculateScheduleMatches`. The sibling keeps `scheduledDate == nil`, `.extra`. Settles with a UI test or a test that replicates the sheet's 8 lines; replicating them here would test my copy, not the sheet.

**S10** Code path. `nextShotSection` reads `.now` in `body` and nothing invalidates `HomeView` at midnight or at the dose time. Whether SwiftUI re-runs the body on foreground without a dependency change is not established here. What would settle it: a UI test that moves the clock, or a device left overnight on the weekly One Tap screen.

## Product calls (not counted, no promise cited or documented rule)

1. Live Activity is not started when a pill is logged from the Watch, widget or a notification with the phone locked (`LiveActivityService.swift:5-6` documents it).
2. A plan save rewrites every past event's schedule status (`PlanStore.swift:30-32` documents it); changing the start day or time silently changes history and "% on schedule".
3. The Home "Undo" button (`HomeView.swift:55`) has no timeout and no description; `showUndoOption` is only reset by Undo (`ShotCaptureCoordinator.swift:125`, `:196`), so in a long-lived process it still deletes the last captured dose days later, and a Watch or widget ingest retargets it to that newer dose. Undo also does not reverse the review-moment counter or the first-shot trial trigger.
4. Editing a dose's time keeps the Health context read at the original time under the "That day" heading (`EditEventSheet.swift:135`).
5. CSV rows without Health context import as `pending` and are enriched against the old days on the next foreground (`ImportService.swift:71`, `ShotCaptureCoordinator.swift:67-76`).
6. The Proactive Alerts status row is loaded once per appearance (`ProAlertsConfigView.swift:79-86`); it says "Off in Settings" after the user enabled notifications until the sheet is reopened.
7. When the phone drops a Watch double tap, the Watch keeps its own wait countdown for up to 10 minutes (`WatchConnectivityController.swift:80-86`).
8. "Apple reminds you before your trial ends." (`SimplePaywallView.swift:214`, `TrialOfferSheet.swift:299`) and "Reminder day N" (`SimplePaywallView.swift:487`) promise something Apple does not guarantee and the app does not schedule.
9. While a dose stays overdue, every scheduler pass re-arms the nudge at now + 60 s (`ProactiveAlertsEngine.swift:91`), so a cold launch repeats "Dose slipping?" after it already fired.

## Related fixes, in order

1. Notification reconciler (S3, S4, S5, S2, S7, S8): one function that rebuilds every pending request from state, called from `refresh`, `historyDidChange`, plan save, import and scene active; apply quiet hours after the `now + 60 s` clamp; retime `simpleglp.wait-end` in that pass; limit `clearDoseNudges` to a dose near now.
2. Claims (S1, S9): store the claim as a plan occurrence (cadence index or local calendar day) instead of an absolute instant, or compare in the current zone; re-match siblings on edit and delete.
3. Entitlements (S6): set `hasResolvedEntitlements` when cached customer info arrives or retry the fetch on foreground.
4. Home clock (S10): wrap the shot card in a `TimelineView` like `PillRoutineView`.

## State machines

Invariants are numbered per machine (M1.I1 and so on). The "breaks" column of a transition table names the invariant a reachable bad transition violates. Bug ids (S1 to S10) refer to the table above, CALL-n to the numbered product calls.

### M1. Dose record and capture (`ShotEvent`, `ShotCaptureCoordinator`)

States of one `ShotEvent`: `captureStatus` (pending, complete, partial, failed) x `healthStatus` (pending, captured, unavailable, failed). Coordinator state: `isCapturing`, `lastCapturedEventID`, `showUndoOption`, `bannerMessage`, `isEnrichingPendingLogs`.

Invariants
- M1.I1 A saved event with `healthStatus == pending` is eventually enriched (foreground pass) or finalized by its own capture task.
- M1.I2 One id appears once: ids are unique, widget and Watch logs carry their id, `captureShot` returns early on a known id.
- M1.I3 `isCapturing` is true only while a capture task is in flight and always returns to false.
- M1.I4 `Undo` removes only what the log just created and leaves no derived state behind (glance, recent shots, wait ping, Live Activity, reminders, late-dose nudge).
- M1.I5 `showUndoOption` is true only right after a log.

| From | Event | To | Breaks |
|---|---|---|---|
| none | Home tap, Log earlier, Watch, widget ingest, notification "Took it", Siri | event(pending, pending); `lastCapturedEventID` = new id; `showUndoOption` = true | |
| event(pending) | health task returns | event(complete / partial / failed) | |
| event(pending) | `deferHealthContext` log (Siri, notification) | stays pending until next foreground `enrichPendingCapturesIfNeeded` | |
| event | Home "Undo" | deleted; reminders and wait ping reconciled by `historyDidChange` | M1.I4: late-dose nudge not restored (S3) |
| event | History swipe delete or Edit sheet delete or save | `historyDidChange` | M1.I4: same (S3) |
| any | a later capture (Watch, widget ingest, Log earlier) | `lastCapturedEventID` replaced, Undo button now targets the newer event | CALL-3 |
| any | 30 s or 3 days later | `showUndoOption` still true, "Undo" still deletes the last captured dose | M1.I5, CALL-3 |
| event(any) | Edit sheet moves the timestamp | schedule match recomputed for this event only; Health values stay from the old time | CALL-4 |
| event(pending) | app killed during the health task | next launch enriches (fetch descriptor matches `pending`) | |
| any | CSV import of rows without health context | stored `pending`, enriched against old days on next foreground | CALL-5 |

### M2. Schedule claims (`ScheduleEngine`, `scheduleStatus`, `scheduledDate`)

State: per event `scheduledDate` (absolute instant of the slot it claimed, or nil) and `scheduleStatus` (onSchedule, early, late, extra, unknown). Derived: `nextDue`, `nextUnclaimedOccurrence`, `isOccurrenceClaimed` (abs difference under 60 s between `scheduledDate` and a recomputed slot), `upcomingReminderSlots`.

Invariants
- M2.I1 A logged dose for a slot keeps that slot claimed until the dose is edited or deleted.
- M2.I2 `nextDue` is the one answer used by Home, glance (widget, Lock Screen widget, Watch), Siri and the late-dose nudge (AGENTS.md "Next dose has one source").
- M2.I3 Slots are wall-clock times in the current zone; a stored claim must still match the slot it names.
- M2.I4 At most one event claims a slot; the rest are `extra`.

| From | Event | To | Breaks |
|---|---|---|---|
| slot unclaimed | log within window | claimed, status onSchedule / early / late | |
| slot claimed | second log | `extra`, `scheduledDate` nil | |
| slot claimed | device time zone moves west | recomputed slot is a later instant than the stored claim, so the slot reads unclaimed and overdue | M2.I1, M2.I3 (S1) |
| slot claimed | device time zone moves east | recomputed slot is earlier than the log, the `timestamp >= overdue` guard hides it | none (control) |
| slot claimed by A, B extra | A deleted or A's time edited | B stays `extra`, slot is unclaimed, Insights "% on schedule" drops | M2.I4 (S9) |
| any | plan save | `recalculateScheduleMatches` rewrites every event's status | CALL-2 |
| any | midnight passes with Home open | the weekly Home card is not re-evaluated until some other state changes | S10 |

### M3. Pill wait countdown (derived, no stored state)

There is no `waiting` flag. The state is the conjunction of: the newest dose today and `plan.effectiveWaitMinutes` (Home `PillRoutineView.waitEnd`), `GLPGlance.waitEndsAt` (widget, Watch, Siri), the pending `simpleglp.wait-end` request, and the Live Activity (Pro).

Invariants
- M3.I1 All four views of the wait agree on the end time while it runs.
- M3.I2 After an undo, delete, edit or plan change they are re-derived together.
- M3.I3 The ping is scheduled only when the dose is not in the past.

| From | Event | To | Breaks |
|---|---|---|---|
| idle | log pill (waitMinutes > 0) | glance, ping, Live Activity (Pro, foreground) all set from the log time | |
| waiting | undo, delete, edit time | `historyDidChange` re-derives ping and activity | |
| waiting | plan save with new waitMinutes | Home and glance use the new length, ping and activity keep the old end | M3.I1, M3.I2 (S8) |
| waiting | plan save changes pill to shot | glance is no longer a pill, ping still pending | M3.I2 (S8) |
| waiting | Pro lapses | activity runs out by itself | |
| idle | log from Watch or widget with app suspended | glance set, ping set at next foreground, no Live Activity | CALL-1 (documented) |

### M4. Notification set (`ReminderService`, `ProactiveAlertsEngine`)

State is the table of pending requests: `simpleglp.next-shot[-n]` (up to 14 daily or 8 longer), `simpleglp.wait-end`, `simpleglp.refill`, `simpleglp.snooze`, `glp-late-dose`, `glp-pattern-<weekday>`, plus iOS permission and the Pro and resolved flags. Scheduler call sites, complete:

| Request | Writer | Called from |
|---|---|---|
| next-shot slots | `ReminderService.scheduleNextShotReminder` via `DoseRoutineService.rescheduleReminders` | `refresh` (launch, scene active, plan save, onboarding), `historyDidChange`, `settleBackgroundLog`, `captureShot` health task, `SupplyView.persist`, `SimpleGLPApp` resolved and Pro `onChange` |
| refill | `scheduleRefillReminder` via `rescheduleReminders` | same list, only if `hasResolvedEntitlements` |
| wait-end | `scheduleWaitEnd` / `cancelWaitEnd` | `didLogDose`, `historyDidChange`, `settleBackgroundLog` (nothing on `refresh` or plan save) |
| snooze | `ReminderService.snooze` (notification action) | removed by `clearDoseNudges` in `didLogDose` |
| late-dose, pattern | `ProactiveAlertsEngine.schedulePatternAlertsIfEnabled` | `SimpleGLPApp.swift:192` and `:199` (resolved and Pro `onChange`), `ProAlertsConfigView.swift:132`, `ShotCaptureCoordinator.swift:62` and `:171`, `DoseRoutineService.swift:116` (nothing on `refresh`, `historyDidChange`, plan save, import, scene active) |

Invariants
- M4.I1 After any change to doses, plan or permission, every pending request matches what the app would schedule from scratch.
- M4.I2 Nothing fires for a dose that is logged.
- M4.I3 Quiet hours are never violated by a Pro alert.
- M4.I4 A background path never prompts.

| From | Event | To | Breaks |
|---|---|---|---|
| nudge for slot S | log S | nudge moved to S+1 | |
| nudge for S+1 | undo, delete, edit, import | not rescheduled, S is unlogged and unnudged | M4.I1 (S3) |
| nudge for S | plan time edited | not rescheduled | M4.I1 (S5) |
| denied | user enables in iOS Settings, app foregrounds | dose reminders reconcile (`refresh`), nudge does not | M4.I1 (S4) |
| overdue S (+4 h passed) | any scheduler pass at night | fire = now + 60 s, quiet hours ignored | M4.I3 (S2) |
| snooze pending for today | log a past day | snooze deleted | M4.I2 reversed: a still-owed reminder is dropped (S7) |
| refill pending | offline cold start, entitlement fetch fails | `hasResolvedEntitlements` never set, refill left stale | M4.I1 (S6) |

### M5. Entitlements and purchase (`StoreService`)

State: `isProUnlocked`, `hasResolvedEntitlements`, `customerInfo`, `pendingPurchase` (persisted), `purchaseInFlight`, `isRefreshingPurchase`, `products`, `introEligibility`.

Invariants
- M5.I1 `hasResolvedEntitlements` becomes true once an authoritative customer fetch succeeded, and gates promo sheets, refill reminders and alert expiry.
- M5.I2 `pendingPurchase` exists only between a non-cancelled purchase and Pro becoming true; it blocks a second purchase.
- M5.I3 Pro features turn off when `isProUnlocked` turns false and a resolved fetch agrees.
- M5.I4 No trial copy without confirmed eligibility.

| From | Event | To | Breaks |
|---|---|---|---|
| unresolved | `customerInfo` fetch succeeds | resolved, isPro from entitlement or product fallback | |
| unresolved | fetch throws (offline cold start) | stays unresolved for the process lifetime, delegate pushes set isPro but never resolved | M5.I1 (S6) |
| none | purchase ok and Pro true | pending set then cleared at once | |
| none | purchase ok, Pro false | pending persists across launches, purchase returns `.pending` | tested as documented (`PaywallFunnelTests`) |
| pending | refresh sees Pro | cleared, conversion recorded once | |
| Pro | subscription lapses | `isProUnlocked` false: refill request removed, alerts cancelled, activity ends at its own end | |

### M6. Promo and onboarding sheets (`RootTabView`, `OnboardingView`)

State: `activeSheet`, `hasSeenFirstRunOffer`, `hasSeenTrialOffer`, `hasSeenPatternsTrialOffer` (app group defaults), `paywallShownThisSession`, `firstRunPaywallPending/Presented`, `trialPitchScheduled`, `foregroundEpoch`, onboarding `step`.

Invariants
- M6.I1 One root sheet at a time.
- M6.I2 No sheet before entitlements resolve, none for Pro or recent Pro.
- M6.I3 Each pitch is one-shot, marked at present time.
- M6.I4 A delayed presentation does not fire across a backgrounding.

All four hold in the code read: `presentTrialOfferIfReady` and `presentFirstRunOfferIfEligible` re-check every guard after their sleep, the flags are written at present time, the epoch is bumped on `.background`. Two benign overlaps: the 3 s and 4 s pitch tasks can overlap, so `trialPitchScheduled` flips false early (rating ask can run into the pitch); the `.pending` result of `startDirectTrialPurchase` leaves the sheet up with the pending message only.

### M7. Pro alerts preferences (`ProAlertsConfigView`)

State: `proAlertsEnabled`, `patternAlertsEnabled`, quiet hours, sensitivity, `@State notificationStatus` (loaded once per appearance). The toggle can be on while permission is denied (the status row says "Off in Settings", correct) but the row is not refreshed when the user returns from iOS Settings with the sheet open (CALL-6).

### M8. Supply and refill cycle (`SupplyMath`, `refillHeadsUpCycle`)

State: `supplyCount`, `supplyUpdatedAt`, `refillHeadsUpCycle`, `refillHeadsUpFireAt`. Remaining is derived (`doses at or after supplyUpdatedAt`), so undo and delete cannot drift it. Invariant: one heads-up per refill cycle; a passed fire date counts as sent. The cycle key resets on "I refilled". Held in the code read except the unresolved-entitlement case (S6).

### M9. Widget and Watch hand-off

State: App Group `glpPendingWidgetShots` queue, `glpGlance`, `glpRecentShots`, Watch `pendingLocalDoseAt`.
- Widget: tap enqueues, optimistic glance and recent shot, app ingests one shot per call and acknowledges after a successful save; chained ingest after each capture drains the rest. No duplicate guard against a dose already stored (the Watch path has a 120 s guard).
- Watch: optimistic glance kept for 10 minutes unless the phone's glance carries a later dose. When the phone dedupes a double tap, the Watch shows its own countdown for up to 10 minutes while the phone shows the first (CALL-7).

### M10. Review prompt (`ReviewPromptTracker`)

State machine of counters in the app group: launch count, pending positive moment, last shown, outcome. Positive moments are recorded at log time and not reversed by Undo (CALL-3 related), asks are gated by launch count, cooldown, permission-question-open. No reachable invalid state found.

### M11. Live Activity (`LiveActivityService`)

State: ActivityKit activities for `GLPWaitActivityAttributes`. Start only when Pro and in the foreground, `sync` on edit, `endFinished` on refresh, `endAll` when no wait is left. One activity at a time by retiring others. No reachable invalid state found beyond the plan-change case in M3.
