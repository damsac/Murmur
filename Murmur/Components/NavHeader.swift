import SwiftUI

struct NavHeader: View {
    let title: String
    let showBackButton: Bool
    let backAction: (() -> Void)?
    let trailingButtons: [NavButton]

    struct NavButton: Identifiable {
        let id = UUID()
        let icon: String
        let action: () -> Void
    }

    init(
        title: String,
        showBackButton: Bool = false,
        backAction: (() -> Void)? = nil,
        trailingButtons: [NavButton] = []
    ) {
        self.title = title
        self.showBackButton = showBackButton
        self.backAction = backAction
        self.trailingButtons = trailingButtons
    }

    var body: some View {
        HStack(spacing: 12) {
            // Leading: Back button or spacer
            if showBackButton {
                Button(action: { backAction?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.Colors.accentPurple)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Spacer()
                    .frame(width: 44)
            }

            // Center: Title
            Text(title)
                .font(Theme.Typography.navTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity)

            // Trailing: Action buttons
            HStack(spacing: 8) {
                ForEach(trailingButtons) { button in
                    Button(action: button.action) {
                        Image(systemName: button.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Theme.Colors.accentPurple)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 44 * CGFloat(max(1, trailingButtons.count)))
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Theme.Colors.bgDeep.opacity(0.95))
    }
}

#Preview("With Back Button") {
    VStack(spacing: 0) {
        NavHeader(
            title: "Entry Details",
            showBackButton: true,
            backAction: { print("Back tapped") },
            trailingButtons: [
                NavHeader.NavButton(icon: "ellipsis", action: { print("More tapped") })
            ]
        )
        Spacer()
    }
    .background(Theme.Colors.bgDeep)
}

#Preview("Simple Title") {
    VStack(spacing: 0) {
        NavHeader(
            title: "Settings"
        )
        Spacer()
    }
    .background(Theme.Colors.bgDeep)
}

#Preview("With Multiple Actions") {
    VStack(spacing: 0) {
        NavHeader(
            title: "Todo View",
            showBackButton: true,
            backAction: { print("Back") },
            trailingButtons: [
                NavHeader.NavButton(icon: "plus", action: { print("Add") }),
                NavHeader.NavButton(icon: "slider.horizontal.3", action: { print("Filter") })
            ]
        )
        Spacer()
    }
    .background(Theme.Colors.bgDeep)
}
