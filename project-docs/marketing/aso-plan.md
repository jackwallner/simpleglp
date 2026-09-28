# aso-plan.md — Simple GLP ASO Plan

> Updated 2026-06-26. App: **Simple GLP: GLP-1 Shot Tracker** (ID `6770137909`). Methodology: `~/Desktop/aso.md`.

---

## 0. TL;DR — the outside-the-box play

**Stop trying to win the same SERP as Shotsy.** Everyone fights on drug-name subtitles + `glp1 tracker`. You have 1 review; they have 26k. That game is unwinnable for years.

**Play a different game:** own the **capture mechanism** — Watch + widget + one-tap + private/on-device. Nobody in the GLP-1 SERP leads with that. Your screenshots already sell it; metadata and promo text didn't.

| Layer | Action | When |
|---|---|---|
| **Promo text** | Watch/widget wedge copy | **Today** (live, no review) |
| **Subtitle** | `GLP1 Shot Widget & Watch` | v1.0.2 |
| **Keywords** | All drug names in field (moved out of subtitle) + `private` | v1.0.2 |
| **Screenshots** | Ship `claude-design` frames (watch frame #4, widget in #6) | v1.0.2 |
| **Reviews** | Prompt after 1st successful shot log | Product — ship ASAP |
| **DROP** | `shotsy` keyword bid | Bad intent — navigational searches want Shotsy |

---

## 1. Why the old approach failed

1. **Repo ≠ live ASC** — staged changes never shipped on v1.0.1.
2. **Wrong fight** — `glp1 tracker` (pop 53) @ 1000 is an authority wall, not a metadata gap.
3. **Shotsy bid** — ranks you #73 on a term where searchers want Shotsy, not you.
4. **Same subtitle as 50 clones** — `GLP1 Ozempic Wegovy Zepbound` makes you interchangeable at rank #40–#80 on combo terms where nobody scrolls.
5. **Wedge was invisible** — Watch, widget, one-tap, private are in description/release notes but not subtitle or screenshot-adjacent metadata.

---

## 2. Competitive repositioning

**Old position:** "Another GLP-1 tracker" (competes with Shotsy on their terms)

**New position:** "The lazy weekly shot logger — tap from wrist or widget" (competes on *how you log*, not which drug)

| Competitor | Their story | Your counter |
|---|---|---|
| Shotsy / MeAgain | Full GLP-1 lifestyle hub, 26k reviews | One tap a week. No bloat. |
| Glippy / Shot Pal | Drug names in subtitle | Drug names in keywords; subtitle sells Watch+widget |
| PeptidePal | Peptide calculator SERP | Not your market — never chase `peptide` |
| Medisafe / pill apps | Generic medication | You own *weekly injection* rhythm |

**Target searcher:** someone who just started a GLP-1, wants the shot recorded, doesn't want a spreadsheet or social features. They search `ozempic shot`, `weekly injection`, `shot reminder` — pop 5 each, but **intent matches**.

---

## 3. Metadata — ship on v1.0.2

### Subtitle (30 char max)
```
GLP1 Shot Widget & Watch
```
24/30 chars. Puts `widget`, `watch`, `shot`, `glp1` at subtitle weight. **First in category to lead with capture surface.**

### Keywords (100 char max)
```
ozempic,wegovy,zepbound,mounjaro,semaglutide,tirzepatide,injection,weekly,reminder,dose,private
```
94/100 chars.

**Critical:** drug names move from subtitle → keywords so the word pool isn't lost. `private` = privacy wedge (`private glp tracker` already #97).

**OUT:** `shotsy` (bad intent), `peptide` (wrong SERP), `diary`, `med`, `schedule` (cycle 2 if `dose` indexes)

### Promotional text (live now — no version needed)
```
Log your weekly GLP-1 shot from Apple Watch or your Home Screen widget — one tap, no account, no bloat. Private and on-device.
```

### Title (unchanged)
```
Simple GLP: GLP-1 Shot Tracker
```
Owns `simple glp` #1, `simple shot tracker` #1.

---

## 4. What actually drives installs (ranked)

1. **Screenshot 1 + conversion** — you're #37–#43 on combo terms; page-1 scrollers decide in 2 seconds. Frame 1 must echo search ("one-tap GLP-1 shot tracker"). Frame 4 = Watch. Frame 6 = widget mention.
2. **Review velocity** — 1 review → invisible on head terms. Prompt after first shot; make leaving a review frictionless.
3. **Combo-term rankings climbing** — `ozempic shot` #43, `zepbound shot` #30, `shot reminder` #37, `tirzepatide shot` #39. These have *right intent*. Metadata supports them; screenshots close them.
4. **Promo text** — test Watch/widget messaging live before locking subtitle on next version.
5. **Keyword metadata** — marginal alone. Necessary hygiene, not growth engine.

---

## 5. Walls (do not chase)

| Term | Pop | Rank | Why |
|---|---|---|---|
| `glp1 tracker` / `glp 1 tracker` | 31–53 | 1000 | Shotsy/MeAgain/MFP wall |
| `shotsy` | 55 | 73 | Navigational — they want Shotsy |
| `peptide tracker` | 55 | 1000 | PeptidePal SERP |
| `reminder` / `schedule` singles | 51–55 | 1000 | Apple Reminders / calendars |
| `weight loss tracker` | 61 | 1000 | MFP/Noom wall |

---

## 6. Overflow — es-MX → US index

Fill `fastlane/metadata/es-MX/keywords.txt` with Spanish wedge words not in en-US field:
`widget,reloj,privado,sin cuenta,inyección semanal,recordatorio`
(verify SERP intent per word before shipping)

---

## 7. Product levers (build roadmap)

- **In-app review prompt** after 1st shot logged (not on launch)
- **Widget onboarding** — show "Add widget" after first shot (screenshot promise → product delivery)
- **Settings → "Rate Simple GLP"** visible after 2nd shot
- Optional v1.1: **injection site rotation** UI surfacing (unlocks `injection site` cluster, diff 17–21)

---

## 8. Rollout sequence

1. **Now:** push promotional text to ASC (editable live).
2. **v1.0.2:** subtitle + keywords + new screenshots + review prompt.
3. **Manual release** — not auto; don't ship mid re-index of current climb.
4. **Week 1 post-release:** watch `ozempic shot`, `shot reminder`, `widget` combos; confirm drugs still index after subtitle move.
5. **Month 1:** if reviews > 20, re-test `glp1 tracker` wall.

---

## 9. Astro tags

| Tag | Keywords |
|---|---|
| `deployed` | ozempic, wegovy, zepbound, mounjaro, semaglutide, tirzepatide, injection, weekly, reminder, dose, private |
| `target` | ozempic shot, zepbound shot, shot reminder, weekly injection, tirzepatide shot, private glp tracker, simple shot tracker |
| `wall` | glp1 tracker, glp 1 tracker, shotsy, peptide tracker, weight loss tracker |
