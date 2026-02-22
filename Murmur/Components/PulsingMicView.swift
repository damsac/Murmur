import SwiftUI

struct PulsingMicView: View {
    private let micSize: CGFloat = 88
    private let ringSize: CGFloat = 160

    var body: some View {
        ZStack {
            PulseRing(diameter: ringSize, lineWidth: 2, delay: 1.0)
            PulseRing(diameter: ringSize * 0.75, lineWidth: 2, delay: 0.5)
            PulseRing(diameter: ringSize * 0.5, lineWidth: 2.5, delay: 0)

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
    }
}

// MARK: - Pulse Ring

private struct PulseRing: View {
    let diameter: CGFloat
    let lineWidth: CGFloat
    let delay: Double

    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.6

    var body: some View {
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
                lineWidth: lineWidth
            )
            .frame(width: diameter, height: diameter)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    Animation.easeOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                        .delay(delay)
                ) {
                    scale = 1.8
                    opacity = 0.0
                }
            }
    }
}

#Preview {
    PulsingMicView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.bgDeep)
}
