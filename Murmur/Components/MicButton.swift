import SwiftUI

struct MicButton: View {
    let size: MicButtonSize
    let isRecording: Bool
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
            case .small: return 24
            case .large: return 30
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
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.Colors.accentPurple,
                            Theme.Colors.accentPurpleLight
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size.diameter, height: size.diameter)
                .shadow(
                    color: Theme.Colors.accentPurple.opacity(isPressed ? 0.6 : 0.4),
                    radius: size.shadowRadius,
                    x: 0,
                    y: isPressed ? 2 : 4
                )
                .shadow(
                    color: Theme.Colors.accentPurple.opacity(0.2),
                    radius: size.shadowRadius * 1.5,
                    x: 0,
                    y: 0
                )
                .overlay {
                    Image(systemName: "mic.fill")
                        .font(.system(size: size.iconSize, weight: .medium))
                        .foregroundStyle(.white)
                }
                .overlay(alignment: .topTrailing) {
                    if isRecording {
                        Circle()
                            .fill(Theme.Colors.accentRed)
                            .frame(width: 10, height: 10)
                            .offset(x: 2, y: -2)
                            .modifier(PulsingDot())
                    }
                }
                .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(MicButtonStyle(isPressed: $isPressed))
        .accessibilityLabel(isRecording ? "Stop recording" : "Record voice note")
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
