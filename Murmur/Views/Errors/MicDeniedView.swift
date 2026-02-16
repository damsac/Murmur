import SwiftUI

struct MicDeniedView: View {
    let onOpenSettings: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Background
            Theme.Colors.bgDeep
                .ignoresSafeArea()

            // Token balance in top right
            TokenBalanceLabel(balance: 4953, showWarning: false)
                .padding(.top, 66)
                .padding(.trailing, Theme.Spacing.screenPadding)

            // Centered error content
            VStack(spacing: 0) {
                Spacer()

                // Mic denied icon
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(Theme.Colors.accentRed.opacity(0.05), lineWidth: 1)
                        .frame(width: 136, height: 136)

                    // Middle ring
                    Circle()
                        .stroke(Theme.Colors.accentRed.opacity(0.1), lineWidth: 1)
                        .frame(width: 112, height: 112)

                    // Inner circle
                    Circle()
                        .stroke(Theme.Colors.accentRed.opacity(0.3), lineWidth: 2)
                        .fill(Theme.Colors.accentRed.opacity(0.06))
                        .frame(width: 88, height: 88)

                    // Mic with slash
                    ZStack {
                        // Mic icon
                        Image(systemName: "mic")
                            .font(.system(size: 36, weight: .regular))
                            .foregroundStyle(Theme.Colors.accentRed.opacity(0.5))

                        // Slash line
                        Rectangle()
                            .fill(Theme.Colors.accentRed)
                            .frame(width: 48, height: 2)
                            .rotationEffect(.degrees(-45))
                    }
                }
                .padding(.bottom, 40)

                // Title
                Text("Microphone Access Needed")
                    .font(.system(size: 24, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.bottom, 10)

                // Subtitle
                Text("Murmur needs your microphone to capture thoughts. Enable it in Settings.")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)

                // Open Settings button
                Button(action: onOpenSettings) {
                    HStack(spacing: 10) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20, weight: .medium))

                        Text("Open Settings")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
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

                Spacer()
            }
        }
    }
}

#Preview("Mic Denied") {
    @Previewable @State var appState = AppState()

    MicDeniedView(
        onOpenSettings: { print("Open Settings") }
    )
    .environment(appState)
}
