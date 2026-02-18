import SwiftUI

struct TextInputView: View {
    @Binding var text: String
    let onSubmit: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Button {
                    text = ""
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(Theme.Typography.bodyMedium)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("New thought")
                    .font(Theme.Typography.body.weight(.medium))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Spacer()

                Button(action: submitAndDismiss) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(
                            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Theme.Colors.textTertiary
                                : Theme.Colors.accentPurple
                        )
                }
                .buttonStyle(.plain)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .overlay(Theme.Colors.borderSubtle)

            // Text editor
            TextEditor(text: $text)
                .focused($isFocused)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            Spacer()
        }
        .background(Theme.Colors.bgDeep)
        .onAppear {
            isFocused = true
        }
    }

    private func submitAndDismiss() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onSubmit()
        dismiss()
    }
}

#Preview("Empty") {
    TextInputView(
        text: .constant(""),
        onSubmit: { print("Submit") }
    )
}

#Preview("With Text") {
    TextInputView(
        text: .constant("Pick up groceries on the way home"),
        onSubmit: { print("Submit") }
    )
}
