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
                    // TimelineView drives continuous phase animation without a Timer
                    TimelineView(.animation) { timeline in
                        let phase = timeline.date.timeIntervalSinceReferenceDate
                        waveView(width: screen.size.width, phase: phase)
                    }
                    .frame(height: 90)
                    .padding(.horizontal, 0)
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
    private func waveView(width w: CGFloat, phase: Double) -> some View {
        // Audio level drives amplitude: loud speech = very tall waves, silence = calm baseline
        let level = CGFloat(avgLevel)
        // Minimum amplitude keeps a gentle idle wave even in silence
        let idleAmplitude: CGFloat = 6
        // At full audio level the wave reaches ~70pt peak-to-trough
        let peakAmplitude: CGFloat = 70
        let amplitude = idleAmplitude + level * (peakAmplitude - idleAmplitude)

        // Wave speed: faster when speaking loudly (audio level scales 0→1)
        // Idle: ~0.8 cycles/sec. Loud: ~3 cycles/sec.
        let speed = 0.8 + Double(level) * 2.2

        // Number of full sine cycles across the width.
        // More cycles = more peaks visible = more energetic visualizer feel.
        // Idle: 3 cycles. Loud: 5 cycles.
        let cycles = 3.0 + Double(level) * 2.0

        // Second harmonic layer (half the amplitude, offset phase, slightly different frequency)
        // adds complexity and breaks the mechanical single-sine look.
        let cycles2 = cycles * 1.6
        let speed2 = speed * 0.75

        // Line width also breathes with audio level
        let lineWidth = 2.0 + level * 3.0

        Canvas { context, size in
            let h = size.height
            let midY = h * 0.55   // Sit slightly below center so wave has room to peak upward
            let steps = 120       // More steps = smoother curve

            var path = Path()
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let x = t * size.width

                // Primary wave
                let primary = sin(t * CGFloat(cycles) * 2 * .pi - CGFloat(phase * speed))

                // Secondary harmonic (adds texture, partially out of phase)
                let secondary = sin(t * CGFloat(cycles2) * 2 * .pi - CGFloat(phase * speed2) + 1.2)

                // Per-sample audio modulation: map buffer index → local level
                let bufIdx = Int(t * CGFloat(max(audioLevels.count - 1, 1)))
                let localLevel = bufIdx < audioLevels.count
                    ? CGFloat(audioLevels[bufIdx]) : level

                // Blend: 80% primary, 20% secondary harmonic for richness
                let wave = (primary * 0.8 + secondary * 0.2) * amplitude * max(localLevel, 0.08)
                let y = midY - wave   // subtract so positive audio → wave peaks upward

                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        Theme.Colors.accentPurple.opacity(0.2),
                        Theme.Colors.accentPurple.opacity(0.85),
                        Theme.Colors.accentPurpleLight,
                        Theme.Colors.accentPurple.opacity(0.85),
                        Theme.Colors.accentPurple.opacity(0.2)
                    ]),
                    startPoint: CGPoint(x: 0, y: midY),
                    endPoint: CGPoint(x: w, y: midY)
                ),
                lineWidth: lineWidth
            )
        }
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
