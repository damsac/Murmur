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

    // MARK: - Attention State

    private var isIdea: Bool {
        entry.category == .idea
    }

    private var isCompleted: Bool {
        entry.status == .completed
    }

    private var isOverdue: Bool {
        guard let dueDate = entry.dueDate else { return false }
        return dueDate < Date() && !isCompleted
    }

    private var hasActiveDue: Bool {
        guard let dueDate = entry.dueDate else { return false }
        return dueDate >= Date() && !isCompleted
    }

    private var cardOpacity: Double {
        if isCompleted { return 0.55 }
        if isIdea { return 0.88 }
        return 1.0
    }

    // MARK: - Formatted strings

    private var timeAgo: String {
        let interval = Date().timeIntervalSince(entry.createdAt)
        switch interval {
        case ..<60: return "Just now"
        case ..<3600: return "\(Int(interval / 60))m ago"
        case ..<86400: return "\(Int(interval / 3600))h ago"
        default: return "\(Int(interval / 86400))d ago"
        }
    }

    private var dueText: String? {
        guard let dueDate = entry.dueDate else { return nil }
        let calendar = Calendar.current
        if isOverdue { return "Overdue" }
        if calendar.isDateInToday(dueDate) { return "Due today" }
        if calendar.isDateInTomorrow(dueDate) { return "Due tomorrow" }
        let days = calendar.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
        return "Due in \(days)d"
    }

    // MARK: - Body

    var body: some View {
        cardContent
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Entry: \(entry.summary)")
    }

    @ViewBuilder
    private var cardContent: some View {
        if let onTap {
            Button(action: onTap) { cardBody }
                .buttonStyle(.plain)
        } else {
            cardBody
        }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category badge (suppress dot glow for timeless entries)
            if showCategory {
                CategoryBadge(category: entry.category, size: .small, showDotGlow: !isIdea)
            }

            // Summary text
            Text(entry.summary)
                .font(Theme.Typography.body)
                .foregroundStyle(isCompleted ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                .strikethrough(isCompleted, color: Theme.Colors.textTertiary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Metadata row — suppressed for timeless entries (ideas, thoughts)
            if !isIdea && !isCompleted {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(timeAgo)
                            .font(Theme.Typography.label)
                    }
                    .foregroundStyle(Theme.Colors.textTertiary)

                    if let dueText {
                        HStack(spacing: 4) {
                            Image(systemName: isOverdue ? "exclamationmark.circle.fill" : "calendar")
                                .font(.caption2)
                            Text(dueText)
                                .font(Theme.Typography.label)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(isOverdue ? Theme.Colors.accentRed : Theme.Colors.accentYellow)
                    } else if entry.priority.map({ $0 <= 2 }) ?? false {
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
        }
        .cardStyle()
        .opacity(cardOpacity)
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
                    category: .note,
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

            EntryCard(
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

            EntryCard(
                entry: Entry(
                    transcript: "",
                    content: "Call dentist about appointment",
                    category: .reminder,
                    sourceText: "",
                    summary: "Call dentist about appointment",
                    dueDate: Date().addingTimeInterval(-3600),
                    status: .active
                ),
                onTap: { print("Tapped") }
            )

            EntryCard(
                entry: Entry(
                    transcript: "",
                    content: "Pick up dry cleaning",
                    category: .todo,
                    sourceText: "",
                    summary: "Pick up dry cleaning",
                    status: .completed
                ),
                onTap: { print("Tapped") }
            )
        }
        .padding(Theme.Spacing.screenPadding)
    }
    .background(Theme.Colors.bgDeep)
}
