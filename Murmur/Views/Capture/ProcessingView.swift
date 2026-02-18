import SwiftUI
import MurmurCore

struct ProcessingView: View {
    @Environment(AppState.self) private var appState
    let entries: [ExtractedEntry]
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
            ExtractedEntry(
                content: "Review the new design system and provide feedback to the team by end of week",
                category: .todo,
                sourceText: "",
                summary: "Review the new design system and provide feedback to the team by end of week",
                priority: 1
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
            ExtractedEntry(
                content: "Review the new design system and provide feedback to the team",
                category: .todo,
                sourceText: "",
                summary: "Review the new design system and provide feedback to the team",
                priority: 1
            ),
            ExtractedEntry(
                content: "The best interfaces are invisible - they get out of the way",
                category: .thought,
                sourceText: "",
                summary: "The best interfaces are invisible - they get out of the way"
            ),
            ExtractedEntry(
                content: "Build a browser extension for quick voice notes",
                category: .idea,
                sourceText: "",
                summary: "Build a browser extension for quick voice notes",
                priority: 3
            )
        ],
        transcript: nil
    )
    .environment(appState)
}
