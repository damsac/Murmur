import SwiftUI

struct DeleteConfirmDialog: View {
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            // Dark overlay background
            Rectangle()
                .fill(Theme.Colors.bgDeep.opacity(0.7))
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }

            // Dialog
            VStack(spacing: 0) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Theme.Colors.accentRed.opacity(0.08))
                        .frame(width: 56, height: 56)

                    Image(systemName: "trash")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Theme.Colors.accentRed)
                }
                .padding(.bottom, 20)

                // Title
                Text("Delete entry?")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.bottom, 8)

                // Subtitle
                Text("This can't be undone. The entry and its transcript will be permanently removed.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 28)

                // Actions
                VStack(spacing: 10) {
                    // Delete button
                    Button(action: onDelete) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .medium))

                            Text("Delete")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Theme.Colors.accentRed)
                        )
                    }
                    .buttonStyle(.plain)

                    // Cancel button
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Theme.Colors.textPrimary.opacity(0.04))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 32)
            .padding(.bottom, 24)
            .frame(maxWidth: 320)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Theme.Colors.bgCard)

                    // Top gradient line
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Theme.Colors.accentRed.opacity(0.2),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            )
            .shadow(color: .black.opacity(0.5), radius: 30, y: 20)
        }
    }
}

#Preview("Delete Confirm Dialog") {
    @Previewable @State var appState = AppState()

    DeleteConfirmDialog(
        onDelete: { print("Delete") },
        onCancel: { print("Cancel") }
    )
    .environment(appState)
}
