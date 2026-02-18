import SwiftUI

struct SettingsMinimalView: View {
    let onBack: () -> Void
    let onTopUp: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Theme.Colors.bgDeep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav header
                NavHeader(
                    title: "Settings",
                    showBackButton: true,
                    backAction: onBack,
                    trailingButtons: []
                )

                ScrollView {
                    VStack(spacing: 28) {
                        // SECURITY Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("SECURITY")
                                .font(Theme.Typography.badge)
                                .tracking(1)
                                .foregroundStyle(Theme.Colors.textTertiary)
                                .padding(.horizontal, Theme.Spacing.screenPadding)

                            VStack(spacing: 0) {
                                SettingsInfoRow(
                                    icon: "lock.fill",
                                    iconColor: Theme.Colors.accentGreen,
                                    label: "Encryption",
                                    value: "Active (AES-256)",
                                    valueColor: Theme.Colors.accentGreen
                                )

                                Divider()
                                    .background(Theme.Colors.textPrimary.opacity(0.04))

                                SettingsInfoRow(
                                    icon: "key.fill",
                                    iconColor: Theme.Colors.accentGreen,
                                    label: "Key Status",
                                    value: "Secure Enclave",
                                    valueColor: Theme.Colors.textSecondary
                                )

                                Divider()
                                    .background(Theme.Colors.textPrimary.opacity(0.04))

                                SettingsInfoRow(
                                    icon: "shield.fill",
                                    iconColor: Theme.Colors.accentGreen,
                                    label: "Entries Encrypted",
                                    value: "47",
                                    valueColor: Theme.Colors.textSecondary
                                )
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Theme.Colors.bgCard)
                            )
                            .padding(.horizontal, Theme.Spacing.screenPadding)
                        }

                        // CREDITS Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("CREDITS")
                                .font(Theme.Typography.badge)
                                .tracking(1)
                                .foregroundStyle(Theme.Colors.textTertiary)
                                .padding(.horizontal, Theme.Spacing.screenPadding)

                            VStack(spacing: 0) {
                                SettingsInfoRow(
                                    icon: "bolt.fill",
                                    iconColor: Theme.Colors.accentPurple,
                                    label: "Balance",
                                    value: "4,312 tokens",
                                    valueColor: Theme.Colors.textPrimary,
                                    boldValue: true
                                )

                                Divider()
                                    .background(Theme.Colors.textPrimary.opacity(0.04))

                                SettingsRow(
                                    icon: "arrow.up.circle.fill",
                                    iconColor: Theme.Colors.accentPurple,
                                    label: "Top Up",
                                    showChevron: true,
                                    action: onTopUp
                                )
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Theme.Colors.bgCard)
                            )
                            .padding(.horizontal, Theme.Spacing.screenPadding)
                        }

                        // PROCESSING Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("PROCESSING")
                                .font(Theme.Typography.badge)
                                .tracking(1)
                                .foregroundStyle(Theme.Colors.textTertiary)
                                .padding(.horizontal, Theme.Spacing.screenPadding)

                            VStack(spacing: 0) {
                                SettingsInfoRow(
                                    icon: "cpu",
                                    iconColor: Theme.Colors.accentBlue,
                                    label: "AI Model",
                                    value: "Claude Haiku",
                                    valueColor: Theme.Colors.textSecondary,
                                    badge: "TEE"
                                )

                                Divider()
                                    .background(Theme.Colors.textPrimary.opacity(0.04))

                                SettingsInfoRow(
                                    icon: "cloud.fill",
                                    iconColor: Theme.Colors.accentBlue,
                                    label: "Mode",
                                    value: "Cloud (default)",
                                    valueColor: Theme.Colors.textSecondary
                                )
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Theme.Colors.bgCard)
                            )
                            .padding(.horizontal, Theme.Spacing.screenPadding)
                        }
                    }
                    .padding(.top, 24)
                }
            }
        }
    }
}

// Info row variant without navigation (just displays info)
private struct SettingsInfoRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let valueColor: Color
    let boldValue: Bool
    let badge: String?

    init(
        icon: String,
        iconColor: Color,
        label: String,
        value: String,
        valueColor: Color,
        boldValue: Bool = false,
        badge: String? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.label = label
        self.value = value
        self.valueColor = valueColor
        self.boldValue = boldValue
        self.badge = badge
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundStyle(iconColor)
            }

            // Label
            Text(label)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Value
            HStack(spacing: 6) {
                Text(value)
                    .font(boldValue ? Theme.Typography.bodyMedium : Theme.Typography.body)
                    .foregroundStyle(valueColor)

                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.Colors.accentGreen)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Theme.Colors.accentGreen.opacity(0.15))
                        )
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

#Preview("Settings Minimal") {
    SettingsMinimalView(
        onBack: { print("Back") },
        onTopUp: { print("Top up") }
    )
}
