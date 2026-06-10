# ASO keyword strategy — Simple GLP (US → 50 locales)

**Data snapshot:** 2026-06-09 · Astro MCP app `105` · prelaunch

## The indie truth

We're not beating Shotsy (25K ratings) or MeAgain (18K ratings) on head terms. This strategy is about **winnable pop/diff** — terms where:
- pop ≥ 5 and diff ≤ 25 → **instant win** (put in subtitle, screenshots, description)
- pop ≥ 18 and diff ≤ 55 → **brand conquest** (drug names, competitor names)
- pop ≥ 45 and diff ≥ 70 → **keyword field only** (don't waste subtitle chars)

**Sweet spot:** `popularity ÷ difficulty ≥ 0.5` on anything in copy.

## What changed from v1

| Aspect | Old (v1) | New (v2) |
|--------|----------|----------|
| Subtitle strategy | Feature-based (`One-Tap Widget · Watch Log`) | Drug-name-based (matches competitor format) |
| `peptide tracker` pop | 40 | **51** (Astro actual) |
| Keyword field | 96 chars, included drug names | 97 chars, drug names moved to subtitle |
| Description | Generic opener | Weaves high-value keywords in first 2 sentences |
| Competitor targets | Shotsy + MeAgain + Glapp | Added Pep, Glowise, Dose AI, Glapp |

## Competitor subtitle analysis (US App Store)

| App | Subtitle | Strategy |
|-----|----------|----------|
| **Shotsy** | `GLP1 Zepbound, Wegovy, Peptide` | Drug names indexing |
| **MeAgain** | `Wegovy Pill Zepbound GLP1 Shot` | Drug names + format |
| **Glapp** | `Zepbound Wegovy Ozempic GLP1` | Drug names only |
| **Pep** | `Zepbound Ozempic Mounjaro GLP1` | Drug names only |
| **Glowise** | `Ozempic Wegovy Mounjaro Pill` | Drug names + pill |
| **Dose AI** | `For Zepbound, Wegovy, Ozempic` | Drug names with "For" |
| **Our old** | `One-Tap Widget · Watch Log` | **Zero search indexing** |

**Lesson:** Every competitor uses subtitle for drug name SEO. We must too.

## Proposed App Store Connect copy (en-US)

### Name (30 chars) — keep

```
Simple GLP: GLP-1 Shot Tracker   (30)
```

**Indexes:** Simple, GLP, GLP-1, Shot, Tracker → covers `glp-1 shot tracker`, `simple glp`.
**Brand note:** `easy glp` and `simple glp` are both popularity 5 (ASO-neutral), so the
brand word follows the binary — CFBundleDisplayName, paywall, and legal pages all say
"Simple GLP" (Guideline 2.3 consistency; standardized 2026-06-04).

### Subtitle (30 chars) — NEW

```
GLP1 Ozempic Wegovy Zepbound   (28)
```

**Indexes:** GLP1, Ozempic, Wegovy, Zepbound → covers `glp1`, `ozempic`, `wegovy`, `zepbound`.  
**Why:** Every competitor does this. Frees 12+ chars from keyword field.

### Keyword field (100 chars) — NEW

```
peptide,semaglutide,tirzepatide,mounjaro,injection,dose,weekly,private,reminder,dose log,shot log   (97)
```

| Token | Pop/Diff | Why it's here |
|-------|----------|---------------|
| peptide | catches `peptide tracker` 51/21 | **#1 winnable** — best ratio in category |
| semaglutide | — | Drug name not in subtitle |
| tirzepatide | — | Drug name not in subtitle |
| mounjaro | — | Drug name not in subtitle |
| injection | 5/21 | Covers `injection tracker`, `injection log`, `injection site` |
| dose | — | Core term, covers `dose log`, `dose tracker` |
| weekly | — | Covers `weekly injection`, `weekly shot log` |
| private | — | Differentiator |
| reminder | — | Feature term |
| dose log | 5/7 | **Ultra winnable** — instant win |
| shot log | 5/13 | **Ultra winnable** — instant win |

**Not in field (already indexed in name/subtitle):** glp1, glp-1, ozempic, wegovy, zepbound, shot, tracker, easy.

### What changed from keyword field v1

| Drug | v1 (in keywords) | v2 (moved to subtitle) |
|------|-------------------|----------------------|
| ozempic | ✅ keyword field | ✅ subtitle |
| wegovy | ✅ keyword field | ✅ subtitle |
| zepbound | ✅ keyword field | ✅ subtitle |
| mounjaro | ✅ keyword field | ✅ keyword field |
| semaglutide | ✅ keyword field | ✅ keyword field |
| tirzepatide | ✅ keyword field | ✅ keyword field |

**Net gain:** `peptide` + `weekly` + `dose log` + `shot log` now fit in keyword field.

## Attack buckets (all locales)

### Tier 1 — Instant win (put in subtitle + screenshot 1–2 + description)

| Keyword | Pop/Diff | Ratio | Why |
|---------|----------|-------|-----|
| **peptide tracker** | 51/21 | 2.42 | Best in category; Astro confirmed 51/21 |
| **dose log** | 5/7 | 0.71 | Zero competition |
| **shot log** | 5/13 | 0.38 | Ultra winnable |
| **injection site log** | 5/15 | 0.33 | Differentiator |
| **weekly injection** | 5/15 | 0.33 | Schedule feature |
| **glp-1 injection** | 5/13 | 0.38 | Literal use case |
| **glp1 injection** | 5/13 | 0.38 | Literal use case |
| **injection schedule** | 5/13 | 0.38 | Schedule feature |
| **injection** | 5/21 | 0.23 | Core term, low diff |
| **injection tracker** | 5/21 | 0.23 | Core term |
| **injection log** | 5/21 | 0.23 | Core term |
| **glp-1 shot** | 5/23 | 0.21 | Core term |
| **glp-1 reminder** | 5/23 | 0.21 | Feature term |
| **ozempic dose** | 5/15 | 0.33 | Brand + dose |
| **mounjaro dose** | 5/17 | 0.29 | Brand + dose |
| **semaglutide log** | 5/21 | 0.23 | Drug + log |
| **tirzepatide log** | 5/17 | 0.29 | Drug + log |
| **ozempic shot** | 5/21 | 0.23 | Brand + shot |

### Tier 2 — Brand conquest (subtitle + field)

| Keyword | Pop/Diff | Ratio | Note |
|---------|----------|-------|------|
| **shotsy** | 55/38 | 1.44 | #1 competitor brand |
| **zepbound** | 25/47 | 0.53 | In subtitle |
| **ozempic** | 22/47 | 0.46 | In subtitle |
| **wegovy** | 23/55 | 0.41 | In subtitle |
| **mounjaro** | 25/41 | 0.60 | In keyword field |
| **zepbound tracker** | 23/49 | 0.46 | Drug + function |
| **glp1 tracker** | 29/51 | 0.56 | Core category term |
| **mounjaro tracker** | 9/39 | 0.23 | Low pop but low diff |
| **ozempic tracker** | 9/41 | 0.21 | Low pop but low diff |
| **meagain** | 26/66 | 0.39 | Competitor (field only) |
| **glapp** | 5/23 | 0.21 | Competitor (field only) |

### Tier 3 — Siege (keyword field only)

| Keyword | Pop/Diff | Note |
|---------|----------|------|
| health | 68/79 | Too broad |
| weight loss | 56/83 | Diet app dominated |
| weight loss tracker | 61/76 | Same |
| tracker | 52/81 | Meaningless alone |
| weight | 45/80 | Generic |
| weight tracker | 54/70 | Not our category |
| apple health | 60/65 | HealthKit integration mention |
| shot | 31/82 | Sports noise |

## Screenshots ↔ keywords

| Order | Keyword cluster | Headline direction |
|-------|-----------------|-------------------|
| 1 | glp1 tracker · one tap · peptide tracker | "The simplest GLP-1 tracker. One tap." |
| 2 | shot log · dose log · injection site | "Dose, site, notes — log what matters." |
| 3 | weekly injection · injection schedule | "Weekly schedule. Automatic reminders." |
| 4 | apple watch widget · watch shot | "Widget + Watch. From your wrist." |
| 5 | private · healthkit · on-device | "Private by design. No sign-up needed." |

**Lead with `peptide tracker`** in screenshot #1 — it's our highest pop/diff ratio and the "peptide" framing differentiates from generic "shot trackers."

## Description opener

```
Simple GLP is the fastest peptide tracker and shot log — log your weekly GLP-1 injection in one tap from iPhone, Apple Watch, or Home Screen widget. No accounts, no spreadsheets. Just a private dose log that works around your routine.
```

Weaves in: peptide tracker, shot log, weekly, GLP-1 injection, one tap, private, dose log.

## Promotional text (170 chars)

```
Log your GLP-1 shot in one tap — iPhone, widget, and Apple Watch. Private weekly dose log with optional injection site notes and HealthKit context. No account required. (158)
```

## What not to chase

| Term | Why skip |
|------|----------|
| calorie counter, workout, golf, basketball | Competitor noise from `glp1 tracker` extraction |
| weight loss / weight loss tracker | Diet app dominated (pop 56+/diff 76+) |
| AI glp1 tracker | Not our positioning |
| health / tracker / weight | Generic single words, high diff |
| glp-1 tracker free | Modifier, low value |
| glucose tracker | Different use case |

## Competitor landscape (US)

| App | Rating | Subtitle | Our angle vs them |
|-----|--------|----------|-------------------|
| **Shotsy** | 4.8 · 25K | GLP1 Zepbound, Wegovy, Peptide | Simpler, one-tap, no bloat |
| **MeAgain** | 4.8 · 18K | Wegovy Pill Zepbound GLP1 Shot | Private, no account needed |
| **Glapp** | 4.9 · 483 | Zepbound Wegovy Ozempic GLP1 | Less complex, widget-first |
| **Pep** | 4.7 · 773 | Zepbound Ozempic Mounjaro GLP1 | One-tap vs full food diary |
| **Glowise** | 4.8 · 958 | Ozempic Wegovy Mounjaro Pill | Focused shot tracker |
| **Dose AI** | — | For Zepbound, Wegovy, Ozempic | Privacy positioning |

## Localization strategy (50 locales)

For every locale:
1. **Subtitle** → translate `GLP1 [local drug names]` format (brand drug names stay global)
2. **Keywords** → native translations of feature terms (`dose log`, `shot log`, `weekly`, `private`, `reminder`, `injection`, `peptide`)
3. **Description** → keep existing native translations, update opener to weave keywords
4. **Name** → keep existing native names with the `Simple GLP` brand word (e.g., `Simple GLP: GLP-1 Spritzen-Log` for de-DE) — brand must match the binary in every locale

## Measurement plan

| When | Check |
|------|-------|
| Prelaunch | All ranks #1000 — baseline only |
| Day 7 after live | `dose log`, `shot log`, `peptide tracker`, `glp1 tracker` |
| Day 14 | Subtitle ranking for `ozempic`, `wegovy`, `zepbound` |
| Day 30 | Any term breaks top 200; promote winner to screenshot #1 |

**Win conditions (30 days post-launch):**
- `peptide tracker` → top 100
- `dose log` or `shot log` → top 50
- Any drug brand in subtitle → top 150
- `shotsy` → top 100 (conquest)

## Astro tracking updates

- Add to `scripts/astro-keywords-us.json`: `peptide tracker`, `dose log`, `shot log` (if missing)
- Remove from tracking: single-word generics that won't move (`health`, `weight`, `shot`)
- Tag `peptide tracker` as priority — it's our #1 opportunity
