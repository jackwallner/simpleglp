# Brand System — Simple GLP

Theme in one word: **effortless**. Calm, soft, rounded, premium. Anything that
reads clinical, busy, or cheap is wrong — it signals "this will be work."

## Color tokens

| Token | Light | Dark | Use |
|---|---|---|---|
| `bg` | `#FAF8F4` warm off-white | `#121212` | App background |
| `surface` | `#FFFFFF` | `#1E1E1E` | Cards |
| `brand` | `#2FBF71` | `#2FBF71` | **The shot button**, primary action only |
| `brand-pressed` | `#249E5C` | `#249E5C` | Button pressed |
| `calm` | `#5BC0BE` soft teal | `#5BC0BE` | Trust accents, links, secondary |
| `text` | `#1A1A1A` | `#F2F2F2` | Primary text |
| `text-muted` | `#7A7A7A` | `#9A9A9A` | Captions, optional labels |
| `warm` | `#F4A259` | `#F4A259` | Friendly highlights / "next dose" |

Rules: exactly **one** `brand` element per screen (the primary action). Green = "go
/ done / on track" — never used for errors. There is no harsh red error state;
problems are `warm`, phrased gently.

## Type

- Family: **SF Pro Rounded** (native iOS, friendly, on-brand).
- Numbers and the one key message per screen are **huge** (display 40–64pt).
- Body short and large (17–20pt). Few words. Lots of air.

## Shape & layout

- Corner radius **24pt** on cards and the button.
- Primary touch targets **≥ 64pt**; the shot button is **220pt** circular.
- Generous whitespace. One focal point per screen. No dense grids or data tables.

## Mascot — "Jab"

A friendly, rounded **injection-pen blob** with a small calm smile. Flat, 2-color
(`brand` + `text`), single continuous outline, no gradients, works at 24pt.
Personality: chill, encouraging, never excited or preachy. Reused across:
onboarding, empty states, widget success, paywall. Provide a small expression
sheet (idle, waving, thumbs-up, sleeping/"see you next week").

## Iconography

Soft, rounded, 2pt stroke, single weight. Custom tab glyphs (not raw SF Symbols)
so the app feels handmade and calm.
