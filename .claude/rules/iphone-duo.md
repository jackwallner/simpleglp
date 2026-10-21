---
paths:
  - "SimpleGLP/Views/RootTabView.swift"
  - "SimpleGLP/Views/HistoryView.swift"
  - "SimpleGLP/Utilities/UnfoldedSplit.swift"
  - "SimpleGLP/Views/OnboardingView.swift"
  - "SimpleGLPTests/UnfoldedSplitTests.swift"
---

# Simple GLP: iPhone Duo (2026-10-21)

- Unfolded (regular width, room for two panes of at least 360 pt),
  `RootTabView` puts the tab view (One Tap, Patterns, Settings and its bar) on
  the leading side of the fold and History in its own pane on the trailing
  side; the History tab leaves the bar while split. Pane edges come from
  `GeometryProxy.verticalFold()` (iOS 27.1 `reservedRegions(.division)`), else
  an even split (`UnfoldedSplit`, tested in `UnfoldedSplitTests`). Folded, every
  ordinary iPhone and the unfolded Duo in portrait keep the single column.
- Folding only moves frames: the `TabView` is never rebuilt. History moves
  between its tab and the pane, so its month lives in `RootTabView`
  (`historyMonth`). Keep new History state there.
- Each tab's content and the History pane get `horizontalSizeClass = .compact`,
  so they lay out as on a phone. Never set it on the `TabView` itself (in Quit
  Zyn that flipped the Duo's vertical bar to a bottom bar on a tab switch).
- Onboarding uses `.unfoldedLeadingPane`, with `OnboardingFoldPanel` in the
  trailing pane. Sheets (paywall, trial offer, log earlier, edit) are still
  system form sheets centred on the inner display.
- Captures: `gh-sim all --device 'iPhone Duo' --wait 10 --record-seconds 120
  --env TZ=Australia/Adelaide --args "-uitesting -GLPScreenshotSeed
  -GLPScreenshotPill -GLPScreenshotPro -GLPDuoTour"` plus `--url noop://1`
  through `noop://9`. The noop URLs fail fast and only pace shots (`simctl
  openurl` to a real scheme raises an alert on iOS 27). Pick `TZ` so the
  runner's UTC clock reads mid-morning, when a pill is taken (Adelaide fits a
  dispatch around 22:40 UTC). `-GLPDuoTour` (DEBUG) loops 13 s per screen,
  because when the first shot lands varies by runner: One Tap, History,
  Patterns, Settings folded, or One Tap, Patterns, Supply, Settings unfolded.
  `GLPDUOTOUR` lines in app.log map shots to steps.
