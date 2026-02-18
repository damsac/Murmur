import SwiftUI
import MurmurCore

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
                            .font(.caption2)
                        Text(timeAgo)
                            .font(Theme.Typography.label)
                    }
                    .foregroundStyle(Theme.Colors.textTertiary)

                    // Priority indicator (if high)
                    if entry.priority.map({ $0 <= 2 }) ?? false {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption2)
                            Text("High")
                                .font(Theme.Typography.label)
                        }
                        .foregroundStyle(Theme.Colors.accentRed)
                    }

                    Spacer()
                }
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Entry: \(entry.summary)")
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
                            .font(.caption2)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reminder: \(entry.summary)")
    }
}

#Preview("Entry Cards") {
    ScrollView {
        VStack(spacing: 16) {
            EntryCard(
                entry: Entry(
                    transcript: "",
                    content: "Review the new design system and provide feedback to the team",
                    category: .todo,
                    sourceText: "",
                    summary: "Review the new design system and provide feedback to the team",
                    priority: 1
                ),
                onTap: { print("Tapped") }
            )

            EntryCard(
                entry: Entry(
                    transcript: "",
                    content: "The best interfaces are invisible - they get out of the way and let users focus on their work",
                    category: .thought,
                    sourceText: "",
                    createdAt: Date().addingTimeInterval(-3600),
                    summary: "The best interfaces are invisible - they get out of the way and let users focus on their work"
                ),
                onTap: { print("Tapped") }
            )

            EntryCard(
                entry: Entry(
                    transcript: "",
                    content: "Build a browser extension for quick voice notes",
                    category: .idea,
                    sourceText: "",
                    createdAt: Date().addingTimeInterval(-7200),
                    summary: "Build a browser extension for quick voice notes"
                ),
                onTap: { print("Tapped") }
            )

            ReminderEntryCard(
                entry: Entry(
                    transcript: "",
                    content: "Submit quarterly report to management",
                    category: .reminder,
                    sourceText: "",
                    createdAt: Date().addingTimeInterval(-1800),
                    summary: "Submit quarterly report to management",
                    priority: 1,
                    dueDate: Date().addingTimeInterval(86400)
                ),
                onTap: { print("Tapped") }
            )
        }
        .padding(Theme.Spacing.screenPadding)
    }
    .background(Theme.Colors.bgDeep)
}
