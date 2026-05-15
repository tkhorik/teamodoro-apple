import SwiftUI

extension Color {
    // MARK: - Phase colours
    static let workColor       = Color(hex: "#E53935")
    static let breakColor      = Color(hex: "#43A047")
    static let workColorMuted  = Color(hex: "#8B1A1A")
    static let breakColorMuted = Color(hex: "#1A5C1A")

    // MARK: - Ring anatomy
    static let tickMajor  = Color(hex: "#484848")
    static let tickMinor  = Color(hex: "#222222")
    static let dotColor   = Color.white

    // MARK: - Surface text
    static let surfaceText = Color(hex: "#555555")  // slightly lighter than spec for legibility on black

    // MARK: - Hex initialiser
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:     Double(r) / 255,
            green:   Double(g) / 255,
            blue:    Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
