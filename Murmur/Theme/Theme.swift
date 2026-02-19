import SwiftUI
import MurmurCore

enum Theme {
    // MARK: - Colors
    enum Colors {
        // Backgrounds
        static let bgDeep = Color(hex: "0A0A0F")
        static let bgBody = Color(hex: "1A1A2E")
        static let bgCard = Color(hex: "1A1A24")

        // Text
        static let textPrimary = Color(hex: "F5F5F7")
        static let textSecondary = Color(hex: "8E8E9A")
        static let textTertiary = Color(hex: "5C5C6A")
        static let textMuted = Color(hex: "3A3A48")

        // Accents
        static let accentPurple = Color(hex: "7C6FF7")
        static let accentPurpleLight = Color(hex: "9D93F9")
        static let accentGreen = Color(hex: "34D399")
        static let accentYellow = Color(hex: "FBBF24")
        static let accentRed = Color(hex: "EF4444")
        static let accentBlue = Color(hex: "60A5FA")

        // Borders
        static let borderSubtle = Color.white.opacity(0.06)
        static let borderFaint = Color.white.opacity(0.04)
    }

    // MARK: - Typography (Dynamic Type-aware)
    enum Typography {
        static let title = Font.title.weight(.bold)
        static let navTitle = Font.title2.weight(.semibold)
        static let body = Font.body
        static let bodyMedium = Font.body.weight(.medium)
        static let caption = Font.caption
        static let label = Font.caption2.weight(.medium)
        static let badge = Font.caption2.weight(.semibold)
        static let navLabel = Font.caption2.weight(.medium)
    }

    // MARK: - Spacing
    enum Spacing {
        static let screenPadding: CGFloat = 24
        static let cardPadding: CGFloat = 18
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
        case .todo:
            return Colors.accentPurple
        case .thought:
            return Colors.accentBlue
        case .idea:
            return Colors.accentYellow
        case .reminder:
            return Colors.accentYellow
        case .note:
            return Colors.textSecondary
        case .question:
            return Colors.accentPurpleLight
        case .list:
            return Colors.accentGreen
        case .habit:
            return Colors.accentBlue
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
