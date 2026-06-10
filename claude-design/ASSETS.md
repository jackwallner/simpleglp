# Asset Manifest — Simple GLP

Every asset the app ships with, with exact spec and **destination path** in the
Xcode project (`~/simpleglp/`). PNGs are sRGB. `@3x` is the master; `@2x`/`@1x`
downscaled. Illustrations: flat, 2–3 colors from `BRAND.md`, no photos.

## A · App identity
| File | Spec | Destination |
|---|---|---|
| `icon-source.svg` | Vector master | `claude-design/output/` (source) |
| `appicon-1024.png` | 1024×1024, sRGB, **no alpha, no rounded corners** | `SimpleGLP/Assets.xcassets/AppIcon.appiconset/` |

Icon concept: single bold mark — a soft droplet with a confident check inside, or
the "Jab" mascot face. Must read at 40px. Background `brand`, mark `surface`.

## B · The shot button (Home — the centerpiece)
| File | Spec | State |
|---|---|---|
| `shot-button-idle@3x.png` | 660×660 (220pt), transparent | resting; inviting soft glow |
| `shot-button-pressed@3x.png` | 660×660 | pressed/darker `brand-pressed` |
| `shot-button-success@3x.png` | 660×660 | check burst, "done" |
| `success-burst.json` | Lottie, ≤600KB, ≤1.5s | plays after tap (gentle, not confetti-spammy) |
→ `SimpleGLP/Assets.xcassets/ShotButton.imageset/` (+ `Resources/` for Lottie)

## C · Onboarding (5 full-width top illustrations, 1080×1080 @3x)
| File | Scene |
|---|---|
| `onb-01-welcome@3x.png` | Jab waving — "Track your shot in one tap" |
| `onb-02-plan@3x.png` | Pen + calendar — pick drug & day |
| `onb-03-reminder@3x.png` | Soft bell — "We'll nudge you weekly" |
| `onb-04-weight@3x.png` | Scale + Apple Health, relaxed — "Only if you want" |
| `onb-05-done@3x.png` | Jab thumbs-up — "That's it. Seriously." |
→ `SimpleGLP/Assets.xcassets/Onboarding/`

## D · Tab glyphs (5 tabs × idle+selected = 10, 96×96 @3x, transparent)
`tab-home`, `tab-log`, `tab-history`, `tab-insights`, `tab-settings` — each
`-idle` (stroke, `text-muted`) and `-selected` (filled, `brand`).
→ `SimpleGLP/Assets.xcassets/Tabs/`

## E · Empty states (3, 720×720 @3x, Jab + one calm line)
`empty-injections@3x.png`, `empty-symptoms@3x.png`, `empty-weight@3x.png`
→ `SimpleGLP/Assets.xcassets/EmptyStates/`

## F · Paywall
`paywall-hero@3x.png` — 1080×900, Jab + calm "Simple GLP Pro" lockup, not pushy.
→ `SimpleGLP/Assets.xcassets/Paywall/`

## G · Widget (point sizes per WidgetKit; provide @2x and @3x)
| File | Size | State |
|---|---|---|
| `widget-small-idle` | 158×158pt | tappable shot button |
| `widget-small-logged` | 158×158pt | check + "Logged" |
| `widget-medium-idle` | 338×158pt | button + "Next shot: <day>" |
| `widget-medium-logged` | 338×158pt | check + next-shot date |
→ `SimpleGLPWidget/Assets.xcassets/`

## H · Apple Watch
`watch-shot-glyph@2x.png` — 88×88, simple high-contrast button/complication glyph.
→ `SimpleGLPWatch/Assets.xcassets/`

## I · App Store marketing screenshots
Device-framed, on-brand bg, big caption bar. **Two sizes each:** 6.9"
(1290×2796) and 6.5" (1242×2688). 5 frames. Lead with `peptide tracker`
keyword cluster — our highest pop/diff term. **No drug names in headlines**
(Ozempic, Wegovy etc. are in the ASC subtitle for search indexing — screenshots
sell simplicity, not drugs):

| Order | File prefix | What to screenshot | Headline | Keyword cluster |
|-------|-------------|-------------------|----------|-----------------|
| 1 | `store-1-onetap` | Home — the giant shot button, clean state | "The simplest GLP-1 tracker. One tap." | peptide tracker, glp1 tracker, one tap |
| 2 | `store-2-log` | Log hub — dose, injection site, notes | "Log your shot, dose, and site. That's it." | dose log, shot log, injection site log |
| 3 | `store-3-schedule` | Schedule — weekly cadence, auto-reminder | "Weekly schedule. Reminds you automatically." | weekly injection, injection schedule |
| 4 | `store-4-watch` | Apple Watch + Home Screen widget together | "Widget and Watch. From your wrist." | apple watch widget, watch shot log |
| 5 | `store-5-private` | Privacy or gentle stats card | "Private. On-device. No account needed." | private shot tracker, healthkit |

→ `fastlane/screenshots/en-US/`

## J · Engineering tokens
`tokens.json` — all `BRAND.md` colors (light+dark hex), radii, spacing scale,
type scale. I consume this to wire `AppAppearance.swift`.
→ `claude-design/output/`

## Deliverable
Drop all files in `claude-design/output/` plus an `output/MANIFEST.md` listing
`filename → destination path` (copy the Destination column above).
