import SwiftUI

struct CaptureBar: View {
    let isRecording: Bool
    var showMicButton: Bool = true
    let onMicTap: () -> Void
    let onKeyboardTap: () -> Void

    private var keyboardButton: some View {
        Button(action: onKeyboardTap) {
            Image(systemName: "keyboard")
                .font(.title3.weight(.medium))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Theme.Colors.bgCard)
                        .overlay(
                            Circle()
                                .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Type a note")
    }

    var body: some View {
        ZStack {
            if showMicButton {
                // Mic centered on screen
                MicButton(
                    size: .large,
                    isRecording: isRecording,
                    action: onMicTap
                )
                .accessibilityLabel("Record voice note")

                // Keyboard to the right of mic
                HStack {
                    Spacer()
                        .frame(width: 52) // half of mic (64pt) + spacing
                    keyboardButton
                }
            } else {
                keyboardButton
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, showMicButton ? 20 : 12)
    }
}

#Preview("Idle") {
    VStack {
        Spacer()
        CaptureBar(
            isRecording: false,
            onMicTap: { print("Mic") },
            onKeyboardTap: { print("Keyboard") }
        )
    }
    .background(Theme.Colors.bgDeep)
}

#Preview("Recording") {
    VStack {
        Spacer()
        CaptureBar(
            isRecording: true,
            onMicTap: { print("Mic") },
            onKeyboardTap: { print("Keyboard") }
        )
    }
    .background(Theme.Colors.bgDeep)
}
