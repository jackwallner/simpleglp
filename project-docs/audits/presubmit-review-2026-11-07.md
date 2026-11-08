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
