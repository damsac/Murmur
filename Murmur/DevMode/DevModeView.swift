import SwiftUI

struct DevModeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedScreen: DevScreen?
    @State private var showComponentGallery = false

    var body: some View {
        @Bindable var appState = appState
        NavigationStack {
            ZStack {
                Theme.Colors.bgDeep
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Level Picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Progressive Disclosure Level")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textPrimary)

                            HStack(spacing: 10) {
                                ForEach([DisclosureLevel.void, .firstLight, .gridAwakens, .viewsEmerge, .fullPower], id: \.self) { level in
                                    LevelButton(
                                        level: level,
                                        isSelected: appState.devOverrideLevel == level,
                                        naturalLevel: appState.disclosureLevel
                                    ) {
                                        withAnimation {
                                            if appState.devOverrideLevel == level {
                                                appState.devOverrideLevel = nil
                                            } else {
                                                appState.devOverrideLevel = level
                                            }
                                        }
                                    }
                                }
                            }

                            if appState.devOverrideLevel != nil {
                                HStack(spacing: 6) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 12))
                                    Text("Overriding natural level (\(appState.disclosureLevel.displayName))")
                                        .font(.system(size: 12))
                                }
                                .foregroundStyle(Theme.Colors.accentYellow)
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.screenPadding)
                        .padding(.top, 8)

                        Divider()
                            .background(Theme.Colors.borderSubtle)

                        // Data Controls
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Data Controls")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textPrimary)

                            // Credit balance
                            HStack {
                                Text("Credit Balance")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.Colors.textSecondary)

                                Spacer()

                                Stepper(
                                    value: $appState.creditBalance,
                                    in: 0...10000,
                                    step: 100
                                ) {
                                    Text("\(appState.creditBalance)")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                        .monospacedDigit()
                                        .frame(width: 60, alignment: .trailing)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.screenPadding)

                        Divider()
                            .background(Theme.Colors.borderSubtle)

                        // State Toggles
                        VStack(alignment: .leading, spacing: 12) {
                            Text("State Toggles")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textPrimary)

                            VStack(spacing: 8) {
                                StateToggleRow(
                                    label: "Show Onboarding",
                                    isOn: $appState.showOnboarding
                                )

                                StateToggleRow(
                                    label: "Show Focus Card",
                                    isOn: $appState.showFocusCard
                                )

                                // Recording state buttons
                                HStack {
                                    Text("Recording State")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.Colors.textSecondary)

                                    Spacer()

                                    Menu {
                                        Button("Idle") {
                                            appState.recordingState = .idle
                                        }
                                        Button("Recording") {
                                            appState.recordingState = .recording
                                        }
                                        Button("Processing") {
                                            appState.recordingState = .processing
                                        }
                                        Button("Confirming") {
                                            appState.recordingState = .confirming
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(recordingStateLabel)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(Theme.Colors.accentPurple)

                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(Theme.Colors.accentPurple)
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.screenPadding)

                        // Component Gallery
                        Button {
                            showComponentGallery = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(Theme.Colors.accentPurple)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Theme.Colors.accentPurple.opacity(0.1))
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Component Gallery")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Theme.Colors.textPrimary)

                                    Text("Browse all \(DevComponent.allCases.count) UI components")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.Colors.textTertiary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.Colors.textTertiary)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Theme.Colors.bgCard)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Theme.Colors.accentPurple.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Theme.Spacing.screenPadding)

                        Divider()
                            .background(Theme.Colors.borderSubtle)

                        // Screen Browser
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Screen Browser")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .padding(.horizontal, Theme.Spacing.screenPadding)

                            Text("Tap any screen to preview in isolation")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.Colors.textTertiary)
                                .padding(.horizontal, Theme.Spacing.screenPadding)

                            LazyVStack(spacing: 1) {
                                ForEach(DevScreen.allCases) { screen in
                                    ScreenBrowserRow(screen: screen) {
                                        selectedScreen = screen
                                    }
                                }
                            }
                        }

                        // Reset Button
                        Button(action: resetAllState) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 16, weight: .semibold))

                                Text("Reset All Dev Overrides")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(Theme.Colors.accentRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Theme.Colors.accentRed.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Theme.Colors.accentRed.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Theme.Spacing.screenPadding)
                        .padding(.bottom, 40)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Dev Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Theme.Colors.accentPurple)
                }
            }
            .sheet(isPresented: $showComponentGallery) {
                DevComponentGallery()
                    .environment(appState)
            }
            .sheet(item: $selectedScreen) { screen in
                NavigationStack {
                    screen.view
                        .navigationTitle(screen.rawValue)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Close") {
                                    selectedScreen = nil
                                }
                                .foregroundStyle(Theme.Colors.accentPurple)
                            }
                        }
                }
            }
        }
    }

    private var recordingStateLabel: String {
        switch appState.recordingState {
        case .idle: return "Idle"
        case .recording: return "Recording"
        case .processing: return "Processing"
        case .confirming: return "Confirming"
        }
    }

    private func resetAllState() {
        withAnimation {
            appState.devOverrideLevel = nil
            appState.recordingState = .idle
            appState.showOnboarding = false
            appState.showFocusCard = false
            appState.creditBalance = 1000
        }
    }
}

// MARK: - Level Button

private struct LevelButton: View {
    let level: DisclosureLevel
    let isSelected: Bool
    let naturalLevel: DisclosureLevel
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(levelShortName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(
                        isSelected
                            ? Theme.Colors.textPrimary
                            : (level == naturalLevel ? Theme.Colors.accentGreen : Theme.Colors.textTertiary)
                    )

                if level == naturalLevel && !isSelected {
                    Circle()
                        .fill(Theme.Colors.accentGreen)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isSelected
                            ? Theme.Colors.accentPurple
                            : Theme.Colors.bgCard
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected
                                    ? Theme.Colors.accentPurple
                                    : (level == naturalLevel ? Theme.Colors.accentGreen.opacity(0.3) : Theme.Colors.borderSubtle),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var levelShortName: String {
        switch level {
        case .void: return "L0"
        case .firstLight: return "L1"
        case .gridAwakens: return "L2"
        case .viewsEmerge: return "L3"
        case .fullPower: return "L4"
        }
    }
}

// MARK: - State Toggle Row

private struct StateToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Theme.Colors.textSecondary)

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(Theme.Colors.accentPurple)
        }
    }
}

// MARK: - Screen Browser Row

private struct ScreenBrowserRow: View {
    let screen: DevScreen
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Level indicator
                Text(levelIndicator)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(levelColor)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(levelColor.opacity(0.1))
                    )

                // Screen name
                Text(screen.rawValue)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)
            .padding(.vertical, 12)
            .background(Theme.Colors.bgCard)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var levelIndicator: String {
        switch screen.level {
        case .void: return "L0"
        case .firstLight: return "L1"
        case .gridAwakens: return "L2"
        case .viewsEmerge: return "L3"
        case .fullPower: return "L4"
        }
    }

    private var levelColor: Color {
        switch screen.level {
        case .void: return Theme.Colors.textMuted
        case .firstLight: return Theme.Colors.accentYellow
        case .gridAwakens: return Theme.Colors.accentPurple
        case .viewsEmerge: return Theme.Colors.accentBlue
        case .fullPower: return Theme.Colors.accentGreen
        }
    }
}

// MARK: - Extension for DisclosureLevel

extension DisclosureLevel {
    var displayName: String {
        switch self {
        case .void: return "Void"
        case .firstLight: return "First Light"
        case .gridAwakens: return "Grid Awakens"
        case .viewsEmerge: return "Views Emerge"
        case .fullPower: return "Full Power"
        }
    }
}

#Preview {
    @Previewable @State var appState = AppState()

    appState.disclosureLevel = .gridAwakens
    appState.isDevMode = true

    return DevModeView()
        .environment(appState)
}
