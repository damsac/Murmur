import SwiftUI

struct FocusCardView: View {
    @Environment(AppState.self) private var appState
    let entry: Entry
    let onMarkDone: (() -> Void)?
    let onSnooze: (() -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        FocusOverlay(
            entry: entry,
            onMarkDone: onMarkDone,
            onSnooze: onSnooze,
            onDismiss: onDismiss
        )
    }
}

#Preview("Focus - Todo") {
    @Previewable @State var appState = AppState()

    FocusCardView(
        entry: Entry(
            summary: "Review the new design system and provide feedback to the team by end of week",
            category: .todo,
            priority: 2,
            aiGenerated: true
        ),
        onMarkDone: { print("Mark done") },
        onSnooze: { print("Snooze") },
        onDismiss: { print("Dismiss") }
    )
    .environment(appState)
}

#Preview("Focus - Insight") {
    @Previewable @State var appState = AppState()

    FocusCardView(
        entry: Entry(
            summary: "The best interfaces are invisible - they get out of the way and let users focus on their task",
            category: .insight,
            aiGenerated: true
        ),
        onMarkDone: nil,
        onSnooze: nil,
        onDismiss: { print("Dismiss") }
    )
    .environment(appState)
}

#Preview("Focus - Reminder") {
    @Previewable @State var appState = AppState()

    FocusCardView(
        entry: Entry(
            summary: "Team standup at 10am - prepare update on the authentication refactor",
            category: .reminder,
            dueDate: Calendar.current.date(byAdding: .hour, value: 2, to: Date()),
            aiGenerated: true
        ),
        onMarkDone: { print("Mark done") },
        onSnooze: { print("Snooze") },
        onDismiss: { print("Dismiss") }
    )
    .environment(appState)
}
