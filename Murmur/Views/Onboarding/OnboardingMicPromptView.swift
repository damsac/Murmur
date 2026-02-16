import SwiftUI
import AVFoundation

struct OnboardingMicPromptView: View {
    let onAllow: () -> Void
    let onSkip: () -> Void

    @State private var isAppearing = false
    @State private var pulseScale1: CGFloat = 1.0
    @State private var pulseScale2: CGFloat = 1.0
    @State private var pulseOpacity1: Double = 1.0
    @State private var pulseOpacity2: Double = 1.0

    var body: some View {
        ZStack {
            // Background
            Theme.Colors.bgDeep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 40) {
                    // Pulsing mic illustration
                    ZStack {
                        // Outer pulse ring
                        Circle()
                            .stroke(Theme.Colors.accentPurple.opacity(0.08), lineWidth: 1)
                            .frame(width: 108, height: 108)
                            .scaleEffect(pulseScale2)
                            .opacity(pulseOpacity2)

                        // Main circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Theme.Colors.accentPurple.opacity(0.12),
                                        Theme.Colors.accentPurple.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(Theme.Colors.accentPurple.opacity(0.2), lineWidth: 1.5)
                            )
                            .frame(width: 96, height: 96)
                            .scaleEffect(pulseScale1)
                            .opacity(pulseOpacity1)

                        // Mic icon
                        Image(systemName: "mic.fill")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Theme.Colors.accentPurple,
                                        Theme.Colors.accentPurpleLight
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAppearing ? 1 : 0.9)
                    .opacity(isAppearing ? 1 : 0)
                    .onAppear {
                        startPulseAnimation()
                    }

                    // Title and subtitle
                    VStack(spacing: 10) {
                        Text("Enable microphone")
                            .font(.system(size: 24, weight: .bold))
                            .tracking(-0.3)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Text("Speak naturally and Murmur will capture, categorize, and remember your thoughts.")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 36)
                    .opacity(isAppearing ? 1 : 0)
                    .offset(y: isAppearing ? 0 : 10)

                    // How it works
                    VStack(alignment: .leading, spacing: 0) {
                        Text("HOW IT WORKS")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .padding(.bottom, 14)

                        VStack(spacing: 0) {
                            HowItWorksStep(
                                number: 1,
                                text: "Speak or type your thoughts"
                            )

                            Divider()
                                .background(Theme.Colors.textPrimary.opacity(0.04))
                                .padding(.leading, 46)

                            HowItWorksStep(
                                number: 2,
                                text: "AI extracts todos, reminders, and ideas"
                            )

                            Divider()
                                .background(Theme.Colors.textPrimary.opacity(0.04))
                                .padding(.leading, 46)

                            HowItWorksStep(
                                number: 3,
                                text: "Review, accept, and never forget"
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 36)
                    .opacity(isAppearing ? 1 : 0)
                    .offset(y: isAppearing ? 0 : 10)
                }

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    Button(action: handleAllowMicrophone) {
                        HStack(spacing: 10) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Allow microphone")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Theme.Colors.accentPurple,
                                            Theme.Colors.accentPurpleLight
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .shadow(
                            color: Theme.Colors.accentPurple.opacity(0.3),
                            radius: 20,
                            x: 0,
                            y: 4
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: onSkip) {
                        Text("I'll just type for now")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .padding(.bottom, 40)
                .opacity(isAppearing ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                isAppearing = true
            }
        }
    }

    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 3)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale1 = 1.03
            pulseOpacity1 = 0.8
        }

        withAnimation(
            .easeInOut(duration: 3)
            .repeatForever(autoreverses: true)
            .delay(0.5)
        ) {
            pulseScale2 = 1.05
            pulseOpacity2 = 0.6
        }
    }

    private func handleAllowMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in
            DispatchQueue.main.async {
                onAllow()
            }
        }
    }
}

private struct HowItWorksStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            // Step number
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.Colors.accentPurple.opacity(0.1))
                .frame(width: 32, height: 32)
                .overlay(
                    Text("\(number)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.Colors.accentPurple)
                )

            // Step text
            Text(text)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
        .padding(.vertical, 12)
    }
}

#Preview("Mic Permission") {
    OnboardingMicPromptView(
        onAllow: { print("Allow") },
        onSkip: { print("Skip") }
    )
}
