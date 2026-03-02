import SwiftUI

/// Recording state overlay — minimal wave line at top, floating transcript.
/// No backdrop, content stays visible. Reactive sine wave driven by real audio input.
struct RecordingStateView: View {
    let transcript: String
    let audioLevels: [Float]

    private var avgLevel: Float {
        guard !audioLevels.isEmpty else { return 0 }
        let recent = audioLevels.suffix(8)
        return recent.reduce(0, +) / Float(recent.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Reactive wave line at top
            GeometryReader { geo in
                let w = geo.size.width
                let amplitude = CGFloat(avgLevel) * 30

                Path { path in
                    let steps = 60
                    for i in 0...steps {
                        let x = w * CGFloat(i) / CGFloat(steps)
                        let bufIdx = Int(Float(i) / Float(steps) * Float(max(audioLevels.count - 1, 1)))
                        let localLevel = bufIdx < audioLevels.count ? CGFloat(audioLevels[bufIdx]) : 0
                        let y: CGFloat = 25 + sin(CGFloat(i) * .pi / 8) * amplitude * localLevel

                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            Theme.Colors.accentPurple.opacity(0.3),
                            Theme.Colors.accentPurple,
                            Theme.Colors.accentPurpleLight,
                            Theme.Colors.accentPurple,
                            Theme.Colors.accentPurple.opacity(0.3)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )
            }
            .frame(height: 50)
            .padding(.top, 12)
            .padding(.horizontal, 16)
            .animation(.easeOut(duration: 0.08), value: audioLevels.last ?? 0)

            Spacer()

            // Floating transcript — no container
            if !transcript.isEmpty {
                Text(transcript)
                    .font(.system(.body, design: .default, weight: .regular))
                    .foregroundStyle(Theme.Colors.textPrimary.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .lineLimit(8)
                    .padding(.horizontal, Theme.Spacing.screenPadding + 8)
                    .animation(.easeOut(duration: 0.15), value: transcript)
            } else {
                Text("Listening...")
                    .font(.system(.body, design: .default, weight: .regular))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            Spacer()
        }
        .allowsHitTesting(false)
    }
}

#Preview("Minimal — Empty") {
    ZStack {
        Theme.Colors.bgDeep.ignoresSafeArea()
        RecordingStateView(transcript: "", audioLevels: [])
    }
}

#Preview("Minimal — Active") {
    let fakeLevels: [Float] = (0..<50).map { _ in Float.random(in: 0.1...0.8) }
    ZStack {
        Theme.Colors.bgDeep.ignoresSafeArea()
        RecordingStateView(
            transcript: "I need to pick up groceries tomorrow and call the dentist",
            audioLevels: fakeLevels
        )
    }
}
