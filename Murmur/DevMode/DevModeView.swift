import SwiftUI
import MurmurCore

struct DevModeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @AppStorage("homeVariant") private var homeVariant: String = "zones"
    @AppStorage("colorPalette") private var colorPalette: String = "classic"

    var body: some View {
        @Bindable var appState = appState
        NavigationStack {
            ZStack {
                Theme.Colors.bgDeep
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // State Toggles
                        VStack(alignment: .leading, spacing: 12) {
                            Text("State Toggles")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.Colors.textPrimary)

                            VStack(spacing: 8) {
                                StateToggleRow(
                                    label: "Research Colors",
                                    isOn: Binding(
                                        get: { colorPalette == "research" },
                                        set: { colorPalette = $0 ? "research" : "classic" }
                                    )
                                )

                                StateToggleRow(
                                    label: "Show Onboarding",
                                    isOn: $appState.showOnboarding
                                )

                                // Home variant picker
                                HStack {
                                    Text("Home View")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.Colors.textSecondary)

                                    Spacer()

                                    Picker("", selection: $homeVariant) {
                                        Text("Scanner").tag("scanner")
                                        Text("Zones").tag("zones")
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 210)
                                }
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

                            }
                        }
                        .padding(.horizontal, Theme.Spacing.screenPadding)

                        Divider()
                            .background(Theme.Colors.borderSubtle)

                        // Recompose Home
                        Button {
                            appState.invalidateHomeComposition()
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "rectangle.3.group")
                                    .font(.body.weight(.semibold))

                                Text("Recompose Home")
                                    .font(.body.weight(.semibold))
                            }
                            .foregroundStyle(Theme.Colors.accentBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Theme.Colors.accentBlue.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Theme.Colors.accentBlue.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Theme.Spacing.screenPadding)

                        // Drain Credits
                        Button {
                            Task { @MainActor in
                                #if DEBUG
                                await appState.creditGate?.setBalance(0)
                                await appState.refreshCreditBalance()
                                #endif
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "creditcard.trianglebadge.exclamationmark")
                                    .font(.body.weight(.semibold))

                                Text("Drain Credits to Zero")
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

    private func resetAllState() {
        withAnimation {
            appState.showOnboarding = false
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

#Preview {
    @Previewable @State var appState = AppState()

    appState.isDevMode = true

    return DevModeView()
        .environment(appState)
}
