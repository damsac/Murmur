import SwiftUI

struct RecordingView: View {
    @Environment(AppState.self) private var appState
    @Binding var transcript: String
    let onStop: () -> Void

    var body: some View {
        RecordingOverlay(
            transcript: transcript,
            tokenBalance: 4953, // Mock balance
            onStopRecording: onStop
        )
    }
}

#Preview("Recording") {
    @Previewable @State var transcript = "Review the new design system and provide feedback to the team"
    @Previewable @State var appState = AppState()

    RecordingView(
        transcript: $transcript,
        onStop: { print("Stop recording") }
    )
    .environment(appState)
}
