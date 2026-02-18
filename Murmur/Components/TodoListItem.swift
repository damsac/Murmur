import SwiftUI
import MurmurCore

struct TodoListItem: View {
    let entry: Entry
    @Binding var isCompleted: Bool
    let onTap: (() -> Void)?
    let onComplete: () -> Void
    let onSnooze: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isDragging = false

    private let swipeThreshold: CGFloat = 80
    private let actionWidth: CGFloat = 80

    private var timeAgo: String {
        let interval = Date().timeIntervalSince(entry.createdAt)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Swipe actions background
            HStack(spacing: 0) {
                Spacer()

                // Done action
                Button(action: handleComplete) {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.title3.weight(.semibold))
                        Text("Done")
                            .font(Theme.Typography.badge)
                    }
                    .foregroundStyle(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(Theme.Colors.accentGreen)
                }

                // Snooze action
                Button(action: handleSnooze) {
                    VStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.title3.weight(.semibold))
                        Text("Snooze")
                            .font(Theme.Typography.badge)
                    }
                    .foregroundStyle(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(Theme.Colors.accentYellow)
                }

                // Delete action
                Button(action: handleDelete) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.title3.weight(.semibold))
                        Text("Delete")
                            .font(Theme.Typography.badge)
                    }
                    .foregroundStyle(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(Theme.Colors.accentRed)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius))

            // Main content
            HStack(spacing: 16) {
                // Checkbox
                Button(action: toggleComplete) {
                    ZStack {
                        Circle()
                            .stroke(
                                isCompleted
                                    ? Theme.Colors.accentPurple
                                    : Theme.Colors.borderSubtle,
                                lineWidth: 2
                            )
                            .frame(width: 24, height: 24)

                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.Colors.accentPurple)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isCompleted ? "Mark incomplete" : "Mark complete")

                // Entry content
                VStack(alignment: .leading, spacing: 8) {
                    // Summary
                    Text(entry.summary)
                        .font(Theme.Typography.body)
                        .foregroundStyle(
                            isCompleted
                                ? Theme.Colors.textTertiary
                                : Theme.Colors.textPrimary
                        )
                        .strikethrough(isCompleted, color: Theme.Colors.textTertiary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Metadata
                    HStack(spacing: 12) {
                        CategoryBadge(category: entry.category, size: .small)

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(timeAgo)
                                .font(Theme.Typography.badge)
                        }
                        .foregroundStyle(Theme.Colors.textTertiary)

                        if entry.priority.map({ $0 <= 2 }) ?? false {
                            HStack(spacing: 3) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.caption2)
                                Text("High")
                                    .font(Theme.Typography.badge)
                            }
                            .foregroundStyle(Theme.Colors.accentRed)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Theme.Spacing.cardPadding)
            .cardStyle()
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        isDragging = true
                        // Only allow left swipe
                        if gesture.translation.width < 0 {
                            offset = gesture.translation.width
                        }
                    }
                    .onEnded { gesture in
                        isDragging = false

                        // Snap to position based on velocity and distance
                        if gesture.translation.width < -swipeThreshold || gesture.predictedEndTranslation.width < -swipeThreshold * 2 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset = -actionWidth * 3
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset = 0
                            }
                        }
                    }
            )
            .onTapGesture {
                if offset < 0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        offset = 0
                    }
                } else {
                    onTap?()
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: isCompleted)
    }

    private func toggleComplete() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isCompleted.toggle()
        }
    }

    private func handleComplete() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            offset = 0
        }
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            onComplete()
        }
    }

    private func handleSnooze() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            offset = 0
        }
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            onSnooze()
        }
    }

    private func handleDelete() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            offset = 0
        }
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            onDelete()
        }
    }
}

#Preview("Todo Items") {
    ScrollView {
        VStack(spacing: 16) {
            TodoListItem(
                entry: Entry(
                    transcript: "",
                    content: "Review design system documentation",
                    category: .todo,
                    sourceText: "",
                    summary: "Review design system documentation",
                    priority: 1
                ),
                isCompleted: .constant(false),
                onTap: { print("Tapped") },
                onComplete: { print("Complete") },
                onSnooze: { print("Snooze") },
                onDelete: { print("Delete") }
            )

            TodoListItem(
                entry: Entry(
                    transcript: "",
                    content: "Schedule team meeting for next week",
                    category: .todo,
                    sourceText: "",
                    summary: "Schedule team meeting for next week",
                    priority: 3
                ),
                isCompleted: .constant(true),
                onTap: { print("Tapped") },
                onComplete: { print("Complete") },
                onSnooze: { print("Snooze") },
                onDelete: { print("Delete") }
            )

            TodoListItem(
                entry: Entry(
                    transcript: "",
                    content: "Update project README with installation instructions and getting started guide",
                    category: .todo,
                    sourceText: "",
                    createdAt: Date().addingTimeInterval(-7200),
                    summary: "Update project README with installation instructions and getting started guide",
                    priority: 5
                ),
                isCompleted: .constant(false),
                onTap: { print("Tapped") },
                onComplete: { print("Complete") },
                onSnooze: { print("Snooze") },
                onDelete: { print("Delete") }
            )
        }
        .padding(Theme.Spacing.screenPadding)
    }
    .background(Theme.Colors.bgDeep)
}

#Preview("Swipe Hint") {
    VStack {
        Text("← Swipe left to reveal actions")
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Colors.textSecondary)
            .padding(.top, 40)

        TodoListItem(
            entry: Entry(
                transcript: "",
                content: "Try swiping this todo item to the left",
                category: .todo,
                sourceText: "",
                summary: "Try swiping this todo item to the left",
                priority: 3
            ),
            isCompleted: .constant(false),
            onTap: { print("Tapped") },
            onComplete: { print("Complete") },
            onSnooze: { print("Snooze") },
            onDelete: { print("Delete") }
        )
        .padding(Theme.Spacing.screenPadding)

        Spacer()
    }
    .background(Theme.Colors.bgDeep)
}
