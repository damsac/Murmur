import SwiftUI

struct InputBar: View {
    @Binding var text: String
    let placeholder: String
    let isRecording: Bool
    var showMicButton: Bool = true
    let onMicTap: () -> Void
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Text input field
            HStack(spacing: 12) {
                TextField(placeholder, text: $text, axis: .vertical)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1...4)
                    .focused($isFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        if !text.isEmpty {
                            onSubmit()
                        }
                    }
                    .tint(Theme.Colors.accentPurple)

                // Clear button (only when text is not empty)
                if !text.isEmpty {
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            text = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Theme.Colors.bgCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                isFocused
                                    ? Theme.Colors.accentPurple.opacity(0.4)
                                    : Theme.Colors.borderSubtle,
                                lineWidth: 1
                            )
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)

            // Mic button (hidden when floating mic is shown)
            if showMicButton {
                MicButton(
                    size: .small,
                    isRecording: isRecording,
                    action: onMicTap
                )
            }
        }
        .padding(.horizontal, Theme.Spacing.screenPadding)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Theme.Colors.bgDeep.opacity(0.95))
                .overlay(
                    Rectangle()
                        .fill(Theme.Colors.borderSubtle)
                        .frame(height: 1),
                    alignment: .top
                )
        )
        .background(.ultraThinMaterial.opacity(0.3))
    }
}

#Preview("Empty") {
    VStack {
        Spacer()
        InputBar(
            text: .constant(""),
            placeholder: "Type or speak...",
            isRecording: false,
            onMicTap: { print("Mic tapped") },
            onSubmit: { print("Submit") }
        )
    }
    .background(Theme.Colors.bgDeep)
    .ignoresSafeArea()
}

#Preview("With Text") {
    VStack {
        Spacer()
        InputBar(
            text: .constant("This is a sample message that I'm typing"),
            placeholder: "Type or speak...",
            isRecording: false,
            onMicTap: { print("Mic tapped") },
            onSubmit: { print("Submit") }
        )
    }
    .background(Theme.Colors.bgDeep)
    .ignoresSafeArea()
}

#Preview("Recording") {
    VStack {
        Spacer()
        InputBar(
            text: .constant(""),
            placeholder: "Type or speak...",
            isRecording: true,
            onMicTap: { print("Mic tapped") },
            onSubmit: { print("Submit") }
        )
    }
    .background(Theme.Colors.bgDeep)
    .ignoresSafeArea()
}

#Preview("Multiline Text") {
    VStack {
        Spacer()
        InputBar(
            text: .constant("This is a much longer message that spans multiple lines to test the text field expansion behavior"),
            placeholder: "Type or speak...",
            isRecording: false,
            onMicTap: { print("Mic tapped") },
            onSubmit: { print("Submit") }
        )
    }
    .background(Theme.Colors.bgDeep)
    .ignoresSafeArea()
}
