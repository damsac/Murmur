import SwiftUI

struct PulsingMicView: View {
    @State private var pulse1Scale: CGFloat = 1.0
    @State private var pulse1Opacity: Double = 0.6
    @State private var pulse2Scale: CGFloat = 1.0
    @State private var pulse2Opacity: Double = 0.6
    @State private var pulse3Scale: CGFloat = 1.0
    @State private var pulse3Opacity: Double = 0.6

    private let micSize: CGFloat = 88
    private let ringSize: CGFloat = 160

    var body: some View {
        ZStack {
            // Outermost ring (pulse 3)
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Theme.Colors.accentPurple,
                            Theme.Colors.accentPurpleLight
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: ringSize, height: ringSize)
                .scaleEffect(pulse3Scale)
                .opacity(pulse3Opacity)

            // Middle ring (pulse 2)
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Theme.Colors.accentPurple,
                            Theme.Colors.accentPurpleLight
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: ringSize * 0.75, height: ringSize * 0.75)
                .scaleEffect(pulse2Scale)
                .opacity(pulse2Opacity)

            // Inner ring (pulse 1)
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Theme.Colors.accentPurple,
                            Theme.Colors.accentPurpleLight
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
                .frame(width: ringSize * 0.5, height: ringSize * 0.5)
                .scaleEffect(pulse1Scale)
                .opacity(pulse1Opacity)

            // Center microphone
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Theme.Colors.accentPurple.opacity(0.4),
                                Theme.Colors.accentPurple.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: micSize / 2 + 20
                        )
                    )
                    .frame(width: micSize + 40, height: micSize + 40)

                // Mic button background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.Colors.accentPurple,
                                Theme.Colors.accentPurpleLight
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: micSize, height: micSize)
                    .shadow(
                        color: Theme.Colors.accentPurple.opacity(0.5),
                        radius: 20,
                        x: 0,
                        y: 4
                    )

                // Microphone icon
                Image(systemName: "mic.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .onAppear {
            startPulsing()
        }
    }

    private func startPulsing() {
        // Pulse 1 - fastest, innermost
        withAnimation(
            Animation.easeOut(duration: 1.5)
                .repeatForever(autoreverses: false)
        ) {
            pulse1Scale = 1.8
            pulse1Opacity = 0.0
        }

        // Pulse 2 - medium speed
        withAnimation(
            Animation.easeOut(duration: 1.5)
                .repeatForever(autoreverses: false)
                .delay(0.5)
        ) {
            pulse2Scale = 1.8
            pulse2Opacity = 0.0
        }

        // Pulse 3 - slowest, outermost
        withAnimation(
            Animation.easeOut(duration: 1.5)
                .repeatForever(autoreverses: false)
                .delay(1.0)
        ) {
            pulse3Scale = 1.8
            pulse3Opacity = 0.0
        }
    }
}

#Preview {
    PulsingMicView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.bgDeep)
}
