import SwiftUI

struct TopUpView: View {
    @Environment(AppState.self) private var appState
    let packs: [CreditPack]
    let isLoading: Bool
    let onBack: () -> Void
    let onPurchase: (CreditPack) -> Void

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

                    Text("credits remaining")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .padding(.top, 28)
                .padding(.bottom, 24)

                ScrollView {
                    VStack(spacing: 0) {
                        CardTabContent(
                            packs: packs,
                            isLoading: isLoading,
                            onPurchase: onPurchase
                        )
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

// MARK: - Card Tab Content

private struct CardTabContent: View {
    let packs: [CreditPack]
    let isLoading: Bool
    let onPurchase: (CreditPack) -> Void

    var body: some View {
        VStack(spacing: 12) {
            if isLoading && packs.isEmpty {
                ProgressView("Loading purchases...")
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .padding(.top, 24)
            } else if packs.isEmpty {
                Text("No credit packs available. Verify StoreKit product configuration.")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .padding(.top, 24)
            } else {
                ForEach(packs) { pack in
                    PackCard(pack: pack, onPurchase: onPurchase)
                }
            }
        }
    }
}

// MARK: - Pack Card

private struct PackCard: View {
    let pack: CreditPack
    let onPurchase: (CreditPack) -> Void

    var body: some View {
        Button(action: { onPurchase(pack) }) {
            HStack(spacing: 0) {
                // Left side
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(pack.credits.formatted()) credits")
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

                    Text("Buy")
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

// MARK: - Credit Pack Model

struct CreditPack: Identifiable {
    let id = UUID()
    let credits: Int
    let price: String
    let isPopular: Bool
    let isBestValue: Bool
}

#Preview("Top Up") {
    @Previewable @State var appState = AppState()

    TopUpView(
        packs: [
            CreditPack(credits: 1_000, price: "$0.99", isPopular: false, isBestValue: false),
            CreditPack(credits: 5_000, price: "$3.99", isPopular: true, isBestValue: false),
            CreditPack(credits: 10_000, price: "$6.99", isPopular: false, isBestValue: true),
        ],
        isLoading: false,
        onBack: { print("Back") },
        onPurchase: { print("Purchase:", $0.credits) }
    )
    .environment(appState)
}
