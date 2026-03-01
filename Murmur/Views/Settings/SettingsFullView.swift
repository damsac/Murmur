import SwiftUI

struct SettingsFullView: View {
    @Environment(AppState.self) private var appState
    @Environment(NotificationPreferences.self) private var notifPrefs
    let onBack: () -> Void
    let onTopUp: () -> Void

    @State private var showArchive = false

    var body: some View {
        if showArchive {
            ArchiveView(onBack: { showArchive = false })
        } else {
            settingsContent
        }
    }

    @ViewBuilder
    private var settingsContent: some View {
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

                // Settings content
                ScrollView {
                    VStack(spacing: 24) {
                        // Credits section: balance hero + top up CTA
                        creditsSection

                        // Notifications section
                        VStack(spacing: 12) {
                            SectionHeader(title: "NOTIFICATIONS")
                            notificationsGroup
                        }

                        // Archive link
                        VStack(spacing: 12) {
                            SectionHeader(title: "DATA")
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showArchive = true
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "archivebox.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(Theme.Colors.accentPurple)
                                        .frame(width: 32)

                                    Text("Archive")
                                        .font(Theme.Typography.body)
                                        .foregroundStyle(Theme.Colors.textPrimary)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.Colors.textTertiary)
                                }
                                .padding(.horizontal, Theme.Spacing.screenPadding)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius)
                                        .fill(Theme.Colors.bgCard)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius)
                                                .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                                        )
                                )
                                .contentShape(Rectangle())
                                .padding(.horizontal, Theme.Spacing.screenPadding)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Credits Section

    @ViewBuilder
    private var creditsSection: some View {
        VStack(spacing: 0) {
            // Balance hero
            VStack(spacing: 6) {
                Text(appState.creditBalance.formatted())
                    .font(.system(size: 40, weight: .bold))
                    .tracking(-0.8)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("credits remaining")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 28)
            .padding(.bottom, 20)

            // Top up button
            Button(action: onTopUp) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Get More Credits")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(Theme.Colors.accentPurple)
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(
                    Capsule()
                        .fill(Theme.Colors.accentPurple.opacity(0.12))
                )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Notifications Group

    @ViewBuilder
    private var notificationsGroup: some View {
        @Bindable var prefs = notifPrefs

        HStack(spacing: 12) {
            NotificationChip(
                icon: "bell.fill",
                label: "Reminders",
                isOn: $prefs.remindersEnabled
            )

            NotificationChip(
                icon: "clock.fill",
                label: "Due Soon",
                isOn: $prefs.dueSoonEnabled
            )

            NotificationChip(
                icon: "moon.zzz.fill",
                label: "Snooze",
                isOn: $prefs.snoozeWakeUpEnabled
            )
        }
        .padding(.horizontal, Theme.Spacing.screenPadding)
    }
}

// MARK: - Notification Chip

private struct NotificationChip: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isOn.toggle()
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isOn ? Theme.Colors.accentPurple.opacity(0.15) : Theme.Colors.bgCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isOn ? Theme.Colors.accentPurple.opacity(0.3) : Theme.Colors.borderSubtle, lineWidth: 1)
                        )
                        .frame(height: 52)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isOn ? Theme.Colors.accentPurple : Theme.Colors.textTertiary)
                }

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isOn ? Theme.Colors.textSecondary : Theme.Colors.textTertiary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(Theme.Typography.badge)
            .tracking(1)
            .foregroundStyle(Theme.Colors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.screenPadding)
    }
}

#Preview("Settings Full") {
    @Previewable @State var appState = AppState()
    @Previewable @State var notifPrefs = NotificationPreferences()

    SettingsFullView(
        onBack: { print("Back") },
        onTopUp: { print("Top up") }
    )
    .environment(appState)
    .environment(notifPrefs)
}
