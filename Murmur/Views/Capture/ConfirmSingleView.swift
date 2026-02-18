import SwiftUI
import MurmurCore

struct ConfirmSingleView: View {
    @Environment(AppState.self) private var appState
    let transcript: String
    let duration: TimeInterval
    let items: [ConfirmItem]
    let inputTokens: Int
    let outputTokens: Int
    let onAccept: () -> Void
    let onDiscard: () -> Void
    let onCorrect: (ConfirmItem) -> Void

    @State private var showFullTranscript: Bool = false

    var body: some View {
        ZStack {
            Theme.Colors.bgDeep
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Review")
                            .font(.title2.weight(.bold))
                            .tracking(-0.3)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Text("Here's what I heard")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .padding(.top, 70)
                    .padding(.bottom, 16)

                    // Transcript section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "mic")
                                    .font(.caption2.weight(.semibold))
                                Text("TRANSCRIPT")
                                    .font(.caption2.weight(.semibold))
                                    .tracking(0.6)
                            }
                            .foregroundStyle(Theme.Colors.textTertiary)

                            Spacer()

                            Text(formattedDuration)
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.textMuted)
                        }

                        Text("\"\(transcript)\"")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .italic()
                            .lineSpacing(2)
                            .lineLimit(showFullTranscript ? nil : 3)
                            .onTapGesture {
                                showFullTranscript.toggle()
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.Colors.textPrimary.opacity(0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Theme.Colors.textPrimary.opacity(0.05), lineWidth: 1)
                            )
                    )
                    .padding(.bottom, 24)

                    // Items header
                    HStack {
                        Text("EXTRACTED")
                            .font(.caption.weight(.semibold))
                            .tracking(0.8)
                            .foregroundStyle(Theme.Colors.textSecondary)

                        Spacer()

                        Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .padding(.bottom, 12)

                    // Item cards
                    ForEach(Array(items.enumerated()), id: \.element.id) { _, item in
                        ConfirmSingleItemCard(
                            item: item,
                            onCorrect: { onCorrect(item) },
                            onDiscard: { /* Handle individual discard */ }
                        )
                        .padding(.bottom, 10)
                    }

                    // Session cost
                    HStack(spacing: 4) {
                        Text("↑")
                            .foregroundStyle(Theme.Colors.accentPurple.opacity(0.6))
                        Text("\(inputTokens) in")
                            .foregroundStyle(Theme.Colors.textTertiary)

                        Text("·")
                            .foregroundStyle(Color(red: 0.165, green: 0.165, blue: 0.204))
                            .padding(.horizontal, 4)

                        Text("↓")
                            .foregroundStyle(Theme.Colors.accentGreen.opacity(0.6))
                        Text("\(outputTokens) out")
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .font(Theme.Typography.label)
                    .monospacedDigit()
                    .tracking(0.3)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                    .overlay(
                        Rectangle()
                            .fill(Theme.Colors.textPrimary.opacity(0.04))
                            .frame(height: 1)
                            .frame(maxWidth: .infinity),
                        alignment: .top
                    )

                    // Bottom spacing for sticky footer
                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
            }

            // Sticky footer
            VStack {
                Spacer()

                VStack(spacing: 12) {
                    // Accept button
                    Button(action: onAccept) {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark")
                                .font(.title3.weight(.bold))

                            Text("Accept")
                                .font(.headline)
                        }
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.Colors.accentPurple, Theme.Colors.accentPurpleLight],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Theme.Colors.accentPurple.opacity(0.3), radius: 20, y: 4)
                        )
                    }
                    .buttonStyle(.plain)

                    // Discard link
                    Button(action: onDiscard) {
                        Text("Discard")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.textMuted)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .padding(.bottom, 40)
                .background(
                    LinearGradient(
                        colors: [Color.clear, Theme.Colors.bgDeep.opacity(0.9), Theme.Colors.bgDeep],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
            }
        }
    }

    private var formattedDuration: String {
        let seconds = Int(duration)
        return "\(seconds)s"
    }
}

// MARK: - Single Item Card

private struct ConfirmSingleItemCard: View {
    let item: ConfirmItem
    let onCorrect: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Item content
            VStack(alignment: .leading, spacing: 8) {
                // Category badge
                HStack(spacing: 5) {
                    Circle()
                        .fill(Theme.categoryColor(item.category))
                        .frame(width: 6, height: 6)

                    Text(item.category.displayName.uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(0.5)
                        .foregroundStyle(Theme.categoryColor(item.category))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.categoryColor(item.category).opacity(0.10))
                )

                // Summary
                Text(item.summary)
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineSpacing(2)

                // Metadata
                if let dueDate = item.dueDate {
                    HStack(spacing: 12) {
                        Text(dueDate)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.Colors.accentYellow)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Action buttons
            VStack(spacing: 6) {
                // Voice correct button
                Button(action: onCorrect) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.Colors.accentYellow.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Theme.Colors.accentYellow.opacity(0.12), lineWidth: 1)
                            )
                            .frame(width: 36, height: 36)

                        Image(systemName: "mic")
                            .font(Theme.Typography.bodyMedium)
                            .foregroundStyle(Theme.Colors.accentYellow)
                    }
                }
                .buttonStyle(.plain)

                // Discard button
                Button(action: onDiscard) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.Colors.accentRed.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Theme.Colors.accentRed.opacity(0.08), lineWidth: 1)
                            )
                            .frame(width: 36, height: 36)

                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.Colors.accentRed)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.Colors.bgCard)

                // Top gradient line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Theme.categoryColor(item.category).opacity(0.12),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        )
    }
}

#Preview("Confirm Single Item") {
    @Previewable @State var appState = AppState()

    ConfirmSingleView(
        transcript: "Remind me to call the dentist tomorrow morning",
        duration: 5,
        items: [
            ConfirmItem(
                category: .todo,
                summary: "Call the dentist",
                priority: nil,
                dueDate: "Tomorrow morning"
            )
        ],
        inputTokens: 82,
        outputTokens: 94,
        onAccept: { print("Accept all") },
        onDiscard: { print("Discard all") },
        onCorrect: { print("Correct:", $0.summary) }
    )
    .environment(appState)
}
