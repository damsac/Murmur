import SwiftUI
import MurmurCore

// MARK: - Color Palette

enum ColorPalette: String, CaseIterable {
    case classic
    case research

    static var active: ColorPalette {
        ColorPalette(rawValue: UserDefaults.standard.string(forKey: "colorPalette") ?? "") ?? .classic
    }

    var displayName: String {
        switch self {
        case .classic:  return "Classic"
        case .research: return "Research"
        }
    }
}

enum Theme {
    // MARK: - Colors
    enum Colors {
        private static var p: ColorPalette { .active }

        // Backgrounds
        static var bgDeep: Color { p == .research ? Color(hex: "16161F") : Color(hex: "111118") }
        static var bgBody: Color { p == .research ? Color(hex: "1E1E2E") : Color(hex: "1E1E30") }
        static var bgCard: Color { p == .research ? Color(hex: "232332") : Color(hex: "222230") }

        // Text — unchanged across palettes
        static let textPrimary    = Color(hex: "F5F5F7")
        static let textSecondary  = Color(hex: "A0A0B0")
        static let textTertiary   = Color(hex: "707080")
        static let textMuted      = Color(hex: "3A3A48")

        // Accents
        static var accentPurple: Color { p == .research ? Color(hex: "8177F5") : Color(hex: "7C6FF7") }
        static var accentPurpleLight: Color { p == .research ? Color(hex: "A49CF7") : Color(hex: "9D93F9") }
        static var accentFuchsia: Color { p == .research ? Color(hex: "C026D3") : Color(hex: "E879F9") }

        static let accentGreen  = Color(hex: "34D399")
        static let accentYellow = Color(hex: "FBBF24")
        static let accentRed    = Color(hex: "EF4444")
        static let accentBlue   = Color(hex: "60A5FA")
        static let accentOrange = Color(hex: "F97316")
        static let accentTeal   = Color(hex: "2DD4BF")
        static let accentSlate  = Color(hex: "94A3B8")

        // Borders
        static let borderSubtle = Color.white.opacity(0.06)
        static let borderFaint  = Color.white.opacity(0.04)
    }

    // MARK: - Typography (Dynamic Type-aware)
    enum Typography {
        static let title = Font.title.weight(.bold)
        static let navTitle = Font.title2.weight(.semibold)
        static let body = Font.body.weight(.regular)
        static let bodyMedium = Font.body.weight(.medium)
        static let caption = Font.footnote
        static let label = Font.caption2.weight(.medium)
        static let badge = Font.caption2.weight(.semibold)
        static let navLabel = Font.caption2.weight(.medium)
    }

    // MARK: - Spacing
    enum Spacing {
        static let screenPadding: CGFloat = 24
        static let cardPadding: CGFloat = 12
        static let cardGap: CGFloat = 16
        static let cardRadius: CGFloat = 16
        static let pillRadius: CGFloat = 10
        static let micButtonSize: CGFloat = 72
        static let micButtonSizeSmall: CGFloat = 52
        static let bottomNavHeight: CGFloat = 44
        static let notchRadius: CGFloat = 39
        static let notchDepth: CGFloat = 12
        static let notchCurveOffset: CGFloat = 14
    }

    // MARK: - Gradients
    static let purpleGradient = LinearGradient(
        colors: [Colors.accentPurple, Colors.accentPurpleLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Category Colors
    static func categoryColor(_ category: EntryCategory) -> Color {
        switch category {
        case .todo:     return Colors.accentPurple
        case .reminder: return Colors.accentYellow
        case .idea:     return Colors.accentOrange
        case .habit:    return Colors.accentGreen
        case .note:     return Colors.accentSlate
        case .question: return Colors.accentFuchsia
        case .list:     return Colors.accentTeal
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}
