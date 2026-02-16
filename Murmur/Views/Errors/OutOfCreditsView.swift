import SwiftUI

struct OutOfCreditsView: View {
    let transcript: String
    let duration: TimeInterval
    let onTopUp: () -> Void
    let onSaveRaw: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Theme.Colors.bgDeep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Review")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.3)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text("Here's what I heard")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .padding(.top, 70)
                .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 20) {
                        // Warning card
                        VStack(spacing: 14) {
                            // Icon
                            ZStack {
                                Circle()
                                    .fill(Theme.Colors.accentRed.opacity(0.1))
                                    .frame(width: 48, height: 48)

                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(Theme.Colors.accentRed)
                            }

                            Text("Out of tokens")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Theme.Colors.accentRed)

                            Text("Recording saved but not categorized.\nTop up to process your thoughts.")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Theme.Colors.accentRed.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Theme.Colors.accentRed.opacity(0.15), lineWidth: 1)
                                )
                        )

                        // Token balance (zero)
                        HStack(spacing: 8) {
                            Text("Balance")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.Colors.textTertiary)

                            Text("0")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Theme.Colors.accentRed)
                                .monospacedDigit()
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Theme.Colors.accentRed.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.Colors.accentRed.opacity(0.08), lineWidth: 1)
                                )
                        )

                        // Transcript section
                        VStack(spacing: 0) {
                            // Header
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "mic")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("TRANSCRIPT")
                                        .font(.system(size: 11, weight: .semibold))
                                        .tracking(0.6)
                                }
                                .foregroundStyle(Theme.Colors.textTertiary)

                                Spacer()

                                Text(formattedDuration)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(red: 0.227, green: 0.227, blue: 0.282)) // #3A3A48
                            }
                            .padding(.bottom, 8)

                            // Transcript text
                            Text("\"\(transcript)\"")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .italic()
                                .lineSpacing(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Theme.Colors.textPrimary.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Theme.Colors.textPrimary.opacity(0.05), lineWidth: 1)
                                )
                        )

                        // Session cost
                        HStack(spacing: 4) {
                            Text("↑")
                                .foregroundStyle(Theme.Colors.accentPurple.opacity(0.6))
                            Text("0 in")
                            Text("·")
                                .foregroundStyle(Color(red: 0.165, green: 0.165, blue: 0.204))
                            Text("↓")
                                .foregroundStyle(Theme.Colors.accentGreen.opacity(0.6))
                            Text("0 out")
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .monospacedDigit()
                        .tracking(0.1)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(Theme.Colors.textPrimary.opacity(0.04))
                                .frame(height: 1)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.screenPadding)
                    .padding(.bottom, 180) // Space for footer
                }
            }

            // Footer with actions
            VStack {
                Spacer()
                VStack(spacing: 12) {
                    // Top up button
                    Button(action: onTopUp) {
                        HStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))

                            Text("Top up tokens")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
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
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .padding(.bottom, 40)
                .background(
                    LinearGradient(
                        colors: [Color.clear, Theme.Colors.bgDeep, Theme.Colors.bgDeep],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }

    private var formattedDuration: String {
        let seconds = Int(duration)
        return "\(seconds)s"
    }
}

#Preview("Out of Credits") {
    @Previewable @State var appState = AppState()

    OutOfCreditsView(
        transcript: "I need to pick up dry cleaning before six, oh and remind me about the DMV on Thursday, also I had this idea about an app that turns receipts into meal plans",
        duration: 12,
        onTopUp: { print("Top up") },
        onSaveRaw: { print("Save raw") }
    )
    .environment(appState)
}
