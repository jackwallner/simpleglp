import SwiftUI

enum AppTheme {
    // Warm, slightly sage-tinted neutral — softer than pure off-white, no white-on-gray glare.
    static let bg = Color(red: 0.953, green: 0.961, blue: 0.945)
    // Card surface: warm cream that contrasts gently with bg rather than being pure white.
    static let surface = Color(red: 0.992, green: 0.988, blue: 0.969)
    // Subtle hairline for definition without harsh shadow.
    static let surfaceStroke = Color(red: 0.847, green: 0.847, blue: 0.820)
    static let brand = Color(red: 0.184, green: 0.749, blue: 0.443)
    static let brandPressed = Color(red: 0.141, green: 0.620, blue: 0.361)
    static let brandSoft = Color(red: 0.847, green: 0.937, blue: 0.871)
    static let calm = Color(red: 0.357, green: 0.753, blue: 0.745)
    static let warm = Color(red: 0.957, green: 0.635, blue: 0.349)
    static let text = Color(red: 0.102, green: 0.102, blue: 0.102)
    static let muted = Color(red: 0.376, green: 0.392, blue: 0.353)
}
