import SwiftUI

/// Animated edge glow shown during LLM processing.
/// Same color family as `ListeningGlowView` but faster rotation and
/// stronger pulse to convey "thinking" urgency.
struct ProcessingGlowView: View {
    @State private var rotationAngle: Double = 0
    @State private var pulseOpacity: Double = 0.7

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
                    lineWidth: 6
                )
                .blur(radius: 24)
                .opacity(pulseOpacity)
                .frame(width: rect.width, height: rect.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            // Faster rotation — more urgent energy than ListeningGlowView (4s)
            withAnimation(
                .linear(duration: 2.2)
                .repeatForever(autoreverses: false)
            ) {
                rotationAngle = 360
            }
            // Stronger, faster pulse (0.7–1.0 in 1.2s vs 0.6–1.0 in 2s)
            withAnimation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true)
            ) {
                pulseOpacity = 1.0
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
