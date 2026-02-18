import SwiftUI
import MurmurCore

struct ConfirmView: View {
    @Environment(AppState.self) private var appState
    let entries: [ExtractedEntry]
    let onAccept: () -> Void
    let onVoiceCorrect: (ExtractedEntry) -> Void
    let onDiscard: (ExtractedEntry) -> Void

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
                                .font(.headline)
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

                    // Entry count
                    Text("\(entries.count) \(entries.count == 1 ? "entry" : "entries") extracted")
                        .font(Theme.Typography.caption)
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
            ExtractedEntry(
                content: "Review the new design system and provide feedback to the team by end of week",
                category: .todo,
                sourceText: "",
                summary: "Review the new design system and provide feedback to the team by end of week",
                priority: 1
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
            ExtractedEntry(
                content: "Review the new design system and provide feedback to the team",
                category: .todo,
                sourceText: "",
                summary: "Review the new design system and provide feedback to the team",
                priority: 1
            ),
            ExtractedEntry(
                content: "The best interfaces are invisible - they get out of the way",
                category: .thought,
                sourceText: "",
                summary: "The best interfaces are invisible - they get out of the way"
            ),
            ExtractedEntry(
                content: "Build a browser extension for quick voice notes",
                category: .idea,
                sourceText: "",
                summary: "Build a browser extension for quick voice notes",
                priority: 3
            )
        ],
        onAccept: { print("Accept") },
        onVoiceCorrect: { print("Voice correct:", $0.summary) },
        onDiscard: { print("Discard:", $0.summary) }
    )
    .environment(appState)
}
