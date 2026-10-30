import Foundation

/// The Pro pitch, worded for how the user takes their medication. One list so onboarding,
/// the paywall, the trial sheet and Insights never promise different things.
enum ProFeatures {
    struct Bullet: Hashable {
        let icon: String
        let title: String
        let detail: String
        let line: String
    }

    static func bullets(isPill: Bool) -> [Bullet] {
        if isPill {
            return [
                Bullet(icon: "lock.iphone", title: String(localized: "Lock Screen countdown"), detail: String(localized: "Your wait ticks down on the Lock Screen and in the Dynamic Island."), line: String(localized: "Lock Screen countdown: Your wait ticks down on the Lock Screen and in the Dynamic Island.")),
                Bullet(icon: "shippingbox.fill", title: String(localized: "Refill reminders"), detail: String(localized: "A heads-up a week before your pills run out."), line: String(localized: "Refill reminders: A heads-up a week before your pills run out.")),
                Bullet(icon: "bell.badge.fill", title: String(localized: "Missed-dose nudges"), detail: String(localized: "A second reminder if the day slips by unlogged."), line: String(localized: "Missed-dose nudges: A second reminder if the day slips by unlogged."))
            ]
        }
        return [
            Bullet(icon: "bell.badge.fill", title: String(localized: "Dose-day nudges"), detail: String(localized: "A second reminder before a shot slips your schedule."), line: String(localized: "Dose-day nudges: A second reminder before a shot slips your schedule.")),
            Bullet(icon: "shippingbox.fill", title: String(localized: "Refill reminders"), detail: String(localized: "A heads-up a week before your pens run out."), line: String(localized: "Refill reminders: A heads-up a week before your pens run out."))
        ]
    }
}
