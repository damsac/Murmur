import SwiftUI
import SwiftData
import MurmurCore

// MARK: - Onboarding Content

private enum OnboardingContent {
    static let transcript = "hmm I keep forgetting things... I should try capturing ideas when they come up"

    static func makeExtracted() -> ExtractedEntry {
        ExtractedEntry(
            content: "Try capturing ideas and tasks the moment they come to mind",
            category: .todo,
            sourceText: transcript,
            summary: "Start capturing ideas as they come up",
            priority: 2
        )
    }
}

// MARK: - Onboarding Flow

struct OnboardingFlowView: View {
    let onComplete: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var currentStep: OnboardingStep = .transcript
    @State private var entry: ExtractedEntry = OnboardingContent.makeExtracted()

    enum OnboardingStep {
        case transcript
        case processing
    }

    var body: some View {
        ZStack {
            switch currentStep {
            case .transcript:
                OnboardingTranscriptView(
                    transcript: OnboardingContent.transcript,
                    onComplete: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                            currentStep = .processing
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            case .processing:
                ProcessingView(transcript: OnboardingContent.transcript)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        saveAndComplete()
                    }
            }
        }
    }

    private func saveAndComplete() {
        let saved = Entry(
            from: entry,
            transcript: OnboardingContent.transcript,
            source: .voice,
            audioDuration: nil
        )
        modelContext.insert(saved)
        do {
            try modelContext.save()
        } catch {
            print("Failed to save onboarding entry: \(error.localizedDescription)")
        }

        appState.hasCompletedOnboarding = true
        onComplete()
    }
}

#Preview("Onboarding Flow") {
    @Previewable @State var appState = AppState()

    OnboardingFlowView(onComplete: { print("Onboarding complete") })
        .environment(appState)
}
