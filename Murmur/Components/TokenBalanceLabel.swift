import SwiftUI

struct TokenBalanceLabel: View {
    let balance: Int
    let showWarning: Bool

    private var displayColor: Color {
        if balance == 0 {
            return Theme.Colors.accentRed
        } else if showWarning {
            return Theme.Colors.accentYellow
        } else {
            return Theme.Colors.textSecondary
        }
    }

    private var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: balance)) ?? "\(balance)"
    }

    var body: some View {
        HStack(spacing: 6) {
            // Token icon
            Circle()
                .fill(displayColor.opacity(0.2))
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .stroke(displayColor, lineWidth: 2)
                )

            // Balance text with tabular numbers
            Text(formattedBalance)
                .font(Theme.Typography.label)
                .foregroundStyle(displayColor)
                .monospacedDigit() // Ensures tabular number spacing
                .fontWeight(.semibold)

            Text("tokens")
                .font(Theme.Typography.label)
                .foregroundStyle(displayColor.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(displayColor.opacity(0.08))
                .overlay(
                    Capsule()
                        .stroke(displayColor.opacity(0.2), lineWidth: 1)
                )
        )
        .animation(.easeOut(duration: 0.2), value: balance)
        .animation(.easeOut(duration: 0.2), value: showWarning)
    }
}

#Preview("Normal Balance") {
    VStack(spacing: 20) {
        TokenBalanceLabel(balance: 1247, showWarning: false)
        TokenBalanceLabel(balance: 847, showWarning: false)
        TokenBalanceLabel(balance: 42, showWarning: false)
    }
    .padding()
    .background(Theme.Colors.bgDeep)
}

#Preview("Warning States") {
    VStack(spacing: 20) {
        TokenBalanceLabel(balance: 150, showWarning: true)
        TokenBalanceLabel(balance: 23, showWarning: true)
        TokenBalanceLabel(balance: 0, showWarning: true)
    }
    .padding()
    .background(Theme.Colors.bgDeep)
}
