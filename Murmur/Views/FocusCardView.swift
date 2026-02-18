import SwiftUI
import MurmurCore

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
    .environment(appState)
}

#Preview("Focus - Insight") {
    @Previewable @State var appState = AppState()

    FocusCardView(
        entry: Entry(
            transcript: "",
            content: "The best interfaces are invisible - they get out of the way and let users focus on their task",
            category: .thought,
            sourceText: "",
            summary: "The best interfaces are invisible - they get out of the way and let users focus on their task"
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
            transcript: "",
            content: "Team standup at 10am - prepare update on the authentication refactor",
            category: .reminder,
            sourceText: "",
            summary: "Team standup at 10am - prepare update on the authentication refactor",
            dueDate: Calendar.current.date(byAdding: .hour, value: 2, to: Date())
        ),
        onMarkDone: { print("Mark done") },
        onSnooze: { print("Snooze") },
        onDismiss: { print("Dismiss") }
    )
    .environment(appState)
}
