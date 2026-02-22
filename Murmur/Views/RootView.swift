import SwiftUI
import SwiftData
import AVFAudio
import MurmurCore

// swiftlint:disable:next type_body_length
struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(NotificationPreferences.self) private var notifPrefs
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @State private var selectedTab: BottomNavBar.Tab = .home
    @State private var selectedEntry: Entry?
    @State private var inputText = ""
    @State private var transcript = ""
    @State private var toastConfig: ToastContainer.ToastConfig?
    @State private var showDevMode = false
    @State private var showTextInput = false
    @State private var showTopUp = false
    @State private var isPurchasingTopUp = false
    @State private var isLoadingTopUpProducts = false
    @State private var topUpPacks: [CreditPack] = []
    @State private var topUpProductIDByCredits: [Int64: String] = [:]
    private let topUpService = StoreKitTopUpService()

    var body: some View {
        ZStack {
            // Main content based on selected tab + disclosure level
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
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(Theme.Colors.accentPurple.opacity(0.8))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Developer tools")
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

            // Focus card overlay (L1) — show highest priority active entry
            if appState.showFocusCard && !appState.showOnboarding,
               let focusEntry = topPriorityEntry {
                FocusCardView(
                    entry: focusEntry,
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

        }
        .toast($toastConfig)
        #if DEBUG
        .sheet(isPresented: $showDevMode) {
            DevModeView()
        }
        #endif
        .sheet(item: $selectedEntry) { entry in
            EntryDetailView(
                entry: entry,
                onBack: { selectedEntry = nil },
                onEdit: {},
                onViewTranscript: {},
                onArchive: { selectedEntry = nil },
                onSnooze: { selectedEntry = nil },
                onDelete: {
                    modelContext.delete(entry)
                    selectedEntry = nil
                }
            )
            .environment(appState)
            .environment(notifPrefs)
        }
        .sheet(isPresented: $showTextInput) {
            TextInputView(text: $inputText, onSubmit: handleTextSubmit)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTopUp) {
            TopUpView(
                packs: topUpPacks,
                isLoading: isLoadingTopUpProducts,
                onBack: { showTopUp = false },
                onPurchase: { pack in
                    handleTopUpPurchase(pack)
                }
            )
        }
        .onAppear {
            wakeUpSnoozedEntries()
            updateDisclosureLevel()
            if !appState.hasCompletedOnboarding {
                appState.showOnboarding = true
            }
            Task { @MainActor in
                await appState.refreshCreditBalance()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { wakeUpSnoozedEntries() }
        }
        .onChange(of: entries.count) { _, _ in updateDisclosureLevel() }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            wakeUpSnoozedEntries()
        }
        .onReceive(NotificationCenter.default.publisher(for: .murmurOpenEntry)) { notification in
            guard let uuid = notification.userInfo?["entryID"] as? UUID else { return }
            selectedEntry = entries.first { $0.id == uuid }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        Group {
            switch selectedTab {
            case .home:
                homeContent

            case .archive:
                ArchiveView(
                    entries: archivedEntries,
                    onEntryTap: { entry in selectedEntry = entry }
                )

            case .settings:
                settingsContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.bgDeep)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomNavBar(
                selectedTab: $selectedTab,
                isRecording: appState.recordingState == .recording,
                onMicTap: handleMicTap,
                onKeyboardTap: { showTextInput = true }
            )
            .background(
                Theme.Colors.bgBody.opacity(0.95),
                ignoresSafeAreaEdges: .bottom
            )
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Home Content

    @ViewBuilder
    private var homeContent: some View {
        switch appState.effectiveLevel {
        case .void:
            VoidView(onMicTap: handleMicTap)

        case .firstLight:
            HomeSparseView(
                inputText: $inputText,
                entries: activeEntries,
                onMicTap: handleMicTap,
                onSubmit: handleTextSubmit,
                onEntryTap: { entry in selectedEntry = entry }
            )

        case .gridAwakens, .viewsEmerge, .fullPower:
            HomeAIComposedView(
                inputText: $inputText,
                entries: activeEntries,
                onMicTap: handleMicTap,
                onSubmit: handleTextSubmit,
                onEntryTap: { entry in
                    selectedEntry = entry
                },
                onSettingsTap: {
                    selectedTab = .settings
                },
                onViewsTap: {
                    // Views tab removed — no-op
                },
                onSnooze: { entry in
                    entry.status = .snoozed
                    entry.snoozeUntil = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
                    entry.updatedAt = Date()
                    try? modelContext.save()
                    NotificationService.shared.sync(entry, preferences: notifPrefs)
                },
                onComplete: { entry in
                    entry.status = .completed
                    entry.updatedAt = Date()
                    try? modelContext.save()
                    NotificationService.shared.cancel(entry)
                },
                onArchive: { entry in
                    entry.status = .archived
                    entry.updatedAt = Date()
                    try? modelContext.save()
                    NotificationService.shared.cancel(entry)
                },
                onDelete: { entry in
                    NotificationService.shared.cancel(entry)
                    modelContext.delete(entry)
                    try? modelContext.save()
                }
            )
        }
    }

    // MARK: - Settings Content

    @ViewBuilder
    private var settingsContent: some View {
        switch appState.effectiveLevel {
        case .void, .firstLight, .gridAwakens:
            SettingsMinimalView(
                creditBalance: appState.creditBalance,
                onBack: {
                    selectedTab = .home
                },
                onTopUp: {
                    openTopUp()
                    showTopUp = true
                }
            )

        case .viewsEmerge, .fullPower:
            SettingsFullView(
                onBack: {
                    selectedTab = .home
                },
                onManageViews: {},
                onExportData: {},
                onClearData: {},
                onOpenSourceLicenses: {}
            )
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
                    handleStopRecording()
                }
            )
            .transition(.opacity)
            .zIndex(30)

        case .processing:
            ProcessingView(
                entries: appState.processedEntries,
                transcript: transcript.isEmpty ? nil : transcript
            )
            .transition(.opacity)
            .zIndex(30)

        case .confirming:
            ConfirmView(
                entries: appState.processedEntries,
                onAccept: {
                    handleAccept()
                },
                onVoiceCorrect: { entry in
                    // Handle voice correction
                    print("Voice correct: \(entry.summary)")
                },
                onDiscard: { entry in
                    withAnimation {
                        appState.processedEntries.removeAll { $0.id == entry.id }
                        if appState.processedEntries.isEmpty {
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
        guard let pipeline = appState.pipeline else {
            showToast("Pipeline not configured — check API key", type: .error)
            return
        }

        Task { @MainActor in
            // Request mic permission if not yet determined
            let recordPermission = AVAudioApplication.shared.recordPermission
            if recordPermission == .undetermined {
                let granted = await AVAudioApplication.requestRecordPermission()
                if !granted {
                    showToast("Microphone access is required for recording", type: .error)
                    return
                }
            } else if recordPermission == .denied {
                showToast("Microphone access denied — enable in Settings", type: .error)
                return
            }

            do {
                try await pipeline.startRecording()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    appState.recordingState = .recording
                }
            } catch {
                print("Failed to start recording: \(error.localizedDescription)")
                showToast("Recording failed: \(error.localizedDescription)", type: .error)
            }
        }
    }

    private func handleStopRecording() {
        guard let pipeline = appState.pipeline else {
            showToast("Pipeline not configured — check API key", type: .error)
            return
        }
        guard appState.recordingState == .recording else { return }

        Task { @MainActor in
            // Yield to let any pending recognition callbacks update currentTranscript
            await Task.yield()

            // Instant check: if nothing was said, bail immediately
            let liveText = await pipeline.currentTranscript
            if liveText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await pipeline.cancelRecording()
                withAnimation {
                    appState.recordingState = .idle
                }
                transcript = ""
                return
            }

            // Content detected — cancel recording instantly and extract from live text
            await pipeline.cancelRecording()
            withAnimation {
                appState.recordingState = .processing
            }

            do {
                let result = try await pipeline.extractFromText(liveText)
                transcript = liveText
                appState.processedEntries = result.entries
                appState.processedTranscript = liveText
                appState.processedAudioDuration = nil
                appState.processedSource = .voice
                await appState.refreshCreditBalance()
                withAnimation {
                    appState.recordingState = .confirming
                }
            } catch {
                print("Processing failed: \(error.localizedDescription)")
                withAnimation {
                    appState.recordingState = .idle
                }
                handlePipelineError(error, fallbackPrefix: "Processing failed")
            }
        }
    }

    private func handleTextSubmit() {
        guard !inputText.isEmpty else { return }

        let text = inputText
        transcript = text
        inputText = ""

        guard let pipeline = appState.pipeline else {
            showToast("Pipeline not configured — check API key", type: .error)
            return
        }

        withAnimation {
            appState.recordingState = .processing
        }

        Task { @MainActor in
            do {
                let result = try await pipeline.extractFromText(text)
                appState.processedEntries = result.entries
                appState.processedTranscript = text
                appState.processedAudioDuration = nil
                appState.processedSource = .text
                await appState.refreshCreditBalance()
                withAnimation {
                    appState.recordingState = .confirming
                }
            } catch {
                print("Text extraction failed: \(error.localizedDescription)")
                withAnimation {
                    appState.recordingState = .idle
                }
                handlePipelineError(error, fallbackPrefix: "Extraction failed")
            }
        }
    }

    private func handleTopUpPurchase(_ pack: CreditPack) {
        guard !isPurchasingTopUp else { return }

        isPurchasingTopUp = true
        Task { @MainActor in
            defer { isPurchasingTopUp = false }
            do {
                let credits = Int64(pack.credits)
                guard let productID = topUpProductIDByCredits[credits] else {
                    showToast("Top-up product unavailable in StoreKit. Check IAP IDs/config.", type: .error)
                    return
                }

                let receipt = try await topUpService.purchase(productID: productID)
                try await appState.applyTopUp(credits: receipt.creditsGranted)
                showTopUp = false
                showToast("Top-up successful: +\(receipt.creditsGranted.formatted()) credits")
            } catch let error as StoreKitTopUpError {
                switch error {
                case .userCancelled:
                    break
                case .pending:
                    showToast("Purchase pending approval.", type: .warning)
                default:
                    showToast("Top-up failed: \(error.localizedDescription)", type: .error)
                }
            } catch {
                showToast("Top-up failed: \(error.localizedDescription)", type: .error)
            }
        }
    }

    private func handlePipelineError(_ error: Error, fallbackPrefix: String) {
        if case PipelineError.insufficientCredits = error {
            openTopUp()
            showTopUp = true
            showToast("Out of credits. Top up to continue.", type: .warning)
            return
        }
        showToast("\(fallbackPrefix): \(error.localizedDescription)", type: .error)
    }

    private func handleAccept() {
        guard !appState.processedEntries.isEmpty else { return }

        var savedEntries: [Entry] = []
        do {
            for extracted in appState.processedEntries {
                let entry = Entry(
                    from: extracted,
                    transcript: appState.processedTranscript,
                    source: appState.processedSource,
                    audioDuration: appState.processedAudioDuration
                )
                modelContext.insert(entry)
                savedEntries.append(entry)
            }
            try modelContext.save()
        } catch {
            print("Failed to save entries: \(error.localizedDescription)")
            showToast("Save failed: \(error.localizedDescription)", type: .error)
            return
        }

        for entry in savedEntries {
            NotificationService.shared.sync(entry, preferences: notifPrefs)
        }

        withAnimation {
            appState.recordingState = .idle
            transcript = ""
            appState.processedEntries = []
            appState.processedTranscript = ""
            appState.processedAudioDuration = nil
            showToast("Saved successfully")
        }
    }

    private func showToast(_ message: String, type: ToastView.ToastType = .success) {
        toastConfig = ToastContainer.ToastConfig(message: message, type: type)
    }

}

// MARK: - Helpers

private extension RootView {
    var activeEntries: [Entry] {
        entries.filter { $0.status == .active }
    }

    var archivedEntries: [Entry] {
        entries.filter { $0.status == .archived }
    }

    var topPriorityEntry: Entry? {
        activeEntries
            .filter { $0.priority != nil }
            .min { ($0.priority ?? 5) < ($1.priority ?? 5) }
    }

    func wakeUpSnoozedEntries() {
        let now = Date()
        var woken: [Entry] = []
        for entry in entries where entry.status == .snoozed {
            if let snoozeUntil = entry.snoozeUntil, snoozeUntil <= now {
                entry.status = .active
                entry.snoozeUntil = nil
                entry.updatedAt = now
                woken.append(entry)
            }
        }
        if !woken.isEmpty {
            do {
                try modelContext.save()
            } catch {
                print("Failed to save woken entries: \(error.localizedDescription)")
            }
            for entry in woken {
                NotificationService.shared.sync(entry, preferences: notifPrefs)
            }
        }
    }

    private func openTopUp() {
        Task { @MainActor in
            await loadTopUpProducts()
        }
    }

    private func loadTopUpProducts() async {
        if isLoadingTopUpProducts { return }
        isLoadingTopUpProducts = true
        defer { isLoadingTopUpProducts = false }

        do {
            let products = try await topUpService.loadProducts()
            topUpPacks = products.enumerated().map { index, product in
                CreditPack(
                    credits: Int(product.credits),
                    price: product.priceText,
                    isPopular: index == 1,
                    isBestValue: index == (products.count - 1)
                )
            }
            topUpProductIDByCredits = Dictionary(
                uniqueKeysWithValues: products.map { ($0.credits, $0.id) }
            )
        } catch {
            topUpPacks = []
            topUpProductIDByCredits = [:]
            showToast("Failed to load purchases: \(error.localizedDescription)", type: .error)
        }
    }

    func updateDisclosureLevel() {
        let level = DisclosureLevel.from(entryCount: activeEntries.count)
        if level > appState.disclosureLevel {
            withAnimation {
                appState.disclosureLevel = level
            }
        }
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
