import SwiftUI

/// Animated edge glow shown during LLM processing.
/// Same color family as `ListeningGlowView` but faster rotation and
/// stronger pulse to convey "thinking" urgency.
struct ProcessingGlowView: View {
    @State private var rotationAngle: Double = 0
    @State private var pulseOpacity: Double = 0.8
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            let rect = geo.size

            RoundedRectangle(cornerRadius: 40)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Theme.Colors.accentPurple,
                            Theme.Colors.accentPurpleLight,
                            Color(hex: "D946EF"), // pink/magenta
                            Theme.Colors.accentPurple,
                            Theme.Colors.accentPurpleLight,
                            Color(hex: "D946EF"),
                            Theme.Colors.accentPurple
                        ]),
                        center: .center,
                        angle: .degrees(rotationAngle)
                    ),
                    lineWidth: 8
                )
                .blur(radius: 20)
                .opacity(pulseOpacity)
                .scaleEffect(pulseScale)
                .frame(width: rect.width, height: rect.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            // Faster rotation — more urgent energy than ListeningGlowView (4s)
            withAnimation(
                .linear(duration: 1.6)
                .repeatForever(autoreverses: false)
            ) {
                rotationAngle = 360
            }
            // Stronger, faster opacity pulse (0.8–1.0 in 0.9s)
            withAnimation(
                .easeInOut(duration: 0.9)
                .repeatForever(autoreverses: true)
            ) {
                pulseOpacity = 1.0
            }
            // Subtle scale breathe to draw attention
            withAnimation(
                .easeInOut(duration: 1.1)
                .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.03
            }
        }
    }
}

#Preview("Processing Glow") {
    ZStack {
        Theme.Colors.bgDeep
            .ignoresSafeArea()

        Text("Processing...")
            .foregroundStyle(Theme.Colors.textPrimary)

        ProcessingGlowView()
    }
}
