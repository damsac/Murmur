import SwiftUI

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String?
    let showChevron: Bool
    let action: (() -> Void)?

    init(
        icon: String,
        iconColor: Color = Theme.Colors.accentPurple,
        label: String,
        value: String? = nil,
        showChevron: Bool = true,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.label = label
        self.value = value
        self.showChevron = showChevron
        self.action = action
    }

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                // Label
                Text(label)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Value (if provided)
                if let value {
                    Text(value)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                // Chevron
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.Colors.bgCard)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// Toggle variant
struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    @Binding var isOn: Bool

    init(
        icon: String,
        iconColor: Color = Theme.Colors.accentPurple,
        label: String,
        isOn: Binding<Bool>
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.label = label
        self._isOn = isOn
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            // Label
            Text(label)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Toggle
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.Colors.accentPurple)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.Colors.bgCard)
        )
    }
}

#Preview("Settings Rows") {
    ScrollView {
        VStack(spacing: 16) {
            SettingsRow(
                icon: "person.circle",
                iconColor: Theme.Colors.accentBlue,
                label: "Account",
                value: nil,
                showChevron: true,
                action: { print("Account tapped") }
            )

            SettingsRow(
                icon: "bell",
                iconColor: Theme.Colors.accentYellow,
                label: "Notifications",
                value: "Enabled",
                showChevron: true,
                action: { print("Notifications tapped") }
            )

            SettingsRow(
                icon: "paintbrush",
                iconColor: Theme.Colors.accentPurple,
                label: "Appearance",
                value: "Dark",
                showChevron: true,
                action: { print("Appearance tapped") }
            )

            SettingsRow(
                icon: "creditcard",
                iconColor: Theme.Colors.accentGreen,
                label: "Top Up Credits",
                value: nil,
                showChevron: true,
                action: { print("Top up tapped") }
            )

            SettingsRow(
                icon: "info.circle",
                iconColor: Theme.Colors.textSecondary,
                label: "About",
                value: "v1.0.0",
                showChevron: true,
                action: { print("About tapped") }
            )

            Divider()
                .padding(.vertical, 8)

            SettingsToggleRow(
                icon: "moon",
                iconColor: Theme.Colors.accentPurple,
                label: "Auto-categorize entries",
                isOn: .constant(true)
            )

            SettingsToggleRow(
                icon: "waveform",
                iconColor: Theme.Colors.accentBlue,
                label: "Haptic feedback",
                isOn: .constant(false)
            )
        }
        .padding(Theme.Spacing.screenPadding)
    }
    .background(Theme.Colors.bgDeep)
}
