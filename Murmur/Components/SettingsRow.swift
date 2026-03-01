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
                        .font(.headline.weight(.medium))
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
                        .font(.subheadline.weight(.semibold))
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

// Toggle variant — no background; wrap in a SettingsGroup for card styling
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
                    .font(.headline.weight(.medium))
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
    }
}

// Groups rows into a single card with dividers between them
struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        let subviews = Group { content }

        VStack(spacing: 0) {
            subviews
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.Colors.bgCard)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, Theme.Spacing.screenPadding)
    }
}

// Thin divider for use between rows inside a SettingsGroup
struct SettingsGroupDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Colors.borderSubtle)
            .frame(height: 1)
            .padding(.leading, 68) // align with text, past icon
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

            Divider()
                .padding(.vertical, 8)

            SettingsGroup {
                SettingsToggleRow(
                    icon: "moon",
                    iconColor: Theme.Colors.accentPurple,
                    label: "Auto-categorize entries",
                    isOn: .constant(true)
                )

                SettingsGroupDivider()

                SettingsToggleRow(
                    icon: "waveform",
                    iconColor: Theme.Colors.accentBlue,
                    label: "Haptic feedback",
                    isOn: .constant(false)
                )
            }
        }
        .padding(.vertical, Theme.Spacing.screenPadding)
    }
    .background(Theme.Colors.bgDeep)
}
