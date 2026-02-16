import SwiftUI

// MARK: - Card Style
struct CardStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.cardPadding)
            .background(
                ZStack(alignment: .top) {
                    // Card background
                    Theme.Colors.bgCard

                    // Top gradient line
                    LinearGradient(
                        colors: [
                            Theme.Colors.accentPurple.opacity(0.3),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 1)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius))
    }
}

// MARK: - Reminder Card Style
struct ReminderCardStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.cardPadding)
            .background(Theme.Colors.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius)
                    .stroke(Theme.Colors.accentYellow, lineWidth: 2)
                    .padding(.leading, -2) // Offset to create left border effect
                    .mask(
                        Rectangle()
                            .frame(width: 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    )
            )
    }
}

// MARK: - View Extensions
extension View {
    func cardStyle() -> some View {
        modifier(CardStyleModifier())
    }

    func reminderCardStyle() -> some View {
        modifier(ReminderCardStyleModifier())
    }
}
