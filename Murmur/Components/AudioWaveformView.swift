import SwiftUI

/// Waveform visualization driven by real audio level data.
/// Renders a horizontal bar chart that reacts to live microphone input.
/// Falls back to a gentle idle pulse when no audio data is present.
struct AudioWaveformView: View {
    /// Rolling buffer of audio levels (0.0–1.0), most recent at end.
    let levels: [Float]
    /// Number of bars to display.
    let barCount: Int

    var barWidth: CGFloat = 3
    var barSpacing: CGFloat = 3
    var maxBarHeight: CGFloat = 80
    var minBarHeight: CGFloat = 4

    @State private var idlePulse: Bool = false

    private var hasRealData: Bool {
        levels.contains { $0 > 0.02 }
    }

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: barWidth / 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.Colors.accentPurple,
                                Theme.Colors.accentPurpleLight
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(
                        width: barWidth,
                        height: barHeight(index: index)
                    )
                    .opacity(hasRealData ? 1.0 : 0.5)
                    .animation(.easeOut(duration: 0.07), value: barLevel(at: index))
            }
        }
        .frame(height: maxBarHeight)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                idlePulse = true
            }
        }
    }

    private func barHeight(index: Int) -> CGFloat {
        let level = barLevel(at: index)
        if hasRealData && level > 0.01 {
            // Real data — full dramatic range
            return minBarHeight + CGFloat(level) * (maxBarHeight - minBarHeight)
        }
        if hasRealData {
            // Has data but this particular bar is silent — stay small
            return minBarHeight
        }
        // Idle pulse: gentle wave pattern when no data at all
        let center = CGFloat(barCount) / 2.0
        let dist = abs(CGFloat(index) - center) / center
        let base: CGFloat = idlePulse ? 0.18 : 0.06
        let factor = (1.0 - dist * 0.6) * base
        return minBarHeight + factor * (maxBarHeight - minBarHeight)
    }

    private func barLevel(at index: Int) -> Float {
        guard !levels.isEmpty else { return 0 }
        let offset = levels.count - barCount + index
        guard offset >= 0 else { return 0 }
        return levels[offset]
    }
}

#Preview("Idle") {
    AudioWaveformView(levels: [], barCount: 35)
        .padding()
        .background(Theme.Colors.bgDeep)
}

#Preview("Active") {
    let fakeLevels: [Float] = (0..<40).map { _ in Float.random(in: 0.1...0.9) }
    AudioWaveformView(levels: fakeLevels, barCount: 35)
        .padding()
        .background(Theme.Colors.bgDeep)
}
