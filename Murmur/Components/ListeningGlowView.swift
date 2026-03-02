import SwiftUI

/// Animated edge glow around the screen while recording.
/// Inspired by Apple Intelligence / Siri edge glow effect.
struct ListeningGlowView: View {
    @State private var rotationAngle: Double = 0
    @State private var pulseOpacity: Double = 0.6

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
                    lineWidth: 5
                )
                .blur(radius: 20)
                .opacity(pulseOpacity)
                .frame(width: rect.width, height: rect.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            // Slow color rotation
            withAnimation(
                .linear(duration: 4)
                .repeatForever(autoreverses: false)
            ) {
                rotationAngle = 360
            }
            // Subtle pulse
            withAnimation(
                .easeInOut(duration: 2)
                .repeatForever(autoreverses: true)
            ) {
                pulseOpacity = 1.0
            }
        }
    }
}

#Preview("Listening Glow") {
    ZStack {
        Theme.Colors.bgDeep
            .ignoresSafeArea()

        Text("Recording...")
            .foregroundStyle(Theme.Colors.textPrimary)

        ListeningGlowView()
    }
}
