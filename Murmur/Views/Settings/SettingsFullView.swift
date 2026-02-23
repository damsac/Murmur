import SwiftUI

struct SettingsFullView: View {
    @Environment(AppState.self) private var appState
    @Environment(NotificationPreferences.self) private var notifPrefs
    let onBack: () -> Void
    let onTopUp: () -> Void
    let onManageViews: () -> Void
    let onExportData: () -> Void
    let onClearData: () -> Void
    let onOpenSourceLicenses: () -> Void

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

                // Settings content
                ScrollView {
                    VStack(spacing: 0) {
                        // Notifications section
                        SectionHeader(title: "NOTIFICATIONS")

                        notificationsSection

                        // Credits section
                        SectionHeader(title: "CREDITS")
                            .padding(.top, 32)

                        SettingsRow(
                            icon: "bolt.fill",
                            iconColor: Theme.Colors.accentPurple,
                            label: "Balance",
                            value: "\(appState.creditBalance.formatted()) credits",
                            showChevron: false,
                            action: {}
                        )

                        SettingsRow(
                            icon: "arrow.up.circle.fill",
                            iconColor: Theme.Colors.accentPurple,
                            label: "Top Up",
                            value: nil,
                            showChevron: true,
                            action: onTopUp
                        )

                        // AI Backend section
                        SectionHeader(title: "AI BACKEND")
                            .padding(.top, 32)

                        SettingsRow(
                            icon: "waveform",
                            iconColor: Theme.Colors.accentBlue,
                            label: "Transcription Service",
                            value: "Whisper API",
                            showChevron: true,
                            action: { print("Transcription service") }
                        )

                        SettingsRow(
                            icon: "brain",
                            iconColor: Theme.Colors.accentPurple,
                            label: "LLM Endpoint",
                            value: "Claude 3.5 Sonnet",
                            showChevron: true,
                            action: { print("LLM endpoint") }
                        )

                        SettingsRow(
                            icon: "key.fill",
                            iconColor: Theme.Colors.accentYellow,
                            label: "API Key",
                            value: "sk-ant-api03-••••",
                            showChevron: true,
                            action: { print("API key") }
                        )

                        // Views section
                        SectionHeader(title: "VIEWS")
                            .padding(.top, 32)

                        SettingsRow(
                            icon: "rectangle.grid.2x2",
                            iconColor: Theme.Colors.accentPurple,
                            label: "Manage Views",
                            value: nil,
                            showChevron: true,
                            action: onManageViews
                        )

                        SettingsRow(
                            icon: "house.fill",
                            iconColor: Theme.Colors.accentBlue,
                            label: "Default Home Layout",
                            value: "AI Composed",
                            showChevron: true,
                            action: { print("Home layout") }
                        )

                        // Data section
                        SectionHeader(title: "DATA")
                            .padding(.top, 32)

                        SettingsRow(
                            icon: "square.and.arrow.up",
                            iconColor: Theme.Colors.accentGreen,
                            label: "Export Thoughts",
                            value: nil,
                            showChevron: true,
                            action: onExportData
                        )

                        SettingsRow(
                            icon: "trash.fill",
                            iconColor: Theme.Colors.accentRed,
                            label: "Clear All Data",
                            value: nil,
                            showChevron: true,
                            action: onClearData
                        )

                        // About section
                        SectionHeader(title: "ABOUT")
                            .padding(.top, 32)

                        SettingsRow(
                            icon: "info.circle.fill",
                            iconColor: Theme.Colors.textSecondary,
                            label: "Version",
                            value: "1.0.0 (beta)",
                            showChevron: false,
                            action: {}
                        )

                        SettingsRow(
                            icon: "doc.text.fill",
                            iconColor: Theme.Colors.textSecondary,
                            label: "Open Source Licenses",
                            value: nil,
                            showChevron: true,
                            action: onOpenSourceLicenses
                        )

                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Notifications Section

    @ViewBuilder
    private var notificationsSection: some View {
        @Bindable var prefs = notifPrefs

        SettingsToggleRow(
            icon: "bell.fill",
            iconColor: Theme.Colors.accentPurple,
            label: "Reminders",
            isOn: $prefs.remindersEnabled
        )

        SettingsToggleRow(
            icon: "clock.fill",
            iconColor: Theme.Colors.accentYellow,
            label: "Due Soon (todos)",
            isOn: $prefs.dueSoonEnabled
        )

        SettingsToggleRow(
            icon: "moon.zzz.fill",
            iconColor: Theme.Colors.accentBlue,
            label: "Snooze Wake-Up",
            isOn: $prefs.snoozeWakeUpEnabled
        )
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
            .padding(.bottom, 12)
    }
}

#Preview("Settings Full") {
    @Previewable @State var appState = AppState()
    @Previewable @State var notifPrefs = NotificationPreferences()

    SettingsFullView(
        onBack: { print("Back") },
        onTopUp: { print("Top up") },
        onManageViews: { print("Manage views") },
        onExportData: { print("Export data") },
        onClearData: { print("Clear data") },
        onOpenSourceLicenses: { print("Licenses") }
    )
    .environment(appState)
    .environment(notifPrefs)
}
