# Context — Simple GLP

## What it is

A GLP-1 medication tracker for people on weekly injections (Ozempic, Wegovy,
Mounjaro, Zepbound). One of ~5 households now has a user. Most competing apps
(Shotsy, Glapp, MeAgain) pile on food logs, charts, and dashboards.

**Our wedge: be the laziest one.** Setup once. Then a single tap each week when you
do your shot. The app handles dose titration, the reminder, and the schedule
silently. Symptoms / weight / food-noise exist but are never required and never
nag.

## Who it's for (design honestly for this)

People who want the easy way out — and feel a little sheepish about it. Design
implications, in priority order:

1. **Zero friction.** The core action is one tap. Never make them think, type, or
   navigate to log a shot.
2. **Zero judgment.** No scales-as-villain imagery, no "before/after," no calorie
   guilt, no red "you slipped" states. Weight is opt-in and shown gently.
3. **Reassurance over data.** The reward for tapping is a warm "done, you're on
   track — see you next week," not a chart to study.
4. **Effortless = trustworthy.** Calm, soft, rounded, premium. Cheap/clinical reads
   as "this will be work."

## Screen map (where assets land)

| Screen | Role | Key asset |
|---|---|---|
| Onboarding (5 pages) | One-time setup: drug, start date, dose, injection day, reminder, optional Health weight | 5 hero illustrations |
| **Home** | The product. A giant "Log my shot" button + small optional cards below | Shot button (idle/pressed/success) + success animation |
| Log hub | Optional: symptoms, weight, wellbeing | tab glyph, empty states |
| History | Segmented list of past injections/symptoms/wellbeing | tab glyph, empty state |
| Insights (Pro) | Gentle trends; symptom-vs-shot-day, weight vs food-noise | tab glyph, empty state |
| Settings | Edit plan, reminder, units, restore purchase | tab glyph |
| Paywall | "Simple GLP Pro" — calm, not pushy | paywall hero |
| Home-screen Widget | The shot button, on the home screen (idle + logged) | widget art ×4 |
| Apple Watch | "Log shot done" button | watch glyph |
| App Store | Listing | 5 framed marketing screenshots ×2 sizes |

## Voice samples (for any text baked into art)

- "One tap. That's the whole app."
- "You took your shot. Nice. See you next week."
- "Set it once. We'll handle the rest."
- "Only if you want to." (on every optional thing)
- Never: "log your food," "track calories," "you missed," "stay accountable."
