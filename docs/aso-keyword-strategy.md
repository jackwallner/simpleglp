# ASO keyword strategy — Simple GLP (US)

**Data snapshot:** 2026-05-25 · Astro MCP · **SimpleGLP** app `105` · prelaunch (ranks mostly #1000 until live)

## The mix (popularity vs difficulty)

| Bucket | Rule | What you do |
|--------|------|-------------|
| **Attack** | pop ≥ 5 and diff ≤ 35, **or** brand terms (Ozempic, Mounjaro…) with pop ≥ 18 and diff ≤ 55 | Subtitle, screenshot #1–3, description opener |
| **Siege** | pop ≥ 45 and diff ≥ 70, or generic giants (`health`, `weight loss`) | ASC **keyword field** only; months to move |
| **Intel** | Competitor names (`shotsy`, `meagain`, `glapp`) | Track in Astro; never put in ASC copy |
| **Ignore** | Single-word generics at low pop, wrong category (`weight tracker`, `glucose tracker`) | Delete in Astro UI |

**Sweet-spot ratio:** `popularity ÷ difficulty` — aim for **≥ 0.25** on phrases you own in copy.

---

## Attack — optimize now

Lead marketing and creative around these (best pop/diff tradeoffs first):

| Keyword | Pop | Diff | Why |
|---------|-----|------|-----|
| **peptide tracker** | 40 | 21 | Best ratio in category; GLP-1 searchers overlap peptide apps |
| **shotsy** | 55 | 38 | #1 competitor brand query — intercept with “simpler / private” |
| **glp1 tracker** | 30 | 51 | Core category head term |
| **mounjaro** | 25 | 41 | Brand search, moderate difficulty |
| **zepbound** | 25 | 47 | Brand search |
| **ozempic** | 22 | 47 | Brand search |
| **wegovy** | 23 | 55 | Brand search |
| **dose log** | 5 | 7 | Easiest win — matches “log dose later” UX |
| **shot log** | 5 | 13 | One-tap positioning |
| **injection schedule** | 5 | 13 | Weekly schedule feature |
| **glp-1 injection** / **glp1 injection** | 5 | 13 | Literal use case |
| **injection site log** | 5 | 15 | Differentiator vs bare trackers |
| **weekly injection** | 5 | 15 | Schedule engine |
| **ozempic dose** / **mounjaro dose** | 5 | 15–17 | Brand + feature |
| **glp-1 shot** | 5 | 23 | Tight product fit |
| **ozempic shot** | 5 | 21 | High intent |
| **private shot tracker** | 5 | 52 | “Private by design” — worth copy tests |
| **one tap glp** | 5 | 50 | Matches hero UX |

**Brand + tracker combos** (keep in Astro, reinforce in description):  
`ozempic tracker`, `wegovy tracker`, `mounjaro tracker`, `zepbound tracker`, `semaglutide tracker`, `tirzepatide tracker`, `shot tracker`, `injection tracker`.

---

## Siege — keyword field + patience

High volume, high difficulty — do **not** waste subtitle characters here:

| Keyword | Pop | Diff | Notes |
|---------|-----|------|-------|
| **health** | 68 | 79 | Too broad |
| **weight loss tracker** | 61 | 76 | Dominated by diet apps |
| **weight loss** | 56 | 83 | Same |
| **apple health** | 60 | 65 | You’re HealthKit *read* — say that in description, not field |
| **tracker** | 52 | 81 | Meaningless alone |
| **weight** | 45 | 80 | Generic |
| **shot** | 30 | 82 | Sports noise |

---

## Ignore — remove in Astro UI

Low ROI or wrong intent (MCP cannot delete):

- `health app`, `weight tracker`, `healthkit tracker`, `glucose tracker`, `widget tracker`, `watch complication`
- Lone tokens you already cover in phrases: `glp-1`, `injection`, `semaglutide`, `tirzepatide` (unless you want them for field experiments)

---

## Recommended App Store Connect copy

Apple indexes **name + subtitle + keyword field** together. **Never repeat a word** across the three — duplicates waste the 100-char keyword budget (comma-separated, **no spaces**: `KEY,WORD,CYX`).

### Name (30 chars max) — **updated**

| | |
|--|--|
| **Was (ASC)** | `Easy GLP - Simple GLP1 Tracker` (30) |
| **Now (repo)** | `Easy GLP - GLP-1 Shot Tracker` (29) |

**Indexes from name:** Easy, GLP, GLP-1, Shot, Tracker → covers `glp-1 shot tracker`, brand **Easy GLP**.

### Subtitle (30 chars max) — **updated**

| | |
|--|--|
| **Was** | *(empty)* |
| **Now** | `One-Tap Widget · Watch Log` (28) |

**Indexes from subtitle:** One-Tap, Widget, Watch, Log — **no repeat** of Shot/GLP-1/Tracker (already in name).

### Keyword field (100 chars max) — **updated**

| | |
|--|--|
| **Was** | `GLP-1,shot,injection,tracker,…,weight,health` (100) — repeated `tracker`, siege `health`/`weight` |
| **Now** | `ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,peptide,reminder,injection,private,dose` (**93 chars**) |

| Token | Role |
|-------|------|
| ozempic, wegovy, mounjaro, zepbound, semaglutide, tirzepatide | Brand **Attack/Siege** (not in name/subtitle) |
| peptide | Best pop/diff ratio (40/21) |
| reminder, injection, private, dose | Feature **Attack** terms |

**Deliberately NOT in field** (already indexed elsewhere): `glp1`, `shot`, `widget`, `watch`, `log`, `tracker`, `health`, `weight`.

**Room left:** 7 chars — e.g. add `,site` (4+1) if you want injection-site indexing in field.

Upload when ready:

```bash
./scripts/upload-appstore-metadata.sh   # if present, or fastlane upload_metadata
```

---

## Astro: what to track (~100 terms)

**Files:**

- `scripts/astro-keywords-us.json` — curated sync list  
- `scripts/astro-keyword-buckets.json` — attack / siege / mid / ignore  
- `scripts/.astro-app.json` — app `105` SimpleGLP  

**Priority tag in Astro UI (weekly):**  
`peptide tracker`, `glp1 tracker`, `shotsy`, `mounjaro`, `zepbound`, `ozempic`, `wegovy`, `dose log`, `shot log`, `glp-1 shot`, `ozempic tracker`, `apple watch widget`, `one tap glp`

**Re-sync:**

```bash
ASTRO_APP_NAME=SimpleGLP ./scripts/sync-astro-keywords.sh
```

---

## Screenshots ↔ keywords

| Order | Keyword cluster | Headline direction |
|-------|-----------------|-------------------|
| 1 | glp1 tracker · one tap | “Log your GLP-1 shot in one tap” |
| 2 | apple watch widget · watch shot | “Apple Watch + Home Screen widget” |
| 3 | dose log · injection site | “Dose, site, notes — when you want them” |
| 4 | weekly injection · injection schedule | “Weekly schedule that knows early vs late” |
| 5 | private shot tracker · healthkit | “Private, on-device, optional Health context” |

Do **not** lead with competitor names; use them only in comparison-style caption if at all.

---

## Description opener (first 2 sentences)

Include: **one tap**, **GLP-1 shot**, **Apple Watch**, **widget**, **private**, **weekly schedule**, **injection site**, **dose log**.

Example:

> **Simple GLP** is the fastest way to log a **GLP-1 shot in one tap** — from the app, **Home Screen widget**, or **Apple Watch**. Set your weekly schedule, optionally add **dose**, **injection site**, and notes later, and keep everything **private on your device**.

---

## Promotional text (170 chars)

```
Log GLP-1 shots in one tap — iPhone, widget, and Apple Watch. Private weekly schedule, optional dose & site notes, HealthKit context. No account required.
```

---

## What not to chase

| Term | Why skip |
|------|----------|
| calorie counter, workout, golf, basketball | Competitor noise from `glp1 tracker` extraction |
| weight loss tracker (alone) | pop 61, diff 76 — Mounjaro/Ozempic diet clutter |
| glp-1 tracker **app** / **free** | Generic modifiers; low diff value |
| AI glp1 tracker | Not your positioning |

---

## Competitors (search intel)

Top US results for `glp-1 tracker` / `shotsy`: **Shotsy**, **MeAgain**, **Glapp**, GLPTracker, Shot Pal, OneShot.  
Track their brand terms in Astro; differentiate on **privacy**, **one tap**, **no account**, **Watch/widget**.

---

## Measurement plan

| When | Check |
|------|-------|
| Prelaunch | All ranks #1000 — baseline only |
| Day 7 after live | `glp1 tracker`, `peptide tracker`, `dose log`, `shot log` |
| Day 14 | Subtitle A/B if you tested alternates |
| Day 30 | Any term breaks top 200; promote to screenshot #1 |

**Win conditions (30 days post-launch):**

- `glp1 tracker` or `peptide tracker` → top 100  
- `dose log` or `shot log` → top 50  
- `shotsy` → top 80 (conquest)  
- One brand combo (`ozempic tracker`) → top 150  

---

## Files changed in this iteration

- `fastlane/metadata/en-US/keywords.txt` — optimized field  
- `fastlane/metadata/en-US/subtitle.txt` — Attack-term subtitle  
- `scripts/astro-keywords-us.json` — curated ~100 keywords  
- `scripts/astro-keyword-buckets.json` — bucket labels  
