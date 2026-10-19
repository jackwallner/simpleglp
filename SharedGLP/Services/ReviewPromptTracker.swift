import Foundation

extension Notification.Name {
    /// Posted after a satisfaction moment. The root view may request the
    /// system rating prompt after a short delay, with no question in front of it.
    static let glpPositiveMomentForReview = Notification.Name("com.jackwallner.glp.positiveMomentForReview")

    /// Posted once when the user logs their very first shot — host may present a one-time, dismissible trial offer.
    static let glpFirstShotLogged = Notification.Name("com.jackwallner.glp.firstShotLogged")

    /// Posted when the Patterns (Insights) tab appears — host may consider the second-touch trial offer.
    static let glpPatternsDidAppear = Notification.Name("com.jackwallner.glp.patternsDidAppear")
}

/// What the user did about a review. Only opening the review page ends the
/// passive asks: someone who sent feedback can still rate.
enum ReviewPromptOutcome: String, Sendable {
    /// Opened the App Store write-review page from Settings.
    case openedWriteReview
    /// Sent feedback by mail. Never stops the asks.
    case submittedFeedback
}

/// Persists launch counts, positive moments, and review-prompt eligibility in the app group.
@MainActor
enum ReviewPromptTracker {
    private static let defaults = GLPAppGroup.userDefaults

    private static let launchCountKey = "reviewPrompt.appLaunchCount"
    private static let firstOpenKey = "reviewPrompt.firstAppOpenDate"
    private static let lastShownKey = "reviewPrompt.lastShownDate"
    private static let outcomeKey = "reviewPrompt.outcome"
    private static let positiveMomentCountKey = "reviewPrompt.positiveMomentCount"
    private static let pendingPositiveMomentKey = "reviewPrompt.pendingPositiveMoment"

    /// Ask early. Most installs are gone within a week, and a rating from
    /// someone who logged twice beats no rating at all. The only tenure gate
    /// is "not the first session": a second cold start.
    static let minimumLaunchCount = 2
    /// Days between our calls. Apple shows the prompt at most three times a
    /// year per device and decides each time, so this paces the asks rather
    /// than the user's answers.
    static let cooldownDays = 30

    static var appLaunchCount: Int {
        get { max(defaults.integer(forKey: launchCountKey), 0) }
        set { defaults.set(newValue, forKey: launchCountKey) }
    }

    static var firstAppOpenDate: Date? {
        get { defaults.object(forKey: firstOpenKey) as? Date }
        set {
            if let date = newValue {
                defaults.set(date, forKey: firstOpenKey)
            } else {
                defaults.removeObject(forKey: firstOpenKey)
            }
        }
    }

    static var lastShownDate: Date? {
        get { defaults.object(forKey: lastShownKey) as? Date }
        set {
            if let date = newValue {
                defaults.set(date, forKey: lastShownKey)
            } else {
                defaults.removeObject(forKey: lastShownKey)
            }
        }
    }

    static var outcome: ReviewPromptOutcome? {
        get {
            guard let raw = defaults.string(forKey: outcomeKey) else { return nil }
            return ReviewPromptOutcome(rawValue: raw)
        }
        set {
            if let value = newValue {
                defaults.set(value.rawValue, forKey: outcomeKey)
            } else {
                defaults.removeObject(forKey: outcomeKey)
            }
        }
    }

    static var positiveMomentCount: Int {
        get { max(defaults.integer(forKey: positiveMomentCountKey), 0) }
        set { defaults.set(newValue, forKey: positiveMomentCountKey) }
    }

    static var hasPendingPositiveMoment: Bool {
        get { defaults.bool(forKey: pendingPositiveMomentKey) }
        set { defaults.set(newValue, forKey: pendingPositiveMomentKey) }
    }

    static func recordAppLaunch(now: Date = .now) {
        if firstAppOpenDate == nil {
            firstAppOpenDate = now
        }
        appLaunchCount += 1
    }

    static func recordPositiveMoment() {
        positiveMomentCount += 1
        hasPendingPositiveMoment = true
    }

    static func consumePendingPositiveMoment() {
        hasPendingPositiveMoment = false
    }

    static func passivePromptAllowed(now: Date = .now) -> Bool {
        guard outcome != .openedWriteReview else { return false }
        guard let last = lastShownDate else { return true }
        let cooldown = TimeInterval(cooldownDays) * 86_400
        return now.timeIntervalSince(last) >= cooldown
    }

    static func canRequestReview(hasCompletedSetup: Bool, now: Date = .now) -> Bool {
        guard !ProcessInfo.processInfo.arguments.contains("-uitesting") else { return false }
        guard hasCompletedSetup else { return false }
        guard passivePromptAllowed(now: now) else { return false }
        return appLaunchCount >= minimumLaunchCount
    }

    /// `permissionQuestionOpen` is true only while a system permission alert is
    /// actually on screen. A permission that was never asked (reminders off)
    /// must not block the ask, or those users are never asked to rate.
    static func shouldRequestAfterPositiveMoment(
        hasCompletedSetup: Bool,
        permissionQuestionOpen: Bool = false,
        now: Date = .now
    ) -> Bool {
        guard hasPendingPositiveMoment, !permissionQuestionOpen else { return false }
        return canRequestReview(hasCompletedSetup: hasCompletedSetup, now: now)
    }

    static func markShown(now: Date = .now) {
        lastShownDate = now
        consumePendingPositiveMoment()
    }

    static func markOpenedWriteReview() {
        outcome = .openedWriteReview
        markShown()
    }

    /// Never overwrites `.openedWriteReview`: feedback sent after the review
    /// page must not reopen the asks that page ended.
    static func markFeedbackSubmitted() {
        if outcome != .openedWriteReview {
            outcome = .submittedFeedback
        }
    }
}
