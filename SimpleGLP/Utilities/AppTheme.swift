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
    // Accent colors. `brand`, `warm` and `calm` are for text, icons and strokes: deep in
    // light mode (4.5:1 on bg, surface and brandSoft), the bright originals in dark mode.
    // Increased Contrast darkens (light) or brightens (dark) them further.
    static let brand = adaptive(
        light: Color(red: 0.080, green: 0.450, blue: 0.240),
        dark: Color(red: 0.184, green: 0.749, blue: 0.443),
        lightHighContrast: Color(red: 0.0, green: 0.340, blue: 0.170),
        darkHighContrast: Color(red: 0.400, green: 0.870, blue: 0.580)
    )
    // Solid fill under white text (buttons, badges, big log button): 5.9:1 in every mode.
    static let brandFill = adaptive(
        light: Color(red: 0.080, green: 0.450, blue: 0.240),
        dark: Color(red: 0.080, green: 0.450, blue: 0.240),
        lightHighContrast: Color(red: 0.0, green: 0.340, blue: 0.170),
        darkHighContrast: Color(red: 0.0, green: 0.340, blue: 0.170)
    )
    static let brandPressed = Color(red: 0.050, green: 0.360, blue: 0.190)
    static let brandSoft = adaptive(
        light: Color(red: 0.847, green: 0.937, blue: 0.871),
        dark: Color(red: 0.110, green: 0.227, blue: 0.157)
    )
    static let calm = adaptive(
        light: Color(red: 0.0, green: 0.400, blue: 0.400),
        dark: Color(red: 0.357, green: 0.753, blue: 0.745),
        lightHighContrast: Color(red: 0.0, green: 0.340, blue: 0.340),
        darkHighContrast: Color(red: 0.500, green: 0.860, blue: 0.850)
    )
    // Deep teal that keeps white text at 4.5:1 or better in every mode.
    static let calmFill = Color(red: 0.0, green: 0.400, blue: 0.400)
    static let warm = adaptive(
        light: Color(red: 0.580, green: 0.300, blue: 0.0),
        dark: Color(red: 0.957, green: 0.635, blue: 0.349),
        lightHighContrast: Color(red: 0.450, green: 0.220, blue: 0.0),
        darkHighContrast: Color(red: 1.0, green: 0.740, blue: 0.480)
    )
    static let text = adaptive(
        light: Color(red: 0.102, green: 0.102, blue: 0.102),
        dark: Color(red: 0.949, green: 0.957, blue: 0.937)
    )
    static let muted = adaptive(
        light: Color(red: 0.376, green: 0.392, blue: 0.353),
        dark: Color(red: 0.639, green: 0.647, blue: 0.616),
        lightHighContrast: Color(red: 0.250, green: 0.260, blue: 0.240),
        darkHighContrast: Color(red: 0.800, green: 0.810, blue: 0.780)
    )

    private static func adaptive(
        light: Color,
        dark: Color,
        lightHighContrast: Color? = nil,
        darkHighContrast: Color? = nil
    ) -> Color {
        #if canImport(UIKit) && !os(watchOS)
        return Color(UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let isHigh = traits.accessibilityContrast == .high
            switch (isDark, isHigh) {
            case (true, true): return UIColor(darkHighContrast ?? dark)
            case (true, false): return UIColor(dark)
            case (false, true): return UIColor(lightHighContrast ?? light)
            case (false, false): return UIColor(light)
            }
        })
        #else
        // watchOS renders in a dark context only.
        return dark
        #endif
    }
}
