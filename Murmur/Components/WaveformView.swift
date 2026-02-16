import SwiftUI

struct WaveformView: View {
    let isAnimating: Bool
    let barCount: Int = 19

    @State private var barHeights: [CGFloat] = Array(repeating: 0.3, count: 19)

    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 4
    private let maxBarHeight: CGFloat = 60
    private let minBarHeight: CGFloat = 8

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(
                    height: barHeights[index],
                    maxHeight: maxBarHeight,
                    minHeight: minBarHeight,
                    width: barWidth,
                    isAnimating: isAnimating
                )
                .animation(
                    isAnimating
                        ? Animation.easeInOut(duration: Double.random(in: 0.4...0.7))
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.05)
                        : .default,
                    value: isAnimating
                )
            }
        }
        .frame(height: maxBarHeight)
        .onAppear {
            if isAnimating {
                startAnimating()
            } else {
                setFrozenHeights()
            }
        }
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                startAnimating()
            } else {
                setFrozenHeights()
            }
        }
    }

    private func startAnimating() {
        withAnimation {
            for i in 0..<barCount {
                // Create varied heights for visual interest
                // Center bars tend to be taller
                let centerDistance = abs(CGFloat(i) - CGFloat(barCount) / 2)
                let heightFactor = 1.0 - (centerDistance / CGFloat(barCount) * 0.4)
                barHeights[i] = CGFloat.random(in: 0.4...0.95) * heightFactor
            }
        }
    }

    private func setFrozenHeights() {
        withAnimation(.easeOut(duration: 0.3)) {
            // Set to a pleasing static pattern
            let pattern: [CGFloat] = [0.3, 0.5, 0.7, 0.85, 0.95, 0.9, 0.8, 0.95, 0.85,
                                      1.0, 0.85, 0.95, 0.8, 0.9, 0.95, 0.85, 0.7, 0.5, 0.3]
            for i in 0..<min(barCount, pattern.count) {
                barHeights[i] = pattern[i]
            }
        }
    }
}

private struct WaveformBar: View {
    let height: CGFloat
    let maxHeight: CGFloat
    let minHeight: CGFloat
    let width: CGFloat
    let isAnimating: Bool

    private var actualHeight: CGFloat {
        minHeight + (maxHeight - minHeight) * height
    }

    var body: some View {
        RoundedRectangle(cornerRadius: width / 2)
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
            .frame(width: width, height: actualHeight)
            .shadow(
                color: Theme.Colors.accentPurple.opacity(isAnimating ? 0.4 : 0.2),
                radius: isAnimating ? 4 : 2,
                x: 0,
                y: 0
            )
    }
}

#Preview("Animating") {
    VStack(spacing: 40) {
        Text("RECORDING")
            .font(Theme.Typography.badge)
            .foregroundStyle(Theme.Colors.textSecondary)
            .tracking(1)

        WaveformView(isAnimating: true)
    }
    .padding()
    .background(Theme.Colors.bgDeep)
}

#Preview("Frozen (Processing)") {
    VStack(spacing: 40) {
        Text("PROCESSING")
            .font(Theme.Typography.badge)
            .foregroundStyle(Theme.Colors.textSecondary)
            .tracking(1)

        WaveformView(isAnimating: false)
    }
    .padding()
    .background(Theme.Colors.bgDeep)
}

#Preview("State Comparison") {
    VStack(spacing: 60) {
        VStack(spacing: 20) {
            Text("RECORDING")
                .font(Theme.Typography.badge)
                .foregroundStyle(Theme.Colors.accentPurple)
                .tracking(1)
            WaveformView(isAnimating: true)
        }

        Divider()
            .background(Theme.Colors.borderSubtle)

        VStack(spacing: 20) {
            Text("PROCESSING")
                .font(Theme.Typography.badge)
                .foregroundStyle(Theme.Colors.textSecondary)
                .tracking(1)
            WaveformView(isAnimating: false)
        }
    }
    .padding(40)
    .background(Theme.Colors.bgDeep)
}
