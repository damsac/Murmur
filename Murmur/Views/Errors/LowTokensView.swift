import SwiftUI

struct LowTokensView: View {
    @Environment(AppState.self) private var appState
    let balance: Int
    let estimatedRecordingsLeft: Int
    let onTopUp: () -> Void

    var body: some View {
        Button(action: onTopUp) {
            HStack(spacing: 12) {
                // Warning icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.Colors.accentYellow.opacity(0.1))
                        .frame(width: 36, height: 36)

                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.Colors.accentYellow)
                }

                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text("Low on tokens")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.accentYellow)

                    Text("~\(estimatedRecordingsLeft) recordings left. Tap to top up.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                Spacer()

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.Colors.accentYellow.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Theme.Colors.accentYellow.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Low Tokens") {
    @Previewable @State var appState = AppState()

    VStack {
        LowTokensView(
            balance: 312,
            estimatedRecordingsLeft: 3,
            onTopUp: { print("Top up") }
        )
        .padding(.horizontal, Theme.Spacing.screenPadding)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.Colors.bgDeep)
    .environment(appState)
}
