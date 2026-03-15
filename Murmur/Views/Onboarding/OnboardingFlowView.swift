import SwiftUI
import SwiftData
import MurmurCore

// MARK: - Onboarding Content

private enum OnboardingContent {
    // swiftlint:disable:next line_length
    static let transcript = "Ok so I really need to get that client proposal done before Friday — the whole team is waiting on it. Oh and remind me to call the dentist at some point this week. Also I want to start doing morning runs every day."

    static func makeDisplayEntries() -> [Entry] {
        let dueDate = nextFriday()
        return [
            Entry(
                transcript: transcript,
                content: "Finish client proposal before Friday",
                category: .todo,
                sourceText: "I really need to get that client proposal done before Friday",
                summary: "Finish client proposal",
                priority: 1,
                dueDate: dueDate
            ),
            Entry(
                transcript: transcript,
                content: "Call dentist this week",
                category: .reminder,
                sourceText: "remind me to call the dentist at some point this week",
                summary: "Call dentist this week"
            ),
            Entry(
                transcript: transcript,
                content: "Morning run every day",
                category: .habit,
                sourceText: "I want to start doing morning runs every day",
                summary: "Morning run",
                cadenceRawValue: "daily"
            ),
        ]
    }

    private static func nextFriday() -> Date {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today) // 1=Sun … 7=Sat, Friday=6
        let daysUntilFriday = (6 - weekday + 7) % 7
        let days = daysUntilFriday == 0 ? 7 : daysUntilFriday
        return cal.date(byAdding: .day, value: days, to: today) ?? today
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
