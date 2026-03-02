import SwiftUI
import SwiftData
import MurmurCore

// MARK: - Onboarding Content

private enum OnboardingContent {
    static let transcript = "Gotta call mom before the weekend. We're out of milk and eggs too. Oh — what if you could share entries with other people?"

    static func makeDisplayEntries() -> [Entry] {
        [
            Entry(
                transcript: transcript,
                content: "Call mom before the weekend",
                category: .reminder,
                sourceText: "Gotta call mom before the weekend.",
                summary: "Call mom before the weekend"
            ),
            Entry(
                transcript: transcript,
                content: "Pick up milk and eggs",
                category: .todo,
                sourceText: "We're out of milk and eggs too.",
                summary: "Pick up milk and eggs"
            ),
            Entry(
                transcript: transcript,
                content: "Let users share entries with friends",
                category: .idea,
                sourceText: "What if you could share entries with other people?",
                summary: "Share entries with friends"
            ),
        ]
    }
}

// MARK: - Onboarding Flow

struct OnboardingFlowView: View {
    let onComplete: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var currentStep: OnboardingStep = .welcome
    @State private var displayEntries: [Entry] = OnboardingContent.makeDisplayEntries()

    enum OnboardingStep {
        case welcome
        case transcript
        case processing
        case result
    }

    var body: some View {
        ZStack {
            switch currentStep {
            case .welcome:
                OnboardingWelcomeView(
                    onContinue: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                            currentStep = .transcript
                        }
                    },
                    onSkip: skipAndComplete
                )
                .transition(.opacity)

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
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            case .processing:
                ProcessingView(transcript: OnboardingContent.transcript)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .task {
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                            currentStep = .result
                        }
                    }

            case .result:
                OnboardingResultView(
                    entries: displayEntries,
                    onSaveAndComplete: saveAndComplete
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
    }

    private func saveAndComplete() {
        for entry in displayEntries {
            modelContext.insert(entry)
        }
        do {
            try modelContext.save()
        } catch {
            print("Failed to save onboarding entries: \(error.localizedDescription)")
        }

        appState.hasCompletedOnboarding = true
        onComplete()
    }

    private func skipAndComplete() {
        appState.hasCompletedOnboarding = true
        onComplete()
    }
}

#Preview("Onboarding Flow") {
    @Previewable @State var appState = AppState()

    OnboardingFlowView(onComplete: { print("Onboarding complete") })
        .environment(appState)
        .modelContainer(for: Entry.self, inMemory: true)
}
