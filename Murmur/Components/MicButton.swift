import SwiftUI

struct MicButton: View {
    let size: MicButtonSize
    let isRecording: Bool
    var isProcessing: Bool = false
    var showStop: Bool = false
    let action: () -> Void

    enum MicButtonSize {
        case small // 52pt - for input bar
        case large // 64pt - floating button

        var diameter: CGFloat {
            switch self {
            case .small: return 52
            case .large: return 72
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .small: return 28
            case .large: return 40
            }
        }

        var shadowRadius: CGFloat {
            switch self {
            case .small: return 16
            case .large: return 24
            }
        }

    }

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Group {
                if isProcessing {
                    MiniWaveformView(barCount: 9)
                        .frame(width: size.diameter, height: size.diameter * 0.5)
                        .transition(.opacity)
                } else {
                    Image(systemName: showStop ? "stop.fill" : "mic.fill")
                        .font(.system(size: size.iconSize, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Theme.Colors.accentPurple,
                                    Theme.Colors.accentPurpleLight
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(
                            color: Theme.Colors.accentPurple.opacity(0.4),
                            radius: size.shadowRadius * 0.5
                        )
                        .contentTransition(.symbolEffect(.replace))
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                        .transition(.opacity)
                }
            }
            .frame(width: size.diameter, height: size.diameter)
            .animation(.easeInOut(duration: 0.25), value: isProcessing)
        }
        .buttonStyle(MicButtonStyle(isPressed: $isPressed))
        .disabled(isProcessing)
        .accessibilityLabel(isProcessing ? "Processing" : isRecording ? "Stop recording" : "Record voice note")
    }
}

// Button style for press feedback
private struct MicButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = newValue
                }
            }
    }
}

// Compact waveform for processing state inside the mic button
private struct MiniWaveformView: View {
    let barCount: Int
    @State private var barHeights: [CGFloat] = []

    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 3

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
                    .frame(width: barWidth)
                    .frame(height: barHeights.indices.contains(index) ? barHeights[index] : 4)
                    .animation(
                        .easeInOut(duration: Double.random(in: 0.5...0.8))
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.07),
                        value: barHeights
                    )
            }
        }
        .onAppear {
            // Start with small bars, then animate to varied heights
            barHeights = Array(repeating: CGFloat(4), count: barCount)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                var heights: [CGFloat] = []
                for i in 0..<barCount {
                    let centerDistance = abs(CGFloat(i) - CGFloat(barCount) / 2)
                    let factor = 1.0 - (centerDistance / CGFloat(barCount) * 0.5)
                    heights.append(CGFloat.random(in: 8...22) * factor)
                }
                barHeights = heights
            }
        }
    }
}

// Pulsing animation for recording indicator
private struct PulsingDot: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
    }
}

#Preview("Sizes") {
    VStack(spacing: 40) {
        MicButton(size: .small, isRecording: false) {
            print("Small mic tapped")
        }

        MicButton(size: .large, isRecording: false) {
            print("Large mic tapped")
        }
    }
    .padding()
    .background(Theme.Colors.bgDeep)
}

#Preview("Recording States") {
    VStack(spacing: 40) {
        VStack(spacing: 16) {
            Text("IDLE")
                .font(Theme.Typography.badge)
                .foregroundStyle(Theme.Colors.textSecondary)
            MicButton(size: .large, isRecording: false) {}
        }

        VStack(spacing: 16) {
            Text("RECORDING")
                .font(Theme.Typography.badge)
                .foregroundStyle(Theme.Colors.accentRed)
            MicButton(size: .large, isRecording: true) {}
        }
    }
    .padding()
    .background(Theme.Colors.bgDeep)
}
