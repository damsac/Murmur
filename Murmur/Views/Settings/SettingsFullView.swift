import SwiftUI

struct SettingsFullView: View {
    @Environment(AppState.self) private var appState
    @Environment(NotificationPreferences.self) private var notifPrefs
    let onBack: () -> Void
    let onTopUp: () -> Void

    @State private var showArchive = false
    @State private var showHelp = false

    var body: some View {
        if showArchive {
            ArchiveView(onBack: { showArchive = false })
        } else if showHelp {
            HelpView(onBack: { showHelp = false })
        } else {
            settingsContent
        }
    }

    @ViewBuilder
    private var settingsContent: some View {
        ZStack(alignment: .top) {
            Theme.Colors.bgDeep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                NavHeader(
                    title: "Settings",
                    showBackButton: true,
                    backAction: onBack,
                    trailingButtons: [
                        NavHeader.NavButton(icon: "questionmark.circle") {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showHelp = true
                            }
                        }
                    ]
                )

                ScrollView {
                    VStack(spacing: 24) {
                        creditsSection

                        VStack(spacing: 12) {
                            SectionHeader(title: "NOTIFICATIONS")
                            notificationsGroup
                        }

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

        VStack(spacing: 8) {
            NotifRow(icon: "bell.fill", title: "Reminders", isOn: $prefs.remindersEnabled) {
                LeadTimePicker(
                    selected: $prefs.remindersLeadTime,
                    options: [("At time", 0), ("5 min", 5), ("15 min", 15), ("30 min", 30)]
                )
            }

            NotifRow(icon: "clock.fill", title: "Due Soon", isOn: $prefs.dueSoonEnabled) {
                LeadTimePicker(
                    selected: $prefs.dueSoonLeadTime,
                    options: [("At time", 0), ("1 hr", 60), ("3 hrs", 180), ("1 day", 1440)]
                )
            }

            NotifRow(icon: "repeat.circle.fill", title: "Habits", isOn: $prefs.habitsEnabled) {
                HabitTimePicker(hour: $prefs.habitHour, minute: $prefs.habitMinute)
                    .onChange(of: prefs.habitHour) { _, _ in
                        NotificationService.shared.scheduleHabitReminder(preferences: prefs)
                    }
                    .onChange(of: prefs.habitMinute) { _, _ in
                        NotificationService.shared.scheduleHabitReminder(preferences: prefs)
                    }
            }
            .onChange(of: prefs.habitsEnabled) { _, enabled in
                if enabled {
                    NotificationService.shared.scheduleHabitReminder(preferences: prefs)
                } else {
                    NotificationService.shared.cancelHabitReminder()
                }
            }

            NotifRow(icon: "moon.zzz.fill", title: "Snooze", isOn: $prefs.snoozeWakeUpEnabled, content: nil)
        }
        .padding(.horizontal, Theme.Spacing.screenPadding)
    }
}

// MARK: - Notification Row

private struct NotifRow<Content: View>: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    @ViewBuilder let content: () -> Content

    init(
        icon: String,
        title: String,
        isOn: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.title = title
        self._isOn = isOn
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isOn ? Theme.Colors.accentPurple : Theme.Colors.textTertiary)
                    .frame(width: 22)

                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Spacer()

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(Theme.Colors.accentPurple)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)

            if isOn {
                content()
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius)
                .fill(Theme.Colors.bgCard)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius)
                        .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isOn)
        .clipped()
    }
}

// Convenience init for rows with no expandable content (Snooze)
extension NotifRow where Content == EmptyView {
    init(icon: String, title: String, isOn: Binding<Bool>, content: Content?) {
        self.icon = icon
        self.title = title
        self._isOn = isOn
        self.content = { EmptyView() }
    }
}

// MARK: - Lead Time Picker

private struct LeadTimePicker: View {
    @Binding var selected: Int
    let options: [(label: String, minutes: Int)]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.minutes) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selected = option.minutes
                    }
                } label: {
                    Text(option.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(selected == option.minutes ? Theme.Colors.accentPurple : Theme.Colors.textTertiary)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selected == option.minutes ? Theme.Colors.accentPurple.opacity(0.12) : Theme.Colors.bgDeep)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            selected == option.minutes ? Theme.Colors.accentPurple.opacity(0.3) : Theme.Colors.borderSubtle,
                                            lineWidth: 1
                                        )
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Habit Time Picker

private struct HabitTimePicker: View {
    @Binding var hour: Int
    @Binding var minute: Int

    // Morning = 8am, Midday = 12pm, Evening = 9pm
    private let options: [(label: String, icon: String, hour: Int, minute: Int)] = [
        ("Morning", "sunrise.fill", 8, 0),
        ("Midday", "sun.max.fill", 12, 0),
        ("Evening", "moon.fill", 21, 0),
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.label) { option in
                let selected = option.hour == hour && option.minute == minute
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        hour = option.hour
                        minute = option.minute
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: option.icon)
                            .font(.system(size: 10, weight: .medium))
                        Text(option.label)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(selected ? Theme.Colors.accentPurple : Theme.Colors.textTertiary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selected ? Theme.Colors.accentPurple.opacity(0.12) : Theme.Colors.bgDeep)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        selected ? Theme.Colors.accentPurple.opacity(0.3) : Theme.Colors.borderSubtle,
                                        lineWidth: 1
                                    )
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
