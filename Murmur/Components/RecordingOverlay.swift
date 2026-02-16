import SwiftUI

struct RecordingOverlay: View {
    let transcript: String
    let tokenBalance: Int
    let onStopRecording: () -> Void

    @State private var showTranscript = false

    var body: some View {
        ZStack {
            // Background - deep with subtle gradient
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
                // Top section with token balance
                HStack {
                    Spacer()
                    TokenBalanceLabel(
                        balance: tokenBalance,
                        showWarning: tokenBalance < 100
                    )
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .padding(.top, 60)

                Spacer()

                // Center: Pulsing mic and waveform
                VStack(spacing: 32) {
                    PulsingMicView()

                    WaveformView(isAnimating: true)
                        .frame(height: 60)
                        .padding(.horizontal, 60)
                }

                Spacer()

                // Bottom: Transcript area
                VStack(spacing: 20) {
                    // Transcript text
                    if !transcript.isEmpty {
                        ScrollView {
                            Text(transcript)
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxHeight: 120)
                        .opacity(showTranscript ? 1 : 0)
                        .animation(Animations.subtlePulse.delay(0.3), value: showTranscript)
                    } else {
                        Text("Listening...")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .opacity(0.6)
                    }

                    // Stop button
                    Button(action: onStopRecording) {
                        HStack(spacing: 10) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Stop Recording")
                                .font(Theme.Typography.bodyMedium)
                        }
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(Theme.Colors.bgCard)
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Theme.Colors.accentPurple.opacity(0.3),
                                                    Theme.Colors.accentPurple.opacity(0.1)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                        )
                        .shadow(
                            color: Theme.Colors.accentPurple.opacity(0.15),
                            radius: 16,
                            x: 0,
                            y: 8
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            showTranscript = true
        }
    }
}

#Preview("Recording - Empty") {
    RecordingOverlay(
        transcript: "",
        tokenBalance: 1250,
        onStopRecording: { print("Stop recording") }
    )
}

#Preview("Recording - With Transcript") {
    RecordingOverlay(
        transcript: "Review the new design system and provide feedback to the team by end of week",
        tokenBalance: 850,
        onStopRecording: { print("Stop recording") }
    )
}

#Preview("Recording - Long Transcript") {
    RecordingOverlay(
        transcript: "Review the new design system and provide feedback to the team by end of week. Check typography and spacing.",
        tokenBalance: 450,
        onStopRecording: { print("Stop recording") }
    )
}

#Preview("Recording - Low Balance") {
    RecordingOverlay(
        transcript: "This is a recording with low token balance",
        tokenBalance: 75,
        onStopRecording: { print("Stop recording") }
    )
}

#Preview("Recording - Zero Balance") {
    RecordingOverlay(
        transcript: "Running out of tokens during recording",
        tokenBalance: 0,
        onStopRecording: { print("Stop recording") }
    )
}
