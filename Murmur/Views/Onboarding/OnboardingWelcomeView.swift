import SwiftUI

struct OnboardingWelcomeView: View {
    let onContinue: () -> Void

    @State private var isAppearing = false

    var body: some View {
        ZStack {
            // Background
            Theme.Colors.bgDeep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 40) {
                    // Brand mark
                    ZStack {
                        // Outer ring
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(Theme.Colors.accentPurple.opacity(0.06), lineWidth: 1)
                            .frame(width: 112, height: 112)

                        // Main brand container
                        RoundedRectangle(cornerRadius: 28)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Theme.Colors.accentPurple.opacity(0.15),
                                        Theme.Colors.accentPurpleLight.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(Theme.Colors.accentPurple.opacity(0.2), lineWidth: 1)
                            )
                            .frame(width: 96, height: 96)

                        // Mic icon
                        Image(systemName: "mic.fill")
                            .font(.system(size: 44, weight: .medium))
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
                    .scaleEffect(isAppearing ? 1 : 0.9)
                    .opacity(isAppearing ? 1 : 0)

                    // Title and subtitle
                    VStack(spacing: 12) {
                        Text("Murmur")
                            .font(.system(size: 32, weight: .bold))
                            .tracking(-0.5)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Theme.Colors.textPrimary,
                                        Theme.Colors.accentPurpleLight
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        Text("Speak or type your thoughts.\nMurmur organizes them for you.")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .opacity(isAppearing ? 1 : 0)
                    .offset(y: isAppearing ? 0 : 10)

                    // Feature pills
                    HStack(spacing: 8) {
                        FeaturePill(label: "Todos", color: Theme.Colors.accentPurple)
                        FeaturePill(label: "Reminders", color: Theme.Colors.accentYellow)
                        FeaturePill(label: "Ideas", color: Theme.Colors.accentGreen)
                    }
                    .opacity(isAppearing ? 1 : 0)
                    .offset(y: isAppearing ? 0 : 10)
                }
                .padding(.horizontal, 40)

                Spacer()

                // Bottom CTA
                VStack(spacing: 12) {
                    Button(action: onContinue) {
                        HStack(spacing: 10) {
                            Text("Get started")
                                .font(.system(size: 17, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
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

                    Text("Your thoughts are encrypted end-to-end.")
                        .font(Theme.Typography.label)
                        .foregroundStyle(Theme.Colors.textMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
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
}

private struct FeaturePill: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(Theme.Typography.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(Theme.Colors.textTertiary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Theme.Colors.textPrimary.opacity(0.03))
                .overlay(
                    Capsule()
                        .stroke(Theme.Colors.textPrimary.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

#Preview("Onboarding Welcome") {
    OnboardingWelcomeView(onContinue: { print("Continue") })
}
