import SwiftUI

struct VoidView: View {
    @Environment(AppState.self) private var appState
    let onMicTap: () -> Void

    @State private var pulseScale1: CGFloat = 1.0
    @State private var pulseScale2: CGFloat = 1.0
    @State private var pulseScale3: CGFloat = 1.0
    @State private var pulseOpacity1: Double = 1.0
    @State private var pulseOpacity2: Double = 0.7
    @State private var pulseOpacity3: Double = 0.5

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Theme.Colors.bgDeep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Center: Pulsing mic
                VStack(spacing: 40) {
                    // Pulsing mic outline
                    ZStack {
                        // Outer ring 3
                        Circle()
                            .stroke(Theme.Colors.accentPurple.opacity(0.05), lineWidth: 1)
                            .frame(width: 136, height: 136)
                            .scaleEffect(pulseScale3)
                            .opacity(pulseOpacity3)

                        // Middle ring 2
                        Circle()
                            .stroke(Theme.Colors.accentPurple.opacity(0.1), lineWidth: 1)
                            .frame(width: 112, height: 112)
                            .scaleEffect(pulseScale2)
                            .opacity(pulseOpacity2)

                        // Inner circle 1
                        Circle()
                            .stroke(Theme.Colors.accentPurple.opacity(0.3), lineWidth: 2)
                            .frame(width: 88, height: 88)
                            .scaleEffect(pulseScale1)
                            .opacity(pulseOpacity1)

                        // Mic icon
                        Button(action: onMicTap) {
                            Image(systemName: "mic")
                                .font(.largeTitle)
                                .foregroundStyle(Theme.Colors.accentPurple.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Record your first voice note")
                    }
                    .onAppear {
                        startPulseAnimation()
                    }

                    // Title and subtitle
                    VStack(spacing: 10) {
                        Text("Say or type anything.")
                            .font(Theme.Typography.title)
                            .tracking(-0.5)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Text("Murmur remembers so you don't have to.")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineSpacing(2)
                            .devModeActivator() // 5-tap to open Dev Mode
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                }

                Spacer()
                Spacer()
            }
        }
    }

    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 3)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale1 = 1.05
            pulseOpacity1 = 0.8
        }

        withAnimation(
            .easeInOut(duration: 3)
            .repeatForever(autoreverses: true)
            .delay(0.5)
        ) {
            pulseScale2 = 1.05
            pulseOpacity2 = 0.5
        }

        withAnimation(
            .easeInOut(duration: 3)
            .repeatForever(autoreverses: true)
            .delay(1.0)
        ) {
            pulseScale3 = 1.05
            pulseOpacity3 = 0.3
        }
    }
}

#Preview("Void - Empty") {
    @Previewable @State var appState = AppState()

    VoidView(
        onMicTap: { print("Mic tapped") }
    )
    .environment(appState)
}
