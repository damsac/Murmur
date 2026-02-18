import SwiftUI

struct OnboardingTranscriptView: View {
    let transcript: String
    let onComplete: () -> Void

    @State private var visibleCount = 0
    @State private var streamingTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Background — matches RecordingOverlay
            LinearGradient(
                colors: [
                    Theme.Colors.bgDeep,
                    Theme.Colors.bgDeep.opacity(0.95),
                    Theme.Colors.accentPurple.opacity(0.03)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Center: Pulsing mic and waveform
                VStack(spacing: 32) {
                    PulsingMicView()

                    WaveformView(isAnimating: true)
                        .frame(height: 60)
                        .padding(.horizontal, 60)
                }

                Spacer()

                // Bottom: Streaming transcript
                VStack(spacing: 20) {
                    Text(visibleText)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 60)
                }
                .padding(.bottom, 80)
            }
        }
        .onAppear {
            startStreaming()
        }
        .onDisappear {
            streamingTask?.cancel()
        }
    }

    private var visibleText: String {
        guard visibleCount > 0 else { return "" }
        let index = transcript.index(transcript.startIndex, offsetBy: min(visibleCount, transcript.count))
        let text = String(transcript[..<index])
        // Blinking cursor while streaming
        if visibleCount < transcript.count {
            return text + "|"
        }
        return text
    }

    private func startStreaming() {
        streamingTask = Task { @MainActor in
            for i in 1...transcript.count {
                if Task.isCancelled { return }

                visibleCount = i

                // Natural pacing: longer pause after punctuation
                let charIndex = transcript.index(transcript.startIndex, offsetBy: i - 1)
                let char = transcript[charIndex]
                let baseDelay: UInt64 = 35_000_000 // 35ms
                let jitter = UInt64.random(in: 0...10_000_000) // 0-10ms jitter

                if char == "." || char == "," || char == "—" {
                    try? await Task.sleep(nanoseconds: baseDelay * 4 + jitter)
                } else if char == " " {
                    try? await Task.sleep(nanoseconds: baseDelay + jitter * 2)
                } else {
                    try? await Task.sleep(nanoseconds: baseDelay + jitter)
                }
            }

            // Brief hold after streaming completes
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s

            if !Task.isCancelled {
                onComplete()
            }
        }
    }
}

#Preview("Onboarding Transcript") {
    OnboardingTranscriptView(
        transcript: "hmm I keep forgetting things... maybe I should try actually capturing my ideas when they come up",
        onComplete: { print("done") }
    )
}
