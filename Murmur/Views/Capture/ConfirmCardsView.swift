import SwiftUI

struct ConfirmCardsView: View {
    @Environment(AppState.self) private var appState
    let transcript: String
    let duration: TimeInterval
    let items: [ConfirmItem]
    let onAccept: (ConfirmItem) -> Void
    let onDiscard: (ConfirmItem) -> Void
    let onCorrect: (ConfirmItem) -> Void
    let onComplete: () -> Void

    @State private var currentIndex: Int = 0
    @State private var showTranscript: Bool = false

    var body: some View {
        ZStack {
            Theme.Colors.bgDeep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top section: progress + transcript
                VStack(spacing: 0) {
                    // Progress row
                    HStack {
                        Text("Item ")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                        + Text("\(currentIndex + 1)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        + Text(" of \(items.count)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)

                        Spacer()

                        // Progress dots
                        HStack(spacing: 6) {
                            ForEach(0..<items.count, id: \.self) { index in
                                Circle()
                                    .fill(index == currentIndex ? Theme.Colors.accentPurple : Color(red: 0.165, green: 0.165, blue: 0.212))
                                    .frame(width: 8, height: 8)
                                    .shadow(
                                        color: index == currentIndex ? Theme.Colors.accentPurple.opacity(0.4) : .clear,
                                        radius: 4
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.screenPadding)
                    .padding(.top, 70)
                    .padding(.bottom, 16)

                    // Transcript peek
                    Button(action: { showTranscript.toggle() }) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "mic")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("ORIGINAL TRANSCRIPT")
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(0.6)
                            }
                            .foregroundStyle(Theme.Colors.textTertiary)

                            Text("\"\(transcript)\"")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .lineLimit(showTranscript ? nil : 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Theme.Colors.textPrimary.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.Colors.textPrimary.opacity(0.05), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Theme.Spacing.screenPadding)
                    .padding(.bottom, 24)
                }

                Spacer()

                // Center: current card with stack effect
                ZStack {
                    // Background stacked cards for depth
                    if currentIndex + 2 < items.count {
                        ConfirmCardContent(item: items[currentIndex + 2])
                            .offset(y: 14)
                            .scaleEffect(0.88)
                            .opacity(0.3)
                    }

                    if currentIndex + 1 < items.count {
                        ConfirmCardContent(item: items[currentIndex + 1])
                            .offset(y: 8)
                            .scaleEffect(0.94)
                            .opacity(0.6)
                    }

                    // Current card
                    ConfirmCardContent(item: items[currentIndex])
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .id(currentIndex)
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)

                Spacer()

                // Bottom: action buttons
                VStack(spacing: 10) {
                    HStack(spacing: 20) {
                        // Discard button
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                handleDiscard()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Theme.Colors.accentRed.opacity(0.08))
                                    .frame(width: 52, height: 52)

                                Circle()
                                    .stroke(Theme.Colors.accentRed.opacity(0.15), lineWidth: 1.5)
                                    .frame(width: 52, height: 52)

                                Image(systemName: "xmark")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(Theme.Colors.accentRed)
                            }
                        }
                        .buttonStyle(.plain)

                        // Accept button (larger, primary)
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                handleAccept()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Theme.Colors.accentPurple, Theme.Colors.accentPurpleLight],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 68, height: 68)
                                    .shadow(color: Theme.Colors.accentPurple.opacity(0.35), radius: 20, y: 4)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            }
                        }
                        .buttonStyle(.plain)

                        // Correct button
                        Button(action: {
                            onCorrect(items[currentIndex])
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Theme.Colors.accentYellow.opacity(0.08))
                                    .frame(width: 52, height: 52)

                                Circle()
                                    .stroke(Theme.Colors.accentYellow.opacity(0.15), lineWidth: 1.5)
                                    .frame(width: 52, height: 52)

                                Image(systemName: "mic")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(Theme.Colors.accentYellow)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    // Labels
                    HStack(spacing: 20) {
                        Text("Discard")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .frame(width: 52)

                        Text("Accept")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(width: 68)

                        Text("Correct")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .frame(width: 52)
                    }
                    .padding(.top, 10)
                }
                .padding(.bottom, 40)
            }
        }
    }

    private func handleAccept() {
        onAccept(items[currentIndex])
        moveToNext()
    }

    private func handleDiscard() {
        onDiscard(items[currentIndex])
        moveToNext()
    }

    private func moveToNext() {
        if currentIndex < items.count - 1 {
            currentIndex += 1
        } else {
            onComplete()
        }
    }
}

// MARK: - Card Content

private struct ConfirmCardContent: View {
    let item: ConfirmItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category badge
            HStack(spacing: 6) {
                Circle()
                    .fill(Theme.categoryColor(item.category))
                    .frame(width: 7, height: 7)

                Text(item.category.displayName.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.categoryColor(item.category))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.categoryColor(item.category).opacity(0.12))
            )
            .padding(.bottom, 16)

            // Summary
            Text(item.summary)
                .font(.system(size: 22, weight: .semibold))
                .tracking(-0.3)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineSpacing(4)
                .padding(.bottom, 12)

            // Extracted metadata
            if let priority = item.priority {
                MetadataRow(label: "Priority", value: priority, isAccent: false)
            }

            if let dueDate = item.dueDate {
                MetadataRow(label: "Due", value: dueDate, isAccent: true)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.Colors.bgCard)

                RoundedRectangle(cornerRadius: 20)
                    .stroke(Theme.categoryColor(item.category).opacity(0.08), lineWidth: 1)

                // Top gradient line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Theme.categoryColor(item.category).opacity(0.2),
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

private struct MetadataRow: View {
    let label: String
    let value: String
    let isAccent: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.textTertiary)
                .frame(width: 60, alignment: .leading)

            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isAccent ? Theme.Colors.accentYellow : Theme.Colors.textPrimary)
        }
        .padding(.top, 8)
    }
}

// MARK: - Model

struct ConfirmItem: Identifiable {
    let id = UUID()
    let category: EntryCategory
    let summary: String
    let priority: String?
    let dueDate: String?
}

#Preview("Confirm Cards") {
    @Previewable @State var appState = AppState()

    ConfirmCardsView(
        transcript: "I need to pick up dry cleaning before six, oh and remind me about the DMV on Thursday, also I had this idea about an app that turns receipts into meal plans",
        duration: 12,
        items: [
            ConfirmItem(category: .todo, summary: "Pick up dry cleaning before 6pm", priority: "High", dueDate: "Today, 6:00 PM"),
            ConfirmItem(category: .reminder, summary: "DMV appointment Thursday", priority: nil, dueDate: "In 2 days"),
            ConfirmItem(category: .idea, summary: "App that turns grocery receipts into meal plans", priority: nil, dueDate: nil)
        ],
        onAccept: { print("Accept:", $0.summary) },
        onDiscard: { print("Discard:", $0.summary) },
        onCorrect: { print("Correct:", $0.summary) },
        onComplete: { print("Complete") }
    )
    .environment(appState)
}
