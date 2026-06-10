# Claude Design prompt — App Store screenshots (link local code: ~/simpleglp)
# Paste everything below this line after linking the repo.

Produce exactly 6 finished App Store screenshot PNGs and nothing else. No
preamble, no explanations, no alternates, no extra frames, no manifest, no
follow-up questions.

## Context in the linked repo

- `claude-design/raw/` — real device screenshots of the shipping app. These
  are ground truth for layout, spacing, color, and type. Match them exactly.
- `claude-design/BRAND.md` — brand tokens. `SimpleGLP/Views/` — the SwiftUI
  source for every screen, if you need to confirm a detail.

## Hard output spec

- Every file exactly **1320 × 2868 px, portrait** (iPhone 6.9" App Store
  size — same resolution as the raws). PNG, sRGB, no transparency. If you
  cannot hit exact pixels, match the 1320:2868 aspect ratio precisely at max
  resolution; never crop.
- Filenames: `store-1-onetap.png`, `store-2-log.png`, `store-3-reminders.png`,
  `store-4-watch.png`, `store-5-patterns.png`, `store-6-dark.png`.

## What these must do

Sell **Simple GLP** — the laziest GLP-1 injection tracker — to someone who
just searched: **glp-1 shot tracker, peptide tracker, shot log, dose log,
weekly injection reminder**. Headlines echo those exact terms so the search
is visually confirmed in frame 1. Tone: calm, effortless, zero judgment.
**No drug brand names (Ozempic, Wegovy, Mounjaro, Zepbound) anywhere.**

## Frame anatomy (identical treatment across all 6)

- Canvas: warm off-white `#FAF8F4` (`#121212` for frame 6), optional soft
  radial wash of `#2FBF71` at ≤8% opacity.
- Headline: SF Pro Rounded heavy, `#1A1A1A` (`#F2F2F2` on frame 6),
  ~115 px, top of canvas, max 2 lines. Subline: SF Pro Rounded regular,
  `#7A7A7A`, ~55 px, one line. At most one `#2FBF71` accent per frame.
- Device: modern iPhone frame, centered, lower ~74% of canvas, soft shadow.

## Screen content — recreate, don't paste

Rebuild each screen pixel-faithful to its raw (same layout, type, colors,
tab bar, status bar at 9:41 full battery) but with the idealized data below.
Do not invent UI elements that aren't in the raws or the SwiftUI source.

1. `store-1-onetap.png` — recreate `raw-1-onetap-hero-light.png`.
   Data: header "You took your shot. Nice. See you next week." · next-dose
   card "In 7 days / June 17, 2026 / 9:00 AM / Dose 0.5 mg" · green
   "I took my shot" button · Last few shots: "June 10, 2026 / 9:04 AM /
   On schedule".
   Headline: `The one‑tap GLP‑1 shot tracker`
   Subline: `Tap once a week. That's the whole app.`

2. `store-2-log.png` — recreate `raw-2-history-light.png` filled with a real
   history. "Jun 2026": Jun 10 · 0.5 mg, Jun 3 · 0.5 mg. "May 2026": May 27
   · 0.5 mg, May 20 · 0.5 mg, May 13 · 0.25 mg, May 6 · 0.25 mg. "Apr
   2026": Apr 29 · 0.25 mg, Apr 22 · 0.25 mg. Every row ~9:00 AM with a
   green "On schedule" badge — the dose increase from 0.25 to 0.5 must be
   visible.
   Headline: `Your shot log & dose schedule`
   Subline: `Every dose, date, and increase — tracked for you.`

3. `store-3-reminders.png` — recreate `raw-3-proactive-alerts-light.png`
   with "Enable Proactive Alerts" ON and "Predict from your patterns" ON
   (green), quiet hours 10 PM–7 AM as shown.
   Headline: `Never miss a weekly shot`
   Subline: `Set your shot day once. We handle the reminders.`

4. `store-4-watch.png` — Apple Watch (Series 10, midnight) device frame
   instead of an iPhone, larger in frame, showing
   `raw-w1-watch-idle.png` as-is (do not redraw the watch UI).
   Headline: `Log it from your wrist`
   Subline: `One tap on Apple Watch. Phone stays in your pocket.`

5. `store-5-patterns.png` — recreate `raw-4-patterns-light.png`.
   Data: Schedule adherence "96% on schedule" / "23 of 24 shots logged
   within the expected window." · Timing pattern "Most shots on Wednesday"
   · Proactive Alerts row as shown.
   Headline: `Gentle insights. 100% on‑device.`
   Subline: `Private by design — no account, no cloud, no judgment.`

6. `store-6-dark.png` — recreate `raw-5-onetap-hero-dark.png` (dark mode
   hero) with the same idealized data as frame 1, on the `#121212` canvas.
   Headline: `Easy on you. Easy on your eyes.`
   Subline: `Full dark mode, widget, and Apple Watch included.`

Deliver the 6 PNGs. Nothing else.
