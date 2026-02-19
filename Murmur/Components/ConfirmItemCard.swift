import SwiftUI
import MurmurCore

struct ConfirmItemCard: View {
    let entry: ExtractedEntry
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
                            .font(.subheadline.weight(.semibold))
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
                            .font(.subheadline.weight(.semibold))
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
                CategoryBadge(category: entry.category, size: .small)

                Spacer()
            }
        }
        .padding(Theme.Spacing.cardPadding)
        .cardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(entry.category.displayName) entry: \(entry.summary)")
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
                entry: ExtractedEntry(
                    content: "Review the new design system and provide feedback to the team by end of week",
                    category: .todo,
                    sourceText: "",
                    summary: "Review the new design system and provide feedback to the team by end of week",
                    priority: 1
                ),
                onVoiceCorrect: { print("Voice correct") },
                onDiscard: { print("Discard") }
            )

            ConfirmItemCard(
                entry: ExtractedEntry(
                    content: "The best interfaces are invisible - they get out of the way and let users focus on their work",
                    category: .thought,
                    sourceText: "",
                    summary: "The best interfaces are invisible - they get out of the way and let users focus on their work"
                ),
                onVoiceCorrect: { print("Voice correct") },
                onDiscard: { print("Discard") }
            )

            ConfirmItemCard(
                entry: ExtractedEntry(
                    content: "Build a browser extension for quick voice notes that syncs with mobile",
                    category: .idea,
                    sourceText: "",
                    summary: "Build a browser extension for quick voice notes that syncs with mobile",
                    priority: 3
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
            entry: ExtractedEntry(
                content: "First item appearing",
                category: .todo,
                sourceText: "",
                summary: "First item appearing"
            ),
            onVoiceCorrect: { },
            onDiscard: { }
        )

        ConfirmItemCard(
            entry: ExtractedEntry(
                content: "Second item appearing",
                category: .thought,
                sourceText: "",
                summary: "Second item appearing"
            ),
            onVoiceCorrect: { },
            onDiscard: { }
        )
        .animation(Animations.cardAppear.delay(0.1), value: true)

        ConfirmItemCard(
            entry: ExtractedEntry(
                content: "Third item appearing",
                category: .idea,
                sourceText: "",
                summary: "Third item appearing"
            ),
            onVoiceCorrect: { },
            onDiscard: { }
        )
        .animation(Animations.cardAppear.delay(0.2), value: true)
    }
    .padding(Theme.Spacing.screenPadding)
    .background(Theme.Colors.bgDeep)
}
