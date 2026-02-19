import SwiftUI
import MurmurCore

struct DevModeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

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
                                .font(.body.weight(.semibold))
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
                                        .font(.caption2)
                                    Text("Overriding natural level (\(appState.disclosureLevel.displayName))")
                                        .font(.caption2)
                                }
                                .foregroundStyle(Theme.Colors.accentYellow)
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.screenPadding)
                        .padding(.top, 8)

                        Divider()
                            .background(Theme.Colors.borderSubtle)

                        // State Toggles
                        VStack(alignment: .leading, spacing: 12) {
                            Text("State Toggles")
                                .font(.body.weight(.semibold))
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
                                        .font(.subheadline)
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
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(Theme.Colors.accentPurple)

                                            Image(systemName: "chevron.down")
                                                .font(Theme.Typography.badge)
                                                .foregroundStyle(Theme.Colors.accentPurple)
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.screenPadding)

                        Divider()
                            .background(Theme.Colors.borderSubtle)

                        // Pipeline Debug Info
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Pipeline Status")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.Colors.textPrimary)

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Pipeline")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                    Spacer()
                                    Text(appState.pipeline != nil ? "Configured" : "Not configured")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(appState.pipeline != nil ? Theme.Colors.accentGreen : Theme.Colors.accentRed)
                                }

                                if let error = appState.pipelineError {
                                    HStack(alignment: .top) {
                                        Text("Error")
                                            .font(.subheadline)
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                        Spacer()
                                        Text(error)
                                            .font(Theme.Typography.caption)
                                            .foregroundStyle(Theme.Colors.accentRed)
                                            .multilineTextAlignment(.trailing)
                                    }
                                }

                                HStack {
                                    Text("Processed Entries")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                    Spacer()
                                    Text("\(appState.processedEntries.count)")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                        .monospacedDigit()
                                }

                                if !appState.processedTranscript.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Last Transcript")
                                            .font(.subheadline)
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                        Text(appState.processedTranscript)
                                            .font(Theme.Typography.caption)
                                            .foregroundStyle(Theme.Colors.textTertiary)
                                            .lineLimit(3)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.screenPadding)

                        Divider()
                            .background(Theme.Colors.borderSubtle)

                        // Onboarding Reset
                        Button {
                            appState.hasCompletedOnboarding = false
                            appState.showOnboarding = true
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise.circle")
                                    .font(.body.weight(.semibold))

                                Text("Reset Onboarding")
                                    .font(.body.weight(.semibold))
                            }
                            .foregroundStyle(Theme.Colors.accentYellow)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Theme.Colors.accentYellow.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Theme.Colors.accentYellow.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Theme.Spacing.screenPadding)

                        // Reset Button
                        Button(action: resetAllState) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.body.weight(.semibold))

                                Text("Reset All Dev Overrides")
                                    .font(.body.weight(.semibold))
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
                    .font(.subheadline.weight(.bold))
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
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(Theme.Colors.accentPurple)
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
