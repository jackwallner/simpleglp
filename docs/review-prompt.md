# App Store review prompt (Simple GLP)

Three-layer funnel (enjoyment sheet → write-review URL or feedback mailto; native `requestReview()` only after “Maybe later” on the pitch). Playbook: `~/Desktop/app-store-5-star-review-strategy.md`.

| Constant | Value |
|----------|--------|
| App Store ID | `6770137909` |
| Feedback | `jackwallner@gmail.com` |
| App group | `group.com.jackwallner.glp` |
| Positive moment A | Shot logged (One Tap tab) |
| Positive moment B | CSV export generated |
| Avoid | Cold launch, onboarding, paywall sheet, errors |

**Code:** `SharedGLP/Services/ReviewPromptTracker.swift`, `SharedGLP/Utilities/AppStoreReviewLinks.swift`, `SimpleGLP/Views/ReviewPromptSheet.swift`, host `RootTabView.swift`.
