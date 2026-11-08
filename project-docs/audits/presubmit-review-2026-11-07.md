# Pre-submit review: Simple GLP 1.2.5 (2026-11-07)

Scope: app sources changed since the live App Store version. App Store Connect lists
1.2.4 as READY_FOR_DISTRIBUTION and 1.2.5 as PREPARE_FOR_SUBMISSION. The 1.2.5 bump is
`3e522c4`, so the diff is `3e522c4^..55996ce` (origin/main, build 70) over `SimpleGLP/`,
`SharedGLP/`, `SimpleGLPWidget/`, `SimpleGLPWatch/` and `project.yml`. Tests, docs, qa/
and fastlane/ were left out.

Changed: 13 Swift/plist files (+176/-56) and 2 new catalog keys ("Language",
"Opens iOS Settings"). The work is the state machine audit fixes (schedule claims across
time zones, freed-slot rematch, late-dose nudge rescheduling, wait ping retiming, snooze
kept for backfills, cached-Pro refill alert, per-minute Home card) plus the Settings
Language row.

## Result

No P0 or P1 found. Nothing was changed in app code.

Checked and clean:
- Crashes: no new force unwraps, subscripts or throwing decodes. No SwiftData schema
  change. The new `@MainActor` drops (`ScheduleEngine.isOccurrenceClaimed`, `claim`) are
  synchronous and only called from main-actor code.
- Purchase and paywall: no change to `SimplePaywallView`, `TrialOfferSheet`, offerings or
  restore. `StoreService.setLocalOverride(resolved:)` is inside `#if DEBUG`. The refill
  guard now also runs for cached Pro, which cannot unlock a free user.
- State: launch and resume still ingest widget shots before `refresh`, so the new
  `syncWait` there reads fresh history. Wait-end and late-dose requests keep fixed
  identifiers, so repeated resumes replace rather than duplicate them. `refresh` never
  prompts for notifications from resume (`mayPrompt: false`).
- App Review: the Language row opens `openSettingsURLString` only. The DueSoon seed is
  inside `#if DEBUG`. No new health claims, prices or platform links.
  `Tools/Localization/check.py`: 534 keys, 10 languages, 0 problems.

## Findings

| Severity | Location | What happens | Status |
| --- | --- | --- | --- |
| P2 | `SimpleGLP/Services/ProactiveAlertsEngine.swift:92` | With `rearmPastDue: false` (plan save, resume, history change) a past-due occurrence returns before `cancelLateDoseNudge()`. If a Pro user with alerts on moves today's dose earlier on a plan save, past the 4 hour grace (say 6:00 PM to 8:00 AM at 2:00 PM), the nudge already queued for 10:00 PM still fires and names the old time. | Not fixed: needs alerts on, a same-day time edit and grace already passed. It still fires for a dose that really isn't logged. Choosing between dropping it or re-arming it now is a product call. |
| P2 | `SimpleGLP/Services/DoseRoutineService.swift:91`, `ProactiveAlertsEngine.swift:53` | New in 1.2.5: the launch `refresh` runs `schedulePatternAlertsIfEnabled`, and before entitlements resolve `isActive` treats the user as Pro. The check runs once, then the task awaits several times before adding requests. If RevenueCat resolves a lapsed Pro user as free during those awaits, the resolve-time cancel can run first and the launch task re-adds pattern alerts or the late-dose nudge afterwards. | Not fixed: only lapsed Pro users who left alerts on are affected, and it depends on task timing. Not reproduced. A safe fix is to check `isActive` again just before each `add`. |

## Tests

Not run. I submitted `gh-sim test --scheme SimpleGLP --only SimpleGLPTests` (run
`simpleglp@20261107-230040-cb3f-claude-mbpro37291-1107-230951-8278`, GitHub Actions
42457644047) at 07:09 UTC. It was still queued after the 90 minute limit: GitHub's Macs
showed 0 of 5 free, with runs stuck in progress since 07:20 and 24 runs queued. No app code
changed in this review, so the result applies to origin/main as is. Fetch it later with
`gh-sim get <id>`.

## Second pass (2026-11-08)

Scope: app sources changed on origin/main since the first pass, `55996ce..f1dde37`
(build 70 to 73). That range merges the live 1.2.4 fixes from `ship/1.2.4` (the
pre-setup overdue rule in `ScheduleEngine`) and adds the accessibility and layout work:
contrast colors (`brandFill`, `brandText`, `warmText`, high contrast variants), 44pt
targets, paywall and onboarding layouts at accessibility sizes, the paywall status line
that now carries purchase and restore errors, a Home card that re-renders at midnight and
the dose time instead of every minute, and the Duo bar inset. 21 files, +608/-269. The
review branch now merges origin/main, so the fix below applies to current main.

Checked and clean:
- Crashes: no new force unwraps, subscripts, throwing decodes or model changes.
  `DoseClockSchedule` returns an endless lazy sequence and its `next(after:)` always moves
  forward, so the timeline cannot stall or spin.
- Home card: `nextDue` only turns over at local midnight or at the plan's time of day, and
  those are the two moments the new schedule ticks. A log re-renders the card through
  `@Query` and `cardClock` still reads the real clock.
- Purchase and paywall: products, packages, purchase and restore logic are unchanged.
  Purchase and restore errors now replace the trial line in the reserved status slot and
  are cleared at the start of every attempt. Terms, Privacy Policy and Restore remain on
  the paywall, the trial sheet and the onboarding trial step at every text size. The
  benefit list moves under the buy button at accessibility sizes, prices stay from
  StoreKit.
- App Review: no new strings with health claims, prices or other platforms. Watch and
  widget compile `AppTheme.swift` and the new colors resolve on watchOS through the dark
  branch. `Tools/Localization/check.py`: 534 keys, 10 languages, 0 problems.

| Severity | Location | What happens | Status |
| --- | --- | --- | --- |
| P1 | `SimpleGLP/Views/RootTabView.swift:661` | New in build 73: `PaneBarInset` wrapped each tab in `if isOn { GeometryReader { content } } else { content }`, with `isOn` being "unfolded". Every fold or unfold of an iPhone Duo gave the tab content a new view identity, so SwiftUI rebuilt the tab's `NavigationStack`. A user editing their plan in Settings who opens or closes the phone is popped back to the Settings root with the edits lost, and an open Edit Dose or Took It Earlier sheet on One Tap is dismissed. This breaks the rule that folding only moves frames. | Fixed: one branch for both states, the padding and safe area edge depend on `isOn`. No unit test: view identity is not reachable from `SimpleGLPTests`. |
| P2 | `SimpleGLP/Services/ScheduleEngine.swift:202` | From the live 1.2.4 merge: a weekly occurrence due before the plan was created is never treated as overdue. Onboarding defaults "First dose" to today 9:00 AM, so someone who sets up the app at 2:00 PM on their shot day and has not taken it yet sees "In 7 days" and gets no late-dose nudge for today. The rule exists for users mid-regimen who enter their last dose, which is the opposite reading of the same input. | Not fixed: product call, already live in 1.2.4. Logging today still records the dose. |
| P2 | `SimpleGLP/Services/ProactiveAlertsEngine.swift:92`, `DoseRoutineService.swift:91` | The two notification timing risks from the first pass. | Still open, no change on main. |

## Second pass tests

Passed. `gh-sim test --scheme SimpleGLP --only SimpleGLPTests` on the branch with the fix
(run `simpleglp@20261108-075713-1383-claude-imac0875-1108-075940-13179`, GitHub Actions
42497575201): Xcode 27.1, iPhone 17 on iOS 27.2, 148 passed, 0 failed, 0 skipped. The build
covers the app, widget and Watch targets compiled with the new colors.
