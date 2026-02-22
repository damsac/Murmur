import SwiftUI

// MARK: - Card Style

struct CardStyleModifier: ViewModifier {
    var accent: Color?
    var intensity: Double

    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.cardPadding)
            .background(Theme.Colors.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius)
                    .stroke(
                        accent?.opacity(0.30 * intensity) ?? Theme.Colors.borderSubtle,
                        lineWidth: accent != nil ? 1.5 : 1
                    )
            )
            .shadow(
                color: accent?.opacity(0.12 * intensity) ?? .clear,
                radius: 10,
                y: 3
            )
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle(accent: Color? = nil, intensity: Double = 1.0) -> some View {
        modifier(CardStyleModifier(accent: accent, intensity: intensity))
    }
}
