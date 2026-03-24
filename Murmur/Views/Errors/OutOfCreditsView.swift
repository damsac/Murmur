import SwiftUI

struct OutOfCreditsView: View {
    let onTopUp: () -> Void

    var body: some View {
        ZStack {
            Theme.Colors.bgDeep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(Theme.Colors.accentRed.opacity(0.8))

                    Text("Out of tokens")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text("Top up to keep capturing your thoughts.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button(action: onTopUp) {
                    Text("Top up tokens")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.Colors.accentPurple, Theme.Colors.accentPurpleLight],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .padding(.bottom, 48)
            }
        }
    }
}

#Preview("Out of Credits") {
    @Previewable @State var appState = AppState()

    OutOfCreditsView(
        onTopUp: { print("Top up") }
    )
    .environment(appState)
}
