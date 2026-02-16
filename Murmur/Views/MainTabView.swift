import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: BottomNavBar.Tab = .home
    @State private var inputText = ""
    @State private var isRecording = false

    private var hasFloatingMic: Bool {
        appState.effectiveLevel >= .gridAwakens
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content layer
            Group {
                switch selectedTab {
                case .home:
                    homeContent

                case .views:
                    viewsContent

                case .settings:
                    settingsContent
                }
            }
            .frame(maxHeight: .infinity)

            // InputBar
            InputBar(
                text: $inputText,
                placeholder: "Type or speak...",
                isRecording: isRecording,
                showMicButton: !hasFloatingMic,
                onMicTap: handleMicTap,
                onSubmit: handleTextSubmit
            )

            // Bottom nav bar
            ZStack {
                BottomNavBar(
                    selectedTab: $selectedTab,
                    showMicButton: hasFloatingMic
                )

                // Floating mic button (only at L2+)
                if hasFloatingMic {
                    MicButton(
                        size: .large,
                        isRecording: isRecording,
                        action: handleFloatingMicTap
                    )
                    .offset(y: -30)
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .background(Theme.Colors.bgDeep.ignoresSafeArea())
    }

    // MARK: - Content Views

    @ViewBuilder
    private var homeContent: some View {
        switch appState.effectiveLevel {
        case .void, .firstLight:
            // Should not reach here, but fallback to sparse
            HomeSparseView(
                inputText: $inputText,
                entries: MockDataService.entriesForLevel1(),
                onMicTap: handleMicTap,
                onSubmit: handleTextSubmit,
                onEntryTap: { entry in
                    print("Entry tapped: \(entry.summary)")
                }
            )

        case .gridAwakens, .viewsEmerge, .fullPower:
            HomeAIComposedView(
                inputText: $inputText,
                entries: MockDataService.entriesForLevel2(),
                onMicTap: handleMicTap,
                onSubmit: handleTextSubmit,
                onCardTap: { card in
                    print("Card tapped: \(card.id)")
                },
                onSettingsTap: {
                    selectedTab = .settings
                },
                onViewsTap: {
                    selectedTab = .views
                }
            )
        }
    }

    @ViewBuilder
    private var viewsContent: some View {
        if appState.effectiveLevel >= .viewsEmerge {
            ViewsGridView(
                onViewSelected: { viewType in
                    print("View selected: \(viewType)")
                },
                onCreateView: {
                    print("Create view tapped")
                },
                onDismiss: {
                    selectedTab = .home
                }
            )
        } else {
            // Views tab not accessible before L3
            EmptyStateView(type: .home, onAction: nil)
        }
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch appState.effectiveLevel {
        case .void, .firstLight, .gridAwakens:
            SettingsMinimalView(
                onBack: {
                    selectedTab = .home
                },
                onTopUp: {
                    print("Top up tapped")
                }
            )

        case .viewsEmerge, .fullPower:
            SettingsFullView(
                onBack: {
                    selectedTab = .home
                },
                onManageViews: {
                    print("Manage views tapped")
                },
                onExportData: {
                    print("Export data tapped")
                },
                onClearData: {
                    print("Clear data tapped")
                },
                onOpenSourceLicenses: {
                    print("Open source licenses tapped")
                }
            )
        }
    }

    // MARK: - Actions

    private func handleMicTap() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isRecording.toggle()
        }

        if isRecording {
            // Start recording
            appState.recordingState = .recording
        } else {
            // Stop recording
            appState.recordingState = .idle
        }
    }

    private func handleFloatingMicTap() {
        // Floating mic button action
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isRecording.toggle()
        }

        if isRecording {
            appState.recordingState = .recording
        } else {
            appState.recordingState = .idle
        }
    }

    private func handleTextSubmit() {
        guard !inputText.isEmpty else { return }

        // Handle text submission
        print("Submit text:", inputText)

        // Process text input
        appState.recordingState = .processing

        // Clear input
        inputText = ""

        // Simulate processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            appState.recordingState = .confirming
        }
    }
}

#Preview("L2 - Grid Awakens") {
    @Previewable @State var appState = AppState()

    appState.disclosureLevel = .gridAwakens

    return MainTabView()
        .environment(appState)
}

#Preview("L3 - Views Emerge") {
    @Previewable @State var appState = AppState()

    appState.disclosureLevel = .viewsEmerge

    return MainTabView()
        .environment(appState)
}

#Preview("L4 - Full Power") {
    @Previewable @State var appState = AppState()

    appState.disclosureLevel = .fullPower

    return MainTabView()
        .environment(appState)
}
