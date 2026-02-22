import SwiftUI
import MurmurCore

struct HomeSparseView: View {
    @Environment(AppState.self) private var appState
    @Binding var inputText: String
    let entries: [Entry]
    let onMicTap: () -> Void
    let onSubmit: () -> Void
    let onEntryTap: (Entry) -> Void
    let onAction: (Entry, EntryAction) -> Void

    @State private var appeared = false
    @State private var activeSwipeID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 2) {
                Text("Murmur")
                    .font(Theme.Typography.navTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(greeting)
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("You have \(entries.count) \(entries.count == 1 ? "entry" : "entries")")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
            .padding(.bottom, 4)

            // Entries
            ScrollView {
                VStack(spacing: Theme.Spacing.cardGap) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        SwipeableCard(
                            actions: buildSwipeActions(for: entry),
                            activeSwipeID: $activeSwipeID,
                            entryID: entry.id,
                            onTap: { onEntryTap(entry) }
                        ) {
                            EntryCard(entry: entry, showCategory: true)
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.8)
                                .delay(Double(index) * 0.1),
                            value: appeared
                        )
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            appeared = true
        }
    }

    private func buildSwipeActions(for entry: Entry) -> [CardSwipeAction] {
        var actions: [CardSwipeAction] = []
        switch entry.category {
        case .reminder:
            actions.append(CardSwipeAction(icon: "moon.zzz.fill", label: "Snooze",
                color: Theme.Colors.accentYellow) { onAction(entry, .snooze(until: nil)) })
            actions.append(CardSwipeAction(icon: "archivebox.fill", label: "Archive",
                color: Theme.Colors.accentBlue) { onAction(entry, .archive) })
            actions.append(CardSwipeAction(icon: "trash.fill", label: "Delete",
                color: Theme.Colors.accentRed) { onAction(entry, .delete) })
        case .todo:
            actions.append(CardSwipeAction(icon: "checkmark.circle.fill", label: "Done",
                color: Theme.Colors.accentGreen) { onAction(entry, .complete) })
            actions.append(CardSwipeAction(icon: "archivebox.fill", label: "Archive",
                color: Theme.Colors.accentBlue) { onAction(entry, .archive) })
            actions.append(CardSwipeAction(icon: "trash.fill", label: "Delete",
                color: Theme.Colors.accentRed) { onAction(entry, .delete) })
        default:
            actions.append(CardSwipeAction(icon: "archivebox.fill", label: "Archive",
                color: Theme.Colors.accentBlue) { onAction(entry, .archive) })
            actions.append(CardSwipeAction(icon: "trash.fill", label: "Delete",
                color: Theme.Colors.accentRed) { onAction(entry, .delete) })
        }
        return actions
    }

    private var greeting: String { Greeting.current }
}

#Preview("Home Sparse - Few Entries") {
    @Previewable @State var appState = AppState()
    @Previewable @State var inputText = ""

    HomeSparseView(
        inputText: $inputText,
        entries: [
            Entry(
                transcript: "",
                content: "Review the new design system and provide feedback to the team by end of week",
                category: .todo,
                sourceText: "",
                summary: "Review the new design system and provide feedback to the team by end of week",
                priority: 1
            ),
            Entry(
                transcript: "",
                content: "Doctor appointment tomorrow at 2pm - bring insurance card",
                category: .reminder,
                sourceText: "",
                summary: "Doctor appointment tomorrow at 2pm - bring insurance card",
                dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())
            ),
            Entry(
                transcript: "",
                content: "Build a browser extension for quick voice notes",
                category: .idea,
                sourceText: "",
                summary: "Build a browser extension for quick voice notes",
                priority: 3
            )
        ],
        onMicTap: { print("Mic tapped") },
        onSubmit: { print("Submit:", inputText) },
        onEntryTap: { print("Entry tapped:", $0.summary) },
        onAction: { entry, action in print("Action:", action, entry.summary) }
    )
    .environment(appState)
}

#Preview("Home Sparse - Single Entry") {
    @Previewable @State var appState = AppState()
    @Previewable @State var inputText = ""

    HomeSparseView(
        inputText: $inputText,
        entries: [
            Entry(
                transcript: "",
                content: "The best interfaces are invisible - they get out of the way",
                category: .thought,
                sourceText: "",
                summary: "The best interfaces are invisible - they get out of the way"
            )
        ],
        onMicTap: { print("Mic tapped") },
        onSubmit: { print("Submit:", inputText) },
        onEntryTap: { print("Entry tapped:", $0.summary) },
        onAction: { entry, action in print("Action:", action, entry.summary) }
    )
    .environment(appState)
}
