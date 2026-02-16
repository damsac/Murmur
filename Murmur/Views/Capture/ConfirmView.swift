import SwiftUI

struct ConfirmView: View {
    @Environment(AppState.self) private var appState
    let entries: [Entry]
    let onAccept: () -> Void
    let onVoiceCorrect: (Entry) -> Void
    let onDiscard: (Entry) -> Void

    var body: some View {
        ZStack {
            // Background
            Theme.Colors.bgDeep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Text("Confirm entries")
                        .font(Theme.Typography.navTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text("Review and accept or make changes")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .padding(.top, 60)
                .padding(.bottom, 24)

                // Scrollable cards
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(entries) { entry in
                            ConfirmItemCard(
                                entry: entry,
                                onVoiceCorrect: { onVoiceCorrect(entry) },
                                onDiscard: { onDiscard(entry) }
                            )
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.screenPadding)
                }

                // Bottom action
                VStack(spacing: 16) {
                    // Accept all button
                    Button(action: onAccept) {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Accept \(entries.count) \(entries.count == 1 ? "entry" : "entries")")
                                .font(Theme.Typography.bodyMedium)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Theme.Colors.accentPurple,
                                            Theme.Colors.accentPurpleLight
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .shadow(
                            color: Theme.Colors.accentPurple.opacity(0.3),
                            radius: 20,
                            x: 0,
                            y: 4
                        )
                    }
                    .buttonStyle(.plain)

                    // Token cost
                    HStack(spacing: 6) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                        Text("Total cost: \(entries.reduce(0) { $0 + $1.tokenCost }) tokens")
                            .font(Theme.Typography.caption)
                    }
                    .foregroundStyle(Theme.Colors.textTertiary)
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview("Confirm - Single Entry") {
    @Previewable @State var appState = AppState()

    ConfirmView(
        entries: [
            Entry(
                summary: "Review the new design system and provide feedback to the team by end of week",
                category: .todo,
                priority: 2,
                aiGenerated: true
            )
        ],
        onAccept: { print("Accept") },
        onVoiceCorrect: { print("Voice correct:", $0.summary) },
        onDiscard: { print("Discard:", $0.summary) }
    )
    .environment(appState)
}

#Preview("Confirm - Multiple Entries") {
    @Previewable @State var appState = AppState()

    ConfirmView(
        entries: [
            Entry(
                summary: "Review the new design system and provide feedback to the team",
                category: .todo,
                priority: 2,
                aiGenerated: true
            ),
            Entry(
                summary: "The best interfaces are invisible - they get out of the way",
                category: .insight,
                aiGenerated: true
            ),
            Entry(
                summary: "Build a browser extension for quick voice notes",
                category: .idea,
                priority: 1,
                aiGenerated: true
            )
        ],
        onAccept: { print("Accept") },
        onVoiceCorrect: { print("Voice correct:", $0.summary) },
        onDiscard: { print("Discard:", $0.summary) }
    )
    .environment(appState)
}
