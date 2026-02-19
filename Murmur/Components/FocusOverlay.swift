import SwiftUI
import MurmurCore

struct FocusOverlay: View {
    let entry: Entry
    let onMarkDone: (() -> Void)?
    let onSnooze: (() -> Void)?
    let onDismiss: () -> Void

    @State private var isAppearing = false
    @State private var cardScale: CGFloat = 0.9

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 0) {
                // Top spacer
                Spacer()

                // Focus card content
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        // Focus indicator
                        HStack(spacing: 8) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Theme.Colors.accentPurple,
                                            Theme.Colors.accentPurpleLight
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 8, height: 8)
                                .shadow(
                                    color: Theme.Colors.accentPurple.opacity(0.6),
                                    radius: 6,
                                    x: 0,
                                    y: 0
                                )

                            Text("Focus on this")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .textCase(.uppercase)
                                .tracking(1.2)
                        }

                        // Title based on category
                        Text(focusTitle)
                            .font(Theme.Typography.navTitle)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }

                    // Entry card
                    EntryCard(
                        entry: entry,
                        showCategory: true,
                        onTap: nil
                    )
                    .scaleEffect(cardScale)
                    .shadow(
                        color: Theme.Colors.accentPurple.opacity(0.2),
                        radius: 24,
                        x: 0,
                        y: 12
                    )

                    // Action buttons
                    VStack(spacing: 12) {
                        // Primary action (context-specific)
                        if let onMarkDone, entry.category == .todo || entry.category == .reminder {
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    cardScale = 0.95
                                }
                                Task {
                                    try? await Task.sleep(for: .seconds(0.2))
                                    onMarkDone()
                                }
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.headline)
                                    Text("Mark as Done")
                                        .font(Theme.Typography.bodyMedium)
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule()
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
                                    color: Theme.Colors.accentPurple.opacity(0.4),
                                    radius: 16,
                                    x: 0,
                                    y: 8
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        // Secondary actions row
                        HStack(spacing: 12) {
                            // Snooze button (for todos/reminders)
                            if let onSnooze, entry.category == .todo || entry.category == .reminder {
                                Button(action: {
                                    onSnooze()
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "clock")
                                            .font(.body.weight(.semibold))
                                        Text("Snooze")
                                            .font(Theme.Typography.bodyMedium)
                                    }
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        Capsule()
                                            .fill(Theme.Colors.bgCard)
                                            .overlay(
                                                Capsule()
                                                    .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                            // Dismiss button
                            Button(action: onDismiss) {
                                HStack(spacing: 8) {
                                    Image(systemName: "xmark")
                                        .font(.body.weight(.semibold))
                                    Text("Dismiss")
                                        .font(Theme.Typography.bodyMedium)
                                }
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule()
                                        .fill(Theme.Colors.bgCard)
                                        .overlay(
                                            Capsule()
                                                .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .opacity(isAppearing ? 1 : 0)
                .offset(y: isAppearing ? 0 : 20)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                isAppearing = true
            }
            withAnimation(
                .spring(response: 0.6, dampingFraction: 0.65)
                .delay(0.1)
            ) {
                cardScale = 1.0
            }
        }
    }

    private var focusTitle: String {
        switch entry.category {
        case .todo:
            return "Complete this task"
        case .reminder:
            return "Don't forget"
        case .thought:
            return "Reflect on this"
        case .idea:
            return "Explore this idea"
        case .question:
            return "Consider this"
        case .list:
            return "Review this list"
        case .note:
            return "Remember this"
        case .habit:
            return "Build this habit"
        }
    }
}

#Preview("Focus - Todo") {
    FocusOverlay(
        entry: Entry(
            transcript: "",
            content: "Review the new design system and provide feedback to the team by end of week",
            category: .todo,
            sourceText: "",
            summary: "Review the new design system and provide feedback to the team by end of week",
            priority: 1
        ),
        onMarkDone: { print("Mark done") },
        onSnooze: { print("Snooze") },
        onDismiss: { print("Dismiss") }
    )
}

#Preview("Focus - Insight") {
    FocusOverlay(
        entry: Entry(
            transcript: "",
            content: "The best interfaces are invisible - they get out of the way and let users focus on their work",
            category: .thought,
            sourceText: "",
            createdAt: Date().addingTimeInterval(-3600),
            summary: "The best interfaces are invisible - they get out of the way and let users focus on their work"
        ),
        onMarkDone: nil,
        onSnooze: nil,
        onDismiss: { print("Dismiss") }
    )
}

#Preview("Focus - Reminder") {
    FocusOverlay(
        entry: Entry(
            transcript: "",
            content: "Submit quarterly report to management",
            category: .reminder,
            sourceText: "",
            summary: "Submit quarterly report to management",
            priority: 1,
            dueDate: Date().addingTimeInterval(86400)
        ),
        onMarkDone: { print("Mark done") },
        onSnooze: { print("Snooze") },
        onDismiss: { print("Dismiss") }
    )
}

#Preview("Focus - Idea") {
    FocusOverlay(
        entry: Entry(
            transcript: "",
            content: "Build a browser extension for quick voice notes that syncs with mobile app seamlessly",
            category: .idea,
            sourceText: "",
            createdAt: Date().addingTimeInterval(-7200),
            summary: "Build a browser extension for quick voice notes that syncs with mobile app seamlessly",
            priority: 3
        ),
        onMarkDone: nil,
        onSnooze: nil,
        onDismiss: { print("Dismiss") }
    )
}

#Preview("Focus - Question") {
    FocusOverlay(
        entry: Entry(
            transcript: "",
            content: "What's the best way to implement real-time collaboration in SwiftUI?",
            category: .question,
            sourceText: "",
            summary: "What's the best way to implement real-time collaboration in SwiftUI?"
        ),
        onMarkDone: nil,
        onSnooze: nil,
        onDismiss: { print("Dismiss") }
    )
}
