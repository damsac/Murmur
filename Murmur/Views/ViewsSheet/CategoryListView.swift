import SwiftUI
import MurmurCore

struct CategoryListView: View {
    @Environment(AppState.self) private var appState
    let category: EntryCategory
    let entries: [Entry]
    let onBack: () -> Void
    let onEntryTap: (Entry) -> Void
    let onToggleComplete: (Entry) -> Void
    let onMarkDone: (Entry) -> Void
    let onSnooze: (Entry) -> Void
    let onDelete: (Entry) -> Void

    @State private var selectedFilter: TimeFilter = .all
    @State private var selectedFilterId: String? = "all"

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Theme.Colors.bgDeep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav header
                NavHeader(
                    title: category.displayName,
                    showBackButton: true,
                    backAction: onBack,
                    trailingButtons: []
                )

                // Filter chips
                FilterChips(
                    filters: TimeFilter.allCases.map { FilterChips.Filter(id: $0.rawValue, label: $0.rawValue) },
                    selectedFilter: $selectedFilterId
                )
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .padding(.top, 18)
                .padding(.bottom, 8)
                .onChange(of: selectedFilterId) { _, newValue in
                    selectedFilter = TimeFilter.allCases.first { $0.rawValue == newValue } ?? .all
                }

                // Entry list
                ScrollView {
                    VStack(spacing: 0) {
                        // Active entries
                        ForEach(activeEntries) { entry in
                            if category == .todo {
                                TodoListItem(
                                    entry: entry,
                                    isCompleted: .constant(entry.status == .completed),
                                    onTap: { onEntryTap(entry) },
                                    onComplete: { onMarkDone(entry) },
                                    onSnooze: { onSnooze(entry) },
                                    onDelete: { onDelete(entry) }
                                )
                            } else {
                                SimpleEntryRow(entry: entry)
                                    .onTapGesture {
                                        onEntryTap(entry)
                                    }
                            }
                        }

                        // Completed section
                        if !completedEntries.isEmpty {
                            Text("COMPLETED")
                                .font(Theme.Typography.badge)
                                .tracking(1)
                                .foregroundStyle(Theme.Colors.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 20)
                                .padding(.bottom, 8)
                                .padding(.horizontal, Theme.Spacing.screenPadding)

                            ForEach(completedEntries) { entry in
                                if category == .todo {
                                    TodoListItem(
                                        entry: entry,
                                        isCompleted: .constant(entry.status == .completed),
                                        onTap: { onEntryTap(entry) },
                                        onComplete: { onMarkDone(entry) },
                                        onSnooze: { onSnooze(entry) },
                                        onDelete: { onDelete(entry) }
                                    )
                                } else {
                                    SimpleEntryRow(entry: entry)
                                        .onTapGesture {
                                            onEntryTap(entry)
                                        }
                                }
                            }
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var filteredEntries: [Entry] {
        entries.filter { entry in
            switch selectedFilter {
            case .all:
                return true
            case .today:
                return Calendar.current.isDateInToday(entry.createdAt) ||
                       (entry.dueDate.map { Calendar.current.isDateInToday($0) } ?? false)
            case .thisWeek:
                let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                return entry.createdAt >= weekAgo ||
                       (entry.dueDate.map { $0 >= weekAgo } ?? false)
            }
        }
    }

    private var activeEntries: [Entry] {
        filteredEntries.filter { $0.status != .completed }
    }

    private var completedEntries: [Entry] {
        filteredEntries.filter { $0.status == .completed }
    }
}

// MARK: - Time Filter

enum TimeFilter: String, CaseIterable {
    case all = "All"
    case today = "Today"
    case thisWeek = "This Week"
}

// MARK: - Simple Entry Row

private struct SimpleEntryRow: View {
    let entry: Entry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Category dot or checkbox placeholder
            Circle()
                .fill(Theme.categoryColor(entry.category))
                .frame(width: 8, height: 8)
                .padding(.top, 8)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.summary)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundStyle(
                        entry.status == .completed ?
                        Theme.Colors.textTertiary :
                        Theme.Colors.textPrimary
                    )
                    .strikethrough(entry.status == .completed)
                    .lineLimit(2)

                Text(timeAgoText)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(
                        entry.status == .completed ?
                        Theme.Colors.accentGreen :
                        Theme.Colors.textSecondary
                    )
            }

            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, Theme.Spacing.screenPadding)
        .background(
            Rectangle()
                .fill(Theme.Colors.textPrimary.opacity(0.04))
                .frame(height: 1)
                .frame(maxHeight: .infinity, alignment: .bottom)
        )
    }

    private var timeAgoText: String {
        if entry.status == .completed {
            return "Completed \(timeAgo(from: entry.completedAt ?? entry.createdAt))"
        } else if let dueDate = entry.dueDate {
            return dueText(for: dueDate)
        } else {
            return timeAgo(from: entry.createdAt)
        }
    }

    private func timeAgo(from date: Date) -> String {
        let components = Calendar.current.dateComponents([.day, .hour], from: date, to: Date())

        if let days = components.day, days > 0 {
            return days == 1 ? "yesterday" : "\(days) days ago"
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else {
            return "just now"
        }
    }

    private func dueText(for date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Due today"
        } else if calendar.isDateInTomorrow(date) {
            return "Due tomorrow"
        } else {
            let days = calendar.dateComponents([.day], from: Date(), to: date).day ?? 0
            if days < 0 {
                return "Overdue"
            } else {
                return "Due in \(days) days"
            }
        }
    }
}

#Preview("Category List - Todo") {
    @Previewable @State var appState = AppState()

    CategoryListView(
        category: .todo,
        entries: [
            Entry(
                transcript: "",
                content: "Pick up dry cleaning",
                category: .todo,
                sourceText: "",
                summary: "Pick up dry cleaning"
            ),
            Entry(
                transcript: "",
                content: "DMV appointment",
                category: .todo,
                sourceText: "",
                summary: "DMV appointment",
                dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())
            ),
            Entry(
                transcript: "",
                content: "Fix the leaky faucet",
                category: .todo,
                sourceText: "",
                summary: "Fix the leaky faucet"
            ),
            Entry(
                transcript: "",
                content: "Buy groceries",
                category: .todo,
                sourceText: "",
                summary: "Buy groceries",
                status: .completed
            )
        ],
        onBack: { print("Back") },
        onEntryTap: { print("Entry tapped:", $0.summary) },
        onToggleComplete: { print("Toggle complete:", $0.summary) },
        onMarkDone: { print("Mark done:", $0.summary) },
        onSnooze: { print("Snooze:", $0.summary) },
        onDelete: { print("Delete:", $0.summary) }
    )
    .environment(appState)
}

#Preview("Category List - Ideas") {
    @Previewable @State var appState = AppState()

    CategoryListView(
        category: .idea,
        entries: [
            Entry(
                transcript: "",
                content: "Voice-controlled home garden watering system",
                category: .idea,
                sourceText: "",
                summary: "Voice-controlled home garden watering system"
            ),
            Entry(
                transcript: "",
                content: "App that turns grocery receipts into meal plans",
                category: .idea,
                sourceText: "",
                summary: "App that turns grocery receipts into meal plans"
            ),
            Entry(
                transcript: "",
                content: "Browser extension for quick voice notes",
                category: .idea,
                sourceText: "",
                summary: "Browser extension for quick voice notes",
                priority: 3
            )
        ],
        onBack: { print("Back") },
        onEntryTap: { print("Entry tapped:", $0.summary) },
        onToggleComplete: { print("Toggle complete:", $0.summary) },
        onMarkDone: { print("Mark done:", $0.summary) },
        onSnooze: { print("Snooze:", $0.summary) },
        onDelete: { print("Delete:", $0.summary) }
    )
    .environment(appState)
}
