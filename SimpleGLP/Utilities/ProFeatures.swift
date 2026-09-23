import Foundation

/// The Pro pitch, worded for how the user takes their medication. One list so onboarding,
/// the paywall, the trial sheet and Insights never promise different things.
enum ProFeatures {
    struct Bullet: Hashable {
        let icon: String
        let title: String
        let detail: String
        /// One-line form for compact rows: "Title: detail".
        var line: String { "\(title): \(detail.prefix(1).lowercased())\(detail.dropFirst())" }
    }

    static func bullets(isPill: Bool) -> [Bullet] {
        if isPill {
            return [
                Bullet(icon: "lock.iphone", title: "Lock Screen countdown", detail: "Your wait ticks down on the Lock Screen and in the Dynamic Island"),
                Bullet(icon: "shippingbox.fill", title: "Refill reminders", detail: "A heads-up a week before your pills run out"),
                Bullet(icon: "bell.badge.fill", title: "Missed-dose nudges", detail: "A second reminder if the day slips by unlogged")
            ]
        }
        return [
            Bullet(icon: "bell.badge.fill", title: "Dose-day nudges", detail: "A second reminder before a shot slips your schedule"),
            Bullet(icon: "shippingbox.fill", title: "Refill reminders", detail: "A heads-up a week before your pens run out"),
            Bullet(icon: "waveform.path.ecg", title: "Drift alerts", detail: "Know when shots creep later week over week")
        ]
    }
}
