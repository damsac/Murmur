import SwiftUI

struct ProcessingView: View {
    @Environment(AppState.self) private var appState
    let entries: [Entry]
    let transcript: String?

    var body: some View {
        ProcessingOverlay(
            entries: entries,
            transcript: transcript
        )
    }
}

#Preview("Processing - Single Entry") {
    @Previewable @State var appState = AppState()

    ProcessingView(
        entries: [
            Entry(
                summary: "Review the new design system and provide feedback to the team by end of week",
                category: .todo,
                priority: 2,
                aiGenerated: true
            )
        ],
        transcript: "Review the design system and provide feedback"
    )
    .environment(appState)
}

#Preview("Processing - Multiple Entries") {
    @Previewable @State var appState = AppState()

    ProcessingView(
        entries: [
            Entry(
                summary: "Review the new design system and provide feedback to the team",
                category: .todo,
                priority: 2,
                aiGenerated: true
            ),
            Entry(
                summary: "The best interfaces are invisible - they get out of the way",
                category: .insight,
                aiGenerated: true
            ),
            Entry(
                summary: "Build a browser extension for quick voice notes",
                category: .idea,
                priority: 1,
                aiGenerated: true
            )
        ],
        transcript: nil
    )
    .environment(appState)
}
