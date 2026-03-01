import SwiftUI

/// Unified overlay card that persists from recording through response.
/// Shows live transcript during recording, frozen transcript during processing,
/// then streams the agent response. Tap to dismiss after response arrives.
struct AgentStreamOverlay: View {
    /// Live or saved transcript text (user's words)
    let transcript: String
    /// Agent response to stream (nil = still waiting)
    let responseText: String?
    /// Whether currently recording (for placeholder when empty)
    let isRecording: Bool
    let onDismiss: () -> Void

    private var displayText: String {
        responseText ?? transcript
    }

    private var showingTranscript: Bool {
        responseText == nil
    }

    var body: some View {
        VStack {
            Spacer()
            cardContent
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.Colors.bgDeep.opacity(0.85))
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                )
                .onTapGesture {
                    if responseText != nil {
                        withAnimation(Animations.overlayDismiss) {
                            onDismiss()
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .padding(.bottom, Theme.Spacing.micButtonSize + 24)
        }
        .allowsHitTesting(responseText != nil)
        .transition(.opacity)
    }

    @ViewBuilder
    private var cardContent: some View {
        if displayText.isEmpty && isRecording {
            Text("Listening...")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if showingTranscript {
            Text(displayText)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(markdownAttributed(displayText))
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func markdownAttributed(_ string: String) -> AttributedString {
        (try? AttributedString(markdown: string, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(string)
    }
}

#Preview("Recording") {
    ZStack {
        Theme.Colors.bgDeep.ignoresSafeArea()
        AgentStreamOverlay(
            transcript: "I need to pick up groceries and...",
            responseText: nil, isRecording: true, onDismiss: {}
        )
    }
}

#Preview("Response") {
    ZStack {
        Theme.Colors.bgDeep.ignoresSafeArea()
        AgentStreamOverlay(
            transcript: "",
            responseText: "Created 2 entries: Groceries and Dentist appointment.",
            isRecording: false, onDismiss: { print("Dismissed") }
        )
    }
}
