# Simple GLP — Design Handoff

This folder is a self-contained brief for a Claude design session. It does **not**
ask for "a website" or generic mockups — it specifies the exact, named assets the
**Simple GLP** iOS app will ship with, mapped to where each one is used in the build.

## How to use

1. Open a Claude design session.
2. Paste the entire contents of **`PROMPT.md`** as the first message. It is fully
   self-contained (brand system + audience + every asset spec are inline — the
   design session does not need this repo).
3. Have it deliver every file named in the prompt's manifest into `output/`.
4. I (Claude Code) wire the delivered assets into the Xcode project using
   `output/MANIFEST.md`, which maps each file to its destination path.

## Files

| File | Purpose |
|---|---|
| `PROMPT.md` | **The thing you paste.** Self-contained. Brand + audience + full asset manifest. |
| `CONTEXT.md` | App + screen map + audience psychology (reference for you/me). |
| `BRAND.md` | The visual system as the source of truth (colors, type, mascot). |
| `ASSETS.md` | The asset manifest with in-app destination paths. |
| `output/` | Where the design session drops delivered assets + its `MANIFEST.md`. |

## The one idea everything serves

After a 60-second setup, the entire app is **one big button you tap when you take
your shot**. The design must make that button the most inviting thing on screen and
make everything else feel optional and weightless. We sell *the easy way out* — and
we make the easy way the right way.
