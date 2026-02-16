import SwiftUI

struct EntryDetailView: View {
    @Environment(AppState.self) private var appState
    let entry: Entry
    let onBack: () -> Void
    let onEdit: () -> Void
    let onTellMeMore: () -> Void
    let onViewTranscript: () -> Void
    let onArchive: () -> Void
    let onSnooze: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Theme.Colors.bgDeep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav header
                NavHeader(
                    title: "Entry",
                    showBackButton: true,
                    backAction: onBack,
                    trailingButtons: [
                        NavHeader.NavButton(
                            icon: "square.and.pencil",
                            action: onEdit
                        )
                    ]
                )

                // Detail content
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Category badge
                        CategoryBadge(category: entry.category, size: .medium)
                            .padding(.bottom, 24)

                        // Thought text
                        Text(entry.summary)
                            .font(.system(size: 20, weight: .regular))
                            .tracking(-0.01)
                            .lineSpacing(6)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .padding(.bottom, 32)

                        // Tell me more button
                        Button(action: onTellMeMore) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Tell me more")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(Theme.Colors.accentPurpleLight)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Theme.Colors.accentPurple.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Theme.Colors.accentPurple.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 28)

                        // Divider
                        Rectangle()
                            .fill(Theme.Colors.textPrimary.opacity(0.06))
                            .frame(height: 1)
                            .padding(.bottom, 20)

                        // Footer row (tags + metadata)
                        HStack(alignment: .center) {
                            // Tags
                            if !entry.tags.isEmpty {
                                HStack(spacing: 8) {
                                    ForEach(entry.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Theme.Colors.textTertiary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 5)
                                            .background(
                                                RoundedRectangle(cornerRadius: 24)
                                                    .fill(Theme.Colors.bgCard)
                                            )
                                    }
                                }
                            }

                            Spacer()

                            // Metadata
                            HStack(spacing: 6) {
                                Text(formattedDate)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textMuted)

                                Circle()
                                    .fill(Theme.Colors.textMuted)
                                    .frame(width: 3, height: 3)

                                Text(formattedDuration)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textMuted)
                            }
                        }

                        // View transcript link
                        Button(action: onViewTranscript) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 14, weight: .medium))
                                Text("View transcript")
                                    .font(Theme.Typography.caption)
                            }
                            .foregroundStyle(Theme.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 16)
                    }
                    .padding(.horizontal, Theme.Spacing.screenPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 110) // Space for action bar
                }
            }

            // Action bar at bottom
            VStack {
                Spacer()
                EntryActionBar(
                    onArchive: onArchive,
                    onSnooze: onSnooze,
                    onDelete: onDelete
                )
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: entry.createdAt)
    }

    private var formattedDuration: String {
        // Mock duration - in real app this would come from audio recording
        return "0:42"
    }
}

// MARK: - Entry Action Bar

private struct EntryActionBar: View {
    let onArchive: () -> Void
    let onSnooze: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ActionButton(
                icon: "archivebox",
                label: "Archive",
                color: Theme.Colors.textSecondary,
                action: onArchive
            )

            ActionButton(
                icon: "clock",
                label: "Snooze",
                color: Theme.Colors.accentYellow,
                action: onSnooze
            )

            ActionButton(
                icon: "trash",
                label: "Delete",
                color: Theme.Colors.accentRed,
                action: onDelete
            )
        }
        .padding(.top, 14)
        .padding(.bottom, 26)
        .background(
            Rectangle()
                .fill(Theme.Colors.bgDeep.opacity(0.95))
                .background(.ultraThinMaterial.opacity(0.5))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Theme.Colors.textPrimary.opacity(0.06))
                        .frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

private struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(color)

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(color)
            }
            .frame(minWidth: 80)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Entry Detail - Idea") {
    @Previewable @State var appState = AppState()

    EntryDetailView(
        entry: Entry(
            summary: "An app that scans your grocery receipt and suggests meals based on what you actually bought.",
            category: .idea,
            tags: ["app-idea", "food"],
            aiGenerated: true
        ),
        onBack: { print("Back") },
        onEdit: { print("Edit") },
        onTellMeMore: { print("Tell me more") },
        onViewTranscript: { print("View transcript") },
        onArchive: { print("Archive") },
        onSnooze: { print("Snooze") },
        onDelete: { print("Delete") }
    )
    .environment(appState)
}

#Preview("Entry Detail - Todo") {
    @Previewable @State var appState = AppState()

    EntryDetailView(
        entry: Entry(
            summary: "Review the new design system and provide detailed feedback to the team by end of week",
            category: .todo,
            priority: 2,
            tags: ["design", "work"],
            aiGenerated: true
        ),
        onBack: { print("Back") },
        onEdit: { print("Edit") },
        onTellMeMore: { print("Tell me more") },
        onViewTranscript: { print("View transcript") },
        onArchive: { print("Archive") },
        onSnooze: { print("Snooze") },
        onDelete: { print("Delete") }
    )
    .environment(appState)
}

#Preview("Entry Detail - Insight") {
    @Previewable @State var appState = AppState()

    EntryDetailView(
        entry: Entry(
            summary: "The best interfaces are invisible - they get out of the way and let users focus on their task without distraction.",
            category: .insight,
            tags: ["ux", "design-philosophy"],
            aiGenerated: true
        ),
        onBack: { print("Back") },
        onEdit: { print("Edit") },
        onTellMeMore: { print("Tell me more") },
        onViewTranscript: { print("View transcript") },
        onArchive: { print("Archive") },
        onSnooze: { print("Snooze") },
        onDelete: { print("Delete") }
    )
    .environment(appState)
}
