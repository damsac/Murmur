import SwiftUI

struct EntryCard: View {
    let entry: Entry
    let showCategory: Bool
    let onTap: (() -> Void)?

    init(
        entry: Entry,
        showCategory: Bool = true,
        onTap: (() -> Void)? = nil
    ) {
        self.entry = entry
        self.showCategory = showCategory
        self.onTap = onTap
    }

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
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 12) {
                // Category badge
                if showCategory {
                    CategoryBadge(category: entry.category, size: .small)
                }

                // Summary text
                Text(entry.summary)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Metadata row
                HStack(spacing: 12) {
                    // Time ago
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(timeAgo)
                            .font(Theme.Typography.label)
                    }
                    .foregroundStyle(Theme.Colors.textTertiary)

                    // Tags (if any)
                    if !entry.tags.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "tag")
                                .font(.system(size: 11))
                            Text("\(entry.tags.count)")
                                .font(Theme.Typography.label)
                        }
                        .foregroundStyle(Theme.Colors.textTertiary)
                    }

                    // Priority indicator (if high)
                    if entry.priority == 2 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 11))
                            Text("High")
                                .font(Theme.Typography.label)
                        }
                        .foregroundStyle(Theme.Colors.accentRed)
                    }

                    Spacer()

                    // AI-generated badge
                    if entry.aiGenerated {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Colors.accentPurple)
                    }
                }
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

// Variant for reminders with yellow accent
struct ReminderEntryCard: View {
    let entry: Entry
    let onTap: (() -> Void)?

    private var dueText: String? {
        guard let dueDate = entry.dueDate else { return nil }

        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(dueDate) {
            return "Due today"
        } else if calendar.isDateInTomorrow(dueDate) {
            return "Due tomorrow"
        } else {
            let components = calendar.dateComponents([.day], from: now, to: dueDate)
            if let days = components.day {
                if days < 0 {
                    return "Overdue"
                } else {
                    return "Due in \(days)d"
                }
            }
        }

        return nil
    }

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 12) {
                // Category badge
                CategoryBadge(category: entry.category, size: .small)

                // Summary text
                Text(entry.summary)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Due date
                if let dueText {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                        Text(dueText)
                            .font(Theme.Typography.label)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(Theme.Colors.accentYellow)
                }
            }
            .reminderCardStyle()
        }
        .buttonStyle(.plain)
    }
}

#Preview("Entry Cards") {
    ScrollView {
        VStack(spacing: 16) {
            EntryCard(
                entry: Entry(
                    summary: "Review the new design system and provide feedback to the team",
                    category: .todo,
                    priority: 2,
                    tags: ["design", "urgent"],
                    aiGenerated: true
                ),
                onTap: { print("Tapped") }
            )

            EntryCard(
                entry: Entry(
                    summary: "The best interfaces are invisible - they get out of the way and let users focus on their work",
                    category: .insight,
                    createdAt: Date().addingTimeInterval(-3600),
                    aiGenerated: false
                ),
                onTap: { print("Tapped") }
            )

            EntryCard(
                entry: Entry(
                    summary: "Build a browser extension for quick voice notes",
                    category: .idea,
                    createdAt: Date().addingTimeInterval(-7200),
                    tags: ["extension"],
                    aiGenerated: true
                ),
                onTap: { print("Tapped") }
            )

            ReminderEntryCard(
                entry: Entry(
                    summary: "Submit quarterly report to management",
                    category: .reminder,
                    createdAt: Date().addingTimeInterval(-1800),
                    dueDate: Date().addingTimeInterval(86400),
                    priority: 2,
                    aiGenerated: true
                ),
                onTap: { print("Tapped") }
            )
        }
        .padding(Theme.Spacing.screenPadding)
    }
    .background(Theme.Colors.bgDeep)
}
