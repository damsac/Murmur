import SwiftUI

struct OnboardingWelcomeView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var showContent = false

    var body: some View {
        ZStack {
            // Background — deep dark with faint purple at bottom
            ZStack {
                Theme.Colors.bgDeep
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Theme.Colors.accentPurple.opacity(0.14),
                        Color.clear
                    ],
                    startPoint: .bottom,
                    endPoint: .center
                )
                .ignoresSafeArea()
            }

            // Skip button — top-right corner
            VStack {
                HStack {
                    Spacer()
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(Theme.Typography.bodyMedium)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.trailing, Theme.Spacing.screenPadding)
                    .padding(.top, 16)
                }
                Spacer()
            }
            .opacity(showContent ? 1 : 0)
            .animation(.easeOut(duration: 0.3).delay(0.5), value: showContent)

            // Main content
            VStack(spacing: 0) {
                Spacer()

                // Visual anchor
                PulsingMicView()
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 24)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: showContent)

                Spacer().frame(height: 48)

                // Headline
                Text("Stop losing\nyour thoughts.")
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 16)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: showContent)

                Spacer().frame(height: 16)

                // Body
                Text("Just speak — Murmur captures and organizes everything automatically.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 12)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: showContent)

                Spacer()

                // CTA
                Button(action: onContinue) {
                    HStack(spacing: 8) {
                        Text("See how it works")
                            .font(Theme.Typography.bodyMedium)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Theme.purpleGradient)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius))
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .padding(.bottom, 48)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 12)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: showContent)
            }
        }
        .onAppear {
            showContent = true
        }
    }
}

#Preview("Onboarding Welcome") {
    OnboardingWelcomeView(
        onContinue: { print("continue") },
        onSkip: { print("skip") }
    )
}
