import SwiftUI

struct APIErrorView: View {
    let duration: TimeInterval
    let inputTokens: Int
    let onRetry: () -> Void
    let onSaveRaw: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Blurred background
            BlurredBackgroundView()

            // Dark overlay
            Rectangle()
                .fill(Theme.Colors.bgDeep.opacity(0.98))
                .ignoresSafeArea()

            // Error content
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 54)

                // Duration (frozen)
                Text(formattedDuration)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .monospacedDigit()
                    .tracking(1)
                    .padding(.bottom, 40)

                // Error icon
                ZStack {
                    Circle()
                        .fill(Theme.Colors.accentRed.opacity(0.06))
                        .frame(width: 88, height: 88)

                    Circle()
                        .stroke(Theme.Colors.accentRed.opacity(0.3), lineWidth: 3)
                        .frame(width: 88, height: 88)

                    Image(systemName: "xmark")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Theme.Colors.accentRed)
                }
                .frame(width: 120, height: 120)
                .padding(.bottom, 48)

                // Frozen waveform
                WaveformView(isAnimating: false)
                    .padding(.bottom, 24)

                // Error status
                Text("Something went wrong")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.bottom, 8)

                Text("Your recording was saved")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.bottom, 32)

                // Token flow
                HStack(spacing: 14) {
                    HStack(spacing: 4) {
                        Text("↑")
                            .foregroundStyle(Theme.Colors.accentPurple.opacity(0.6))
                        Text("\(inputTokens) in")
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }

                    Text("·")
                        .foregroundStyle(Color(red: 0.165, green: 0.165, blue: 0.204))

                    HStack(spacing: 4) {
                        Text("↓")
                            .foregroundStyle(Theme.Colors.accentGreen.opacity(0.6))
                        Text("0 out")
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .tracking(0.3)
                .padding(.bottom, 40)

                // Action buttons
                VStack(spacing: 12) {
                    // Retry button
                    Button(action: onRetry) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20, weight: .bold))

                            Text("Retry")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(maxWidth: 300)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.Colors.accentPurple, Theme.Colors.accentPurpleLight],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Theme.Colors.accentPurple.opacity(0.3), radius: 20, y: 4)
                        )
                    }
                    .buttonStyle(.plain)

                    // Save raw button
                    Button(action: onSaveRaw) {
                        Text("Save as raw")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .onTapGesture {
            // Allow dismissal by tapping outside buttons
        }
    }

    private var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Blurred Background

private struct BlurredBackgroundView: View {
    var body: some View {
        VStack(spacing: 14) {
            Spacer()
                .frame(height: 130)

            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.Colors.bgCard)
                .frame(height: 90)

            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.Colors.bgCard)
                    .frame(height: 110)

                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.Colors.bgCard)
                    .frame(height: 110)
            }

            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.Colors.bgCard)
                .frame(height: 140)

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.screenPadding)
        .blur(radius: 8)
        .opacity(0.3)
    }
}

#Preview("API Error") {
    @Previewable @State var appState = AppState()

    APIErrorView(
        duration: 12,
        inputTokens: 247,
        onRetry: { print("Retry") },
        onSaveRaw: { print("Save raw") },
        onDismiss: { print("Dismiss") }
    )
    .environment(appState)
}
