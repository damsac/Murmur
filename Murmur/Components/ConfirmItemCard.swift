import SwiftUI

struct ConfirmItemCard: View {
    let entry: Entry
    let onVoiceCorrect: () -> Void
    let onDiscard: () -> Void

    @State private var isAppearing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category badge
            CategoryBadge(category: entry.category, size: .medium)

            // Summary text
            Text(entry.summary)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Action buttons
            HStack(spacing: 12) {
                // Voice correct button
                Button(action: onVoiceCorrect) {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Voice Correct")
                            .font(Theme.Typography.bodyMedium)
                    }
                    .foregroundStyle(Theme.Colors.accentPurple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.Colors.accentPurple.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.Colors.accentPurple.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                // Discard button
                Button(action: onDiscard) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Discard")
                            .font(Theme.Typography.bodyMedium)
                    }
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.Colors.bgDeep.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            // Metadata footer
            HStack(spacing: 12) {
                // Token cost
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                    Text("\(entry.tokenCost) tokens")
                        .font(Theme.Typography.label)
                }
                .foregroundStyle(Theme.Colors.textTertiary)

                Spacer()

                // AI generated badge
                if entry.aiGenerated {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                        Text("AI Enhanced")
                            .font(Theme.Typography.label)
                    }
                    .foregroundStyle(Theme.Colors.accentPurple)
                }
            }
        }
        .padding(Theme.Spacing.cardPadding)
        .cardStyle()
        .scaleEffect(isAppearing ? 1 : 0.92)
        .opacity(isAppearing ? 1 : 0)
        .onAppear {
            withAnimation(Animations.cardAppear) {
                isAppearing = true
            }
        }
    }
}

#Preview("Confirm Item Cards") {
    ScrollView {
        VStack(spacing: 16) {
            ConfirmItemCard(
                entry: Entry(
                    summary: "Review the new design system and provide feedback to the team by end of week",
                    category: .todo,
                    priority: 2,
                    aiGenerated: true
                ),
                onVoiceCorrect: { print("Voice correct") },
                onDiscard: { print("Discard") }
            )

            ConfirmItemCard(
                entry: Entry(
                    summary: "The best interfaces are invisible - they get out of the way and let users focus on their work",
                    category: .insight,
                    aiGenerated: true
                ),
                onVoiceCorrect: { print("Voice correct") },
                onDiscard: { print("Discard") }
            )

            ConfirmItemCard(
                entry: Entry(
                    summary: "Build a browser extension for quick voice notes that syncs with mobile",
                    category: .idea,
                    priority: 1,
                    aiGenerated: true
                ),
                onVoiceCorrect: { print("Voice correct") },
                onDiscard: { print("Discard") }
            )
        }
        .padding(Theme.Spacing.screenPadding)
    }
    .background(Theme.Colors.bgDeep)
}

#Preview("Staggered Appear") {
    VStack(spacing: 16) {
        ConfirmItemCard(
            entry: Entry(
                summary: "First item appearing",
                category: .todo
            ),
            onVoiceCorrect: { },
            onDiscard: { }
        )

        ConfirmItemCard(
            entry: Entry(
                summary: "Second item appearing",
                category: .insight
            ),
            onVoiceCorrect: { },
            onDiscard: { }
        )
        .animation(Animations.cardAppear.delay(0.1), value: true)

        ConfirmItemCard(
            entry: Entry(
                summary: "Third item appearing",
                category: .idea
            ),
            onVoiceCorrect: { },
            onDiscard: { }
        )
        .animation(Animations.cardAppear.delay(0.2), value: true)
    }
    .padding(Theme.Spacing.screenPadding)
    .background(Theme.Colors.bgDeep)
}
