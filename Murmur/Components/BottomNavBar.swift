import SwiftUI

struct BottomNavBar: View {
    var isRecording: Bool = false
    var isProcessing: Bool = false
    var showTextInput: Bool = false
    @Binding var inputText: String
    var onMicTap: (() -> Void)?
    var onKeyboardTap: (() -> Void)?
    var onTextSubmit: (() -> Void)?
    var onDismissTextInput: (() -> Void)?

    @FocusState private var isTextFieldFocused: Bool
    @Namespace private var navBarNamespace

    private let micSize = Theme.Spacing.micButtonSize
    private let kbSize: CGFloat = 40

    var body: some View {
        ZStack {
            if showTextInput {
                textInputMode
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.9, anchor: .trailing)),
                        removal: .opacity.combined(with: .scale(scale: 0.9, anchor: .trailing))
                    ))
            } else {
                normalMode
                    .transition(.opacity)
            }
        }
        .frame(height: micSize)
        .padding(.bottom, 0)
        .animation(Animations.smoothSlide, value: showTextInput)
        .animation(Animations.smoothSlide, value: isRecording)
    }

    // MARK: - Normal Mode (Idle / Recording)

    @ViewBuilder
    private var normalMode: some View {
        ZStack {
            // Mic button — centered, staggered higher
            MicButton(
                size: .large,
                isRecording: isRecording,
                isProcessing: isProcessing,
                showStop: isRecording && !isProcessing,
                action: { onMicTap?() }
            )
            .offset(y: -12)
            .accessibilityLabel(isRecording ? "Stop recording" : "Record voice note")

            // Keyboard button — to the right of mic, lower
            if !isRecording && !isProcessing, let onKeyboardTap {
                Button(action: onKeyboardTap) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: kbSize, height: kbSize)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Type a note")
                .offset(x: micSize / 2 + kbSize / 2 + 6)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Text Input Mode

    @ViewBuilder
    private var textInputMode: some View {
        HStack(spacing: 10) {
            // Dismiss button
            Button {
                onDismissTextInput?()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            // Text field pill
            HStack(spacing: 8) {
                TextField("Type something...", text: $inputText, axis: .vertical)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1...3)
                    .focused($isTextFieldFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onTextSubmit?()
                        }
                    }
                    .tint(Theme.Colors.accentPurple)

                if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            inputText = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Theme.Colors.bgCard)
                    .overlay(
                        Capsule()
                            .stroke(
                                isTextFieldFocused
                                    ? Theme.Colors.accentPurple.opacity(0.4)
                                    : Theme.Colors.borderSubtle,
                                lineWidth: 1
                            )
                    )
            )

            // Send / mic button on the right
            if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    onTextSubmit?()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Theme.Colors.accentPurple)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send")
                .transition(.scale.combined(with: .opacity))
            } else {
                MicButton(
                    size: .small,
                    isRecording: false,
                    action: {
                        onDismissTextInput?()
                        onMicTap?()
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, Theme.Spacing.screenPadding)
        .animation(.easeInOut(duration: 0.15), value: inputText.isEmpty)
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

// MARK: - Notched Tab Bar Shape

struct NotchedTabBarShape: Shape {
    let notchRadius: CGFloat
    let notchDepth: CGFloat
    let curveOffset: CGFloat // unused — kept for API compat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let midX = rect.midX

        let alpha = asin(notchDepth / notchRadius)
        let halfGap = sqrt(notchRadius * notchRadius - notchDepth * notchDepth)
        let startAngle = Angle.radians(.pi + alpha)
        let endAngle = Angle.radians(2 * .pi - alpha)

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: midX - halfGap, y: rect.minY))

        path.addArc(
            center: CGPoint(x: midX, y: notchDepth),
            radius: notchRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

// MARK: - Previews

#Preview("Nav Bar - Idle") {
    @Previewable @State var text = ""
    VStack {
        Spacer()
        BottomNavBar(
            isRecording: false,
            inputText: $text,
            onMicTap: { print("Mic") },
            onKeyboardTap: { print("Keyboard") }
        )
    }
    .background(Theme.Colors.bgDeep)
}

#Preview("Nav Bar - Recording") {
    @Previewable @State var text = ""
    VStack {
        Spacer()
        BottomNavBar(
            isRecording: true,
            inputText: $text,
            onMicTap: { print("Stop") }
        )
    }
    .background(Theme.Colors.bgDeep)
}

#Preview("Nav Bar - Text Input") {
    @Previewable @State var text = "Hello world"
    VStack {
        Spacer()
        BottomNavBar(
            showTextInput: true,
            inputText: $text,
            onTextSubmit: { print("Submit:", text) },
            onDismissTextInput: { print("Dismiss") }
        )
    }
    .background(Theme.Colors.bgDeep)
}
