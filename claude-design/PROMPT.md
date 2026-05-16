You are designing the complete visual asset set for **Simple GLP — Easy Tracker**,
a native iOS app. This brief is self-contained. Do not produce a website or generic
mockups — produce the specific, named, production-ready asset files listed at the
end, delivered into an `output/` folder with a `MANIFEST.md`.

────────────────────────────────────────
THE PRODUCT (one idea — everything serves it)
────────────────────────────────────────
A tracker for people on weekly GLP-1 injections (Ozempic, Wegovy, Mounjaro,
Zepbound). Every competitor is bloated with food logs and charts. Our entire
pitch: be the laziest one. After a 60-second setup, the whole app is **one big
button you tap when you take your shot.** Dose titration, the weekly reminder, and
the schedule happen silently. Symptoms / weight exist but are never required and
never nag.

────────────────────────────────────────
WHO IT'S FOR (design honestly for this)
────────────────────────────────────────
People who want the easy way out — and feel a little sheepish about it. So:
1. Zero friction — the hero action is ONE tap; nothing to think about.
2. Zero judgment — no scale-as-villain, no before/after, no calorie guilt, no red
   "you slipped" states. Weight is opt-in and shown gently.
3. Reassurance over data — the reward for tapping is a warm "done, you're on track,
   see you next week," not a chart.
4. Effortless = trustworthy — calm, soft, rounded, premium. Clinical or busy or
   cheap reads as "this will be work" and kills it.

────────────────────────────────────────
BRAND SYSTEM (use exactly)
────────────────────────────────────────
Theme word: **effortless**.

Colors — light / dark / use:
- bg            #FAF8F4 / #121212 — app background
- surface       #FFFFFF / #1E1E1E — cards
- brand         #2FBF71 / #2FBF71 — THE shot button & primary action ONLY
- brand-pressed #249E5C / #249E5C — pressed
- calm          #5BC0BE / #5BC0BE — trust/secondary accents, links
- text          #1A1A1A / #F2F2F2
- text-muted    #7A7A7A / #9A9A9A — captions, "optional" labels
- warm          #F4A259 / #F4A259 — friendly highlights, "next dose", gentle alerts
Rules: exactly ONE brand-colored element per screen (the action). Green means
go/done/on-track — never an error color. No harsh red anywhere; problems are `warm`
and phrased kindly.

Type: SF Pro Rounded. The one key message/number per screen is huge (40–64pt).
Body short and large (17–20pt). Few words, lots of air.

Shape: 24pt corner radius on cards & the button. Primary targets ≥64pt. The shot
button is a 220pt circle. One focal point per screen; no dense tables.

Mascot — "Jab": a friendly rounded **injection-pen blob** with a small calm smile.
Flat, 2-color (brand + text), single continuous outline, no gradients, legible at
24pt. Chill and encouraging, never hyper or preachy. Provide an expression sheet:
idle, waving, thumbs-up, sleeping ("see you next week").

Voice for any baked-in text: "One tap. That's the whole app." / "You took your
shot. Nice. See you next week." / "Set it once — we handle the rest." / "Only if
you want to." Never: "log your food," "calories," "you missed," "stay accountable."

────────────────────────────────────────
DELIVERABLES — produce every file, exactly these names
────────────────────────────────────────
PNGs: sRGB. @3x is the master; also export @2x and @1x. Illustrations flat,
2–3 brand colors, no photos. Provide light + dark variants where a screen has both
(suffix `-dark`).

A. App icon
   - icon-source.svg (vector master)
   - appicon-1024.png — 1024×1024, NO alpha, NO rounded corners. Concept: a soft
     droplet with a confident check inside, OR Jab's face. Must read at 40px.
     Background brand, mark surface.

B. Shot button (the centerpiece) — 660×660 transparent each:
   - shot-button-idle@3x.png — resting, inviting soft glow
   - shot-button-pressed@3x.png — brand-pressed
   - shot-button-success@3x.png — gentle check burst
   - success-burst.json — Lottie, ≤1.5s, ≤600KB, calm (not confetti spam)

C. Onboarding — 5 illustrations, 1080×1080 @3x:
   - onb-01-welcome@3x.png — Jab waving, "Track your shot in one tap"
   - onb-02-plan@3x.png — pen + calendar, pick drug & day
   - onb-03-reminder@3x.png — soft bell, "We'll nudge you weekly"
   - onb-04-weight@3x.png — scale + Apple Health, relaxed, "Only if you want"
   - onb-05-done@3x.png — Jab thumbs-up, "That's it. Seriously."

D. Tab glyphs — 96×96 @3x transparent, each in `-idle` (stroke, text-muted) and
   `-selected` (filled, brand): tab-home, tab-log, tab-history, tab-insights,
   tab-settings (10 files). Soft rounded, 2pt stroke.

E. Empty states — 720×720 @3x, Jab + one calm line:
   empty-injections@3x.png, empty-symptoms@3x.png, empty-weight@3x.png

F. paywall-hero@3x.png — 1080×900, Jab + calm "Simple GLP Pro" lockup, not pushy.

G. Widget (@2x and @3x of each, point sizes given):
   - widget-small-idle (158×158pt) — tappable shot button
   - widget-small-logged (158×158pt) — check + "Logged"
   - widget-medium-idle (338×158pt) — button + "Next shot: <day>"
   - widget-medium-logged (338×158pt) — check + next-shot date

H. watch-shot-glyph@2x.png — 88×88, high-contrast simple button/complication glyph.

I. App Store screenshots — device-framed, on-brand background, big caption bar.
   TWO sizes each: 6.9" (1290×2796) and 6.5" (1242×2688):
   1. store-1-onetap — Home — "One tap. That's the whole app."
   2. store-2-setonce — Onboarding — "Set it once. We handle the rest."
   3. store-3-remember — Reminder — "We remember so you don't."
   4. store-4-dose — Titration card — "Your dose, on schedule. Automatically."
   5. store-5-trends — Insights — "See how you're doing — only if you care to."

J. tokens.json — all brand colors (light+dark hex), radii, spacing scale, type
   scale. Engineering consumes this directly.

K. MANIFEST.md — table of every delivered filename → its in-app destination (these
   are: AppIcon.appiconset, ShotButton.imageset, Onboarding, Tabs, EmptyStates,
   Paywall asset catalogs; SimpleGLPWidget/SimpleGLPWatch asset catalogs;
   fastlane/screenshots/en-US; tokens/source to project root).

Put everything in an `output/` folder. Before generating, briefly confirm the
icon concept and mascot look with 2–3 quick options, then produce the full set.
