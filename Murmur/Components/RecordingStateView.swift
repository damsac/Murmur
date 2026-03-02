import SwiftUI

/// Recording state overlay — transcript anchored above stop button growing upward,
/// dark fade behind text, thin ambient wave at bottom edge.
/// No backdrop on transparent areas. Reactive sine wave driven by real audio input.
struct RecordingStateView: View {
    let transcript: String
    let audioLevels: [Float]

    /// Bottom padding so transcript clears the stop button area
    private let bottomPad = Theme.Spacing.micButtonSize + 24

    /// Max fraction of screen height the transcript can occupy before clipping
    private let maxHeightFraction: CGFloat = 0.6

    private var avgLevel: Float {
        guard !audioLevels.isEmpty else { return 0 }
        let recent = audioLevels.suffix(8)
        return recent.reduce(0, +) / Float(recent.count)
    }

    var body: some View {
        GeometryReader { screen in
            ZStack(alignment: .bottom) {
                // --- Dark fade gradient behind transcript ---
                if !transcript.isEmpty {
                    VStack(spacing: 0) {
                        Spacer()
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Theme.Colors.bgDeep.opacity(0.6),
                                Theme.Colors.bgDeep.opacity(0.95),
                                Theme.Colors.bgDeep
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        // Gradient covers transcript max height + breathing room
                        .frame(
                            height: screen.size.height * maxHeightFraction + bottomPad + 60
                        )
                    }
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.25), value: transcript.isEmpty)
                }

                // --- Bottom-anchored transcript + wave stack ---
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    // Transcript text — grows upward from bottom anchor
                    if !transcript.isEmpty {
                        Text(transcript)
                            .font(.system(.body, design: .default, weight: .regular))
                            .foregroundStyle(Theme.Colors.textPrimary.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .lineLimit(12)
                            .padding(.horizontal, Theme.Spacing.screenPadding + 8)
                            .frame(
                                maxHeight: screen.size.height * maxHeightFraction,
                                alignment: .bottom
                            )
                            .animation(.easeOut(duration: 0.15), value: transcript)
                    }

                    // Spacing to clear the stop button / nav bar
                    Spacer()
                        .frame(height: bottomPad)

                    // Reactive wave line at bottom — extends into unsafe area
                    waveView(width: screen.size.width)
                        .frame(height: 50)
                        .padding(.horizontal, 16)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.08), value: audioLevels.last ?? 0)
    }

    // MARK: - Wave

    @ViewBuilder
    private func waveView(width w: CGFloat) -> some View {
        let amplitude = CGFloat(avgLevel) * 30

        Path { path in
            let steps = 60
            for i in 0...steps {
                let x = w * CGFloat(i) / CGFloat(steps)
                let bufIdx = Int(
                    Float(i) / Float(steps) * Float(max(audioLevels.count - 1, 1))
                )
                let localLevel = bufIdx < audioLevels.count
                    ? CGFloat(audioLevels[bufIdx]) : 0
                let y: CGFloat = 25
                    + sin(CGFloat(i) * .pi / 8) * amplitude * localLevel

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

#Preview("Long Transcript") {
    let fakeLevels: [Float] = (0..<50).map { _ in Float.random(in: 0.1...0.8) }
    ZStack {
        // Bright background to verify dark fade works
        Color.purple.opacity(0.3).ignoresSafeArea()
        RecordingStateView(
            transcript: """
            I need to pick up groceries tomorrow and call the dentist. \
            Also remind me to send the report to Sarah by Friday. \
            Oh and book a table for dinner on Saturday night, somewhere nice, \
            maybe Italian. And don't forget to water the plants.
            """,
            audioLevels: fakeLevels
        )
    }
}
