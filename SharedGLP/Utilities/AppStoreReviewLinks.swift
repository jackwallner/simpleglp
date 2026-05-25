import Foundation

/// App Store review deep links for Simple GLP.
enum AppStoreReviewLinks {
    /// Public App Store track ID (ASC app id). Update if Apple assigns a different id at launch.
    static let appStoreID = "6770137909"

    /// Opens the App Store write-review page (use for explicit user-initiated rating CTAs).
    static var writeReviewURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!
    }
}
