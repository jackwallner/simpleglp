---
paths:
  - "SimpleGLP/Utilities/ReadableWidth.swift"
  - "SimpleGLP/Utilities/UnfoldedSplit.swift"
  - "SimpleGLP/Views/**"
  - "SimpleGLP/Info.plist"
  - "project.yml"
---

# Simple GLP: iPad layout (2026-11-12)

iPad support is free: `TARGETED_DEVICE_FAMILY "1,2"` on the app only (the widget
and the Watch app are untouched), all four orientations
(`UISupportedInterfaceOrientations~ipad`), Split View and Slide Over allowed.

- **One column, centred.** Scrolling screens (Home, History, Patterns, Settings,
  Supply, plan editor, Pro alerts, Export, Import) call `.readableWidth()`
  (640 pt). It sets horizontal `contentMargins`, so the scroll view, its
  background and its indicators still span the window. Never frame a List or
  Form to a width: the grouped background would stop at the frame.
- **Fixed screens** (onboarding, paywall) use `.centeredColumn()` (560 pt). The
  paywall scrolls on iPad (`scrolls`) because its sheet height varies.
- **No Duo split on iPad.** `UnfoldedSplit` and `unfoldedLeadingPane` are for the
  unfolded iPhone Duo; call sites pass `!UIUserInterfaceIdiom.isPad`, otherwise a
  wide iPad window would split into two phone panes.
- Sheets are system form sheets on iPad (detents are ignored), so sheet content
  must scroll and never assume a phone height.
- New screens: add `.readableWidth()` or `.centeredColumn()`, keep phone widths
  unchanged (both are no-ops below their cap), no iPad-only labels or copy.
- Captures: `gh-sim test --scheme SimpleGLPUITests --device "iPad Pro 13-inch (M5)" --only SimpleGLPUITests/IPadLayoutTourTests`
  rotates with `XCUIDevice.orientation` and attaches every screen in portrait and
  landscape (frames land in `attachments/manifest.json`). App Store 13-inch frames
  are 2064x2752.