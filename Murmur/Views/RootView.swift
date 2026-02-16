import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @State private var inputText = ""
    @State private var transcript = ""
    @State private var processedEntries: [Entry] = []
    @State private var showSuccessToast = false
    @State private var toastMessage = ""
    @State private var showDevMode = false

    var body: some View {
        ZStack {
            // Main content based on disclosure level
            mainContent
                .preferredColorScheme(.dark)

            // Dev Mode floating button (always accessible once activated)
            #if DEBUG
            if appState.isDevMode {
                VStack {
                    HStack {
                        Button {
                            showDevMode = true
                        } label: {
                            Image(systemName: "hammer.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(Theme.Colors.accentPurple.opacity(0.8))
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 16)
                        .padding(.top, 54)

                        Spacer()
                    }
                    Spacer()
                }
                .zIndex(90)
            }
            #endif

            // Onboarding overlay (highest priority)
            if appState.showOnboarding {
                OnboardingFlowView(
                    onComplete: {
                        withAnimation {
                            appState.showOnboarding = false
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(100)
            }

            // Recording state overlays
            if !appState.showOnboarding {
                recordingOverlays
            }

            // Focus card overlay (L1)
            if appState.showFocusCard && !appState.showOnboarding {
                FocusCardView(
                    entry: Entry(
                        summary: "Review design mockups and provide feedback",
                        category: .todo,
                        priority: 2,
                        aiGenerated: true
                    ),
                    onMarkDone: {
                        withAnimation {
                            appState.showFocusCard = false
                        }
                    },
                    onSnooze: {
                        withAnimation {
                            appState.showFocusCard = false
                        }
                    },
                    onDismiss: {
                        withAnimation {
                            appState.showFocusCard = false
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(50)
            }

            // Success toast
            if showSuccessToast {
                VStack {
                    ToastView(
                        message: toastMessage,
                        type: .success,
                        isShowing: $showSuccessToast
                    )
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))

                    Spacer()
                }
                .zIndex(40)
            }
        }
        #if DEBUG
        .sheet(isPresented: $showDevMode) {
            DevModeView()
        }
        #endif
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        switch appState.effectiveLevel {
        case .void:
            // L0: The Void
            VoidView(
                inputText: $inputText,
                onMicTap: handleMicTap,
                onSubmit: handleTextSubmit,
                onSettingsTap: handleSettingsTap
            )

        case .firstLight:
            // L1: First Light (sparse home with InputBar)
            VStack(spacing: 0) {
                HomeSparseView(
                    inputText: $inputText,
                    entries: MockDataService.entriesForLevel1(),
                    onMicTap: handleMicTap,
                    onSubmit: handleTextSubmit,
                    onEntryTap: { entry in
                        print("Entry tapped: \(entry.summary)")
                    }
                )
                .frame(maxHeight: .infinity)

                InputBar(
                    text: $inputText,
                    placeholder: "Add a thought...",
                    isRecording: appState.recordingState == .recording,
                    onMicTap: handleMicTap,
                    onSubmit: handleTextSubmit
                )
            }
            .background(Theme.Colors.bgDeep.ignoresSafeArea())

        case .gridAwakens, .viewsEmerge, .fullPower:
            // L2-L4: Full tab-based interface
            MainTabView()
        }
    }

    // MARK: - Recording Overlays

    @ViewBuilder
    private var recordingOverlays: some View {
        switch appState.recordingState {
        case .recording:
            RecordingView(
                transcript: $transcript,
                onStop: {
                    withAnimation {
                        appState.recordingState = .processing
                        // Create mock entry from transcript
                        createMockEntry()
                    }
                }
            )
            .transition(.opacity)
            .zIndex(30)

        case .processing:
            ProcessingView(
                entries: processedEntries,
                transcript: transcript.isEmpty ? nil : transcript
            )
            .onAppear {
                // Simulate processing delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        appState.recordingState = .confirming
                    }
                }
            }
            .transition(.opacity)
            .zIndex(30)

        case .confirming:
            ConfirmView(
                entries: processedEntries,
                onAccept: {
                    withAnimation {
                        appState.recordingState = .idle
                        transcript = ""
                        processedEntries = []
                        showToast("Saved successfully")
                    }
                },
                onVoiceCorrect: { entry in
                    // Handle voice correction
                    print("Voice correct: \(entry.summary)")
                },
                onDiscard: { entry in
                    withAnimation {
                        processedEntries.removeAll { $0.id == entry.id }
                        if processedEntries.isEmpty {
                            appState.recordingState = .idle
                            transcript = ""
                        }
                    }
                }
            )
            .transition(.opacity)
            .zIndex(30)

        case .idle:
            EmptyView()
        }
    }

    // MARK: - Actions

    private func handleMicTap() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            appState.recordingState = .recording
        }
    }

    private func handleTextSubmit() {
        guard !inputText.isEmpty else { return }

        // Store transcript
        transcript = inputText

        // Process text input
        withAnimation {
            appState.recordingState = .processing
        }

        // Create mock entry
        createMockEntry()

        // Clear input
        inputText = ""
    }

    private func handleSettingsTap() {
        // At L0, this would show SettingsMinimalView as a sheet
        // For now, just print
        print("Settings tapped")
    }

    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation {
            showSuccessToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                showSuccessToast = false
            }
        }
    }

    private func createMockEntry() {
        // Create a mock entry from the transcript
        let mockEntry = Entry(
            summary: transcript.isEmpty ? "Sample thought" : transcript,
            category: .todo,
            priority: 1,
            aiGenerated: true
        )
        processedEntries = [mockEntry]
    }
}

#Preview("L0 - Void") {
    @Previewable @State var appState = AppState()

    appState.disclosureLevel = .void

    return RootView()
        .environment(appState)
}

#Preview("L1 - First Light") {
    @Previewable @State var appState = AppState()

    appState.disclosureLevel = .firstLight

    return RootView()
        .environment(appState)
}

#Preview("L2 - Grid Awakens") {
    @Previewable @State var appState = AppState()

    appState.disclosureLevel = .gridAwakens

    return RootView()
        .environment(appState)
}

#Preview("L3 - Views Emerge") {
    @Previewable @State var appState = AppState()

    appState.disclosureLevel = .viewsEmerge

    return RootView()
        .environment(appState)
}

#Preview("L4 - Full Power") {
    @Previewable @State var appState = AppState()

    appState.disclosureLevel = .fullPower

    return RootView()
        .environment(appState)
}

#Preview("With Onboarding") {
    @Previewable @State var appState = AppState()

    appState.showOnboarding = true

    return RootView()
        .environment(appState)
}

#Preview("With Focus Card") {
    @Previewable @State var appState = AppState()

    appState.disclosureLevel = .firstLight
    appState.showFocusCard = true

    return RootView()
        .environment(appState)
}

#Preview("Recording State") {
    @Previewable @State var appState = AppState()

    appState.disclosureLevel = .gridAwakens
    appState.recordingState = .recording

    return RootView()
        .environment(appState)
}
