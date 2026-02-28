import SwiftUI
import MurmurCore

struct ProcessingView: View {
    let transcript: String?

    var body: some View {
        ProcessingOverlay(transcript: transcript)
    }
}

#Preview("Processing") {
    ProcessingView(transcript: "Review the new design system and provide feedback")
}
