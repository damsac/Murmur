import SwiftUI
import MurmurCore

struct ProcessingOverlay: View {
    let transcript: String?

    @State private var spinnerRotation: Double = 0

    var body: some View {
        ZStack {
            Theme.Colors.bgDeep
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // Spinner
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Theme.Colors.accentPurple,
                                Theme.Colors.accentPurpleLight,
                                Theme.Colors.accentPurple.opacity(0.3)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(spinnerRotation))
                    .onAppear {
                        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                            spinnerRotation = 360
                        }
                    }

                // Frozen waveform
                WaveformView(isAnimating: false)
                    .frame(height: 60)
                    .padding(.horizontal, 60)
                    .opacity(0.6)

                // Processing text
                Text("Processing...")
                    .font(Theme.Typography.navTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("AI is organizing your thoughts")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }
}

#Preview("Processing") {
    ProcessingOverlay(transcript: "Review the new design system")
}
