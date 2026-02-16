import SwiftUI

struct TopUpView: View {
    @Environment(AppState.self) private var appState
    let onBack: () -> Void
    let onPurchase: (TokenPack) -> Void

    @State private var selectedTab: TopUpTab = .card

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Theme.Colors.bgDeep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav header
                NavHeader(
                    title: "Top Up",
                    showBackButton: true,
                    backAction: onBack,
                    trailingButtons: []
                )

                // Balance display
                VStack(spacing: 6) {
                    Text(appState.creditBalance.formatted())
                        .font(.system(size: 40, weight: .bold))
                        .tracking(-0.8)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text("tokens remaining")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .padding(.top, 28)
                .padding(.bottom, 24)

                // Tab bar
                HStack(spacing: 3) {
                    ForEach(TopUpTab.allCases, id: \.self) { tab in
                        TopUpTabButton(
                            title: tab.rawValue,
                            isSelected: selectedTab == tab,
                            action: { selectedTab = tab }
                        )
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .padding(.bottom, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.071, green: 0.071, blue: 0.102)) // #12121A
                        .padding(.horizontal, Theme.Spacing.screenPadding)
                        .padding(.vertical, 3)
                )

                // Tab content
                ScrollView {
                    VStack(spacing: 0) {
                        switch selectedTab {
                        case .card:
                            CardTabContent(onPurchase: onPurchase)
                        case .cashu:
                            CashuTabContent()
                        case .subscribe:
                            SubscribeTabContent()
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.screenPadding)
                    .padding(.bottom, 80) // Space for disclaimer
                }
            }

            // Disclaimer at bottom
            VStack {
                Spacer()
                Text("Credits are non-refundable")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.227, green: 0.227, blue: 0.282)) // #3A3A48
                    .padding(.bottom, 42)
            }
        }
    }
}

// MARK: - Top Up Tab

enum TopUpTab: String, CaseIterable {
    case card = "Card"
    case cashu = "Cashu"
    case subscribe = "Subscribe"
}

// MARK: - Tab Button

private struct TopUpTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? .white : Theme.Colors.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Theme.Colors.accentPurple : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card Tab Content

private struct CardTabContent: View {
    let onPurchase: (TokenPack) -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Pack 1: 10,000 tokens
            PackCard(
                pack: TokenPack(tokens: 10_000, price: "$0.99", isPopular: false, isBestValue: false),
                onPurchase: onPurchase
            )

            // Pack 2: 50,000 tokens (Popular)
            PackCard(
                pack: TokenPack(tokens: 50_000, price: "$3.99", isPopular: true, isBestValue: false),
                onPurchase: onPurchase
            )

            // Pack 3: 100,000 tokens (Best Value)
            PackCard(
                pack: TokenPack(tokens: 100_000, price: "$6.99", isPopular: false, isBestValue: true),
                onPurchase: onPurchase
            )
        }
    }
}

// MARK: - Pack Card

private struct PackCard: View {
    let pack: TokenPack
    let onPurchase: (TokenPack) -> Void

    var body: some View {
        Button(action: { onPurchase(pack) }) {
            HStack(spacing: 0) {
                // Left side
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(pack.tokens.formatted()) tokens")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)

                    if pack.isBestValue {
                        Text("Best value")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.Colors.accentGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Theme.Colors.accentGreen.opacity(0.12))
                            )
                    }
                }

                Spacer()

                // Right side
                HStack(spacing: 12) {
                    Text(pack.price)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)

                    // Apple Pay button
                    Text("Pay")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(-0.2)
                        .foregroundStyle(.black)
                        .frame(width: 40, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.Colors.textPrimary)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.Colors.bgCard)

                    if pack.isPopular {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.Colors.accentPurple, lineWidth: 1)
                    }
                }
            )
            .overlay(alignment: .topTrailing) {
                if pack.isPopular {
                    Text("Popular")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Theme.Colors.accentPurple)
                        )
                        .offset(y: -9)
                        .padding(.trailing, 16)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cashu Tab Content

private struct CashuTabContent: View {
    @State private var cashuToken: String = ""

    var body: some View {
        VStack(spacing: 12) {
            // Paste input
            HStack(spacing: 12) {
                TextField("Paste cashu token...", text: $cashuToken)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .padding(.leading, 4)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.Colors.bgCard)
            )

            // Scan QR button
            Button(action: { print("Scan QR") }) {
                HStack(spacing: 8) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 20, weight: .medium))

                    Text("Scan QR Code")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(Theme.Colors.accentPurpleLight)
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.Colors.accentPurple.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.Colors.accentPurple.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Subscribe Tab Content

private struct SubscribeTabContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Murmur Pro")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.bottom, 4)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$4.99")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.Colors.accentPurple)

                Text("/ month")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(.bottom, 12)

            // Features
            FeatureRow(text: "100,000 tokens per month")
            FeatureRow(text: "Priority processing")
            FeatureRow(text: "Auto-renew, cancel anytime")
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.Colors.bgCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.Colors.accentPurple.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

private struct FeatureRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Colors.accentGreen)

            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Token Pack Model

struct TokenPack: Identifiable {
    let id = UUID()
    let tokens: Int
    let price: String
    let isPopular: Bool
    let isBestValue: Bool
}

#Preview("Top Up") {
    @Previewable @State var appState = AppState()

    TopUpView(
        onBack: { print("Back") },
        onPurchase: { print("Purchase:", $0.tokens) }
    )
    .environment(appState)
}
