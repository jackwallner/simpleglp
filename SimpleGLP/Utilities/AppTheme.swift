import SwiftUI
#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif

enum AppTheme {
    // Neutrals adapt to light/dark so the custom palette stays in sync with system chrome
    // (nav bars, sheets) and the system-colored components used elsewhere in the app.

    // Warm, slightly sage-tinted neutral in light; near-black warm in dark.
    static let bg = adaptive(
        light: Color(red: 0.953, green: 0.961, blue: 0.945),
        dark: Color(red: 0.071, green: 0.075, blue: 0.067)
    )
    // Card surface: warm cream in light; softly elevated dark in dark.
    static let surface = adaptive(
        light: Color(red: 0.992, green: 0.988, blue: 0.969),
        dark: Color(red: 0.137, green: 0.141, blue: 0.129)
    )
    // Subtle hairline for definition without harsh shadow.
    static let surfaceStroke = adaptive(
        light: Color(red: 0.847, green: 0.847, blue: 0.820),
        dark: Color(red: 0.282, green: 0.282, blue: 0.267)
    )
    static let brand = Color(red: 0.184, green: 0.749, blue: 0.443)
    static let brandPressed = Color(red: 0.141, green: 0.620, blue: 0.361)
    static let brandSoft = adaptive(
        light: Color(red: 0.847, green: 0.937, blue: 0.871),
        dark: Color(red: 0.110, green: 0.227, blue: 0.157)
    )
    static let calm = Color(red: 0.357, green: 0.753, blue: 0.745)
    static let warm = Color(red: 0.957, green: 0.635, blue: 0.349)
    static let text = adaptive(
        light: Color(red: 0.102, green: 0.102, blue: 0.102),
        dark: Color(red: 0.949, green: 0.957, blue: 0.937)
    )
    static let muted = adaptive(
        light: Color(red: 0.376, green: 0.392, blue: 0.353),
        dark: Color(red: 0.639, green: 0.647, blue: 0.616)
    )

    private static func adaptive(light: Color, dark: Color) -> Color {
        #if canImport(UIKit) && !os(watchOS)
        return Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        // watchOS renders in a dark context only.
        return dark
        #endif
    }
}
