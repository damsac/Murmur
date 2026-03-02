import SwiftUI
import SwiftData
import MurmurCore

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(NotificationPreferences.self) private var notifPrefs
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @State private var selectedEntry: Entry?
    @State private var inputText = ""
    @State private var toastConfig: ToastContainer.ToastConfig?
    @State private var showDevMode = false
    @State private var showTextInputBar = false
    @State private var showSettings = false
    @State private var showTopUp = false
    @State private var isPurchasingTopUp = false
    @State private var isLoadingTopUpProducts = false
    @State private var topUpPacks: [CreditPack] = []
    @State private var topUpProductIDByCredits: [Int64: String] = [:]
    @State private var pendingDeleteEntry: Entry?
    @State private var pendingDeleteTask: Task<Void, Never>?
    @State private var snoozeEntry: Entry?
    @State private var showSnoozeDialog = false
    @State private var showCustomSnoozeSheet = false
    private let topUpService = StoreKitTopUpService()

    var body: some View {
        ZStack {
            // Main content based on selected tab
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

            // Conversation overlays
            if !appState.showOnboarding {
                let conversation = appState.conversation
                if conversation.isRecording {
                    ListeningGlowView()
                        .zIndex(20)
                }
                if conversation.isRecording || conversation.isProcessing || conversation.agentStreamText != nil {
                    let transcript = conversation.displayTranscript ?? ""
                    AgentStreamOverlay(
                        transcript: transcript,
                        responseText: conversation.agentStreamText,
                        isRecording: conversation.isRecording,
                        onDismiss: { conversation.agentStreamText = nil }
                    )
                    .transition(.opacity)
                    .zIndex(30)
                }
            }

        }
        .toast($toastConfig, onUndo: handleUndo)
        #if DEBUG
        .sheet(isPresented: $showDevMode) {
            DevModeView()
        }
        #endif
        .sheet(item: $selectedEntry) { entry in
            EntryDetailView(
                entry: entry,
                onBack: { selectedEntry = nil },
                onViewTranscript: {},
                onAction: { action in
                    selectedEntry = nil
                    handleEntryAction(entry, action)
                }
            )
            .environment(appState)
            .environment(notifPrefs)
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
        .confirmationDialog("Snooze until...", isPresented: $showSnoozeDialog) {
            Button("In 1 hour") {
                performSnooze(.hour, value: 1)
            }
            Button("Tomorrow morning") {
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                let date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)
                commitSnooze(until: date)
            }
            Button("Next week") {
                performSnooze(.weekOfYear, value: 1)
            }
            Button("Custom time...") {
                showCustomSnoozeSheet = true
            }
            Button("Cancel", role: .cancel) {
                snoozeEntry = nil
            }
        }
        .sheet(isPresented: $showCustomSnoozeSheet, onDismiss: { snoozeEntry = nil }) {
            SnoozePickerSheet(
                onSave: { date in
                    commitSnooze(until: date)
                    showCustomSnoozeSheet = false
                },
                onDismiss: { showCustomSnoozeSheet = false }
            )
        }
        .onAppear {
            wakeUpSnoozedEntries()
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
        homeContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.bgDeep)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                let conversation = appState.conversation
                BottomNavBar(
                    isRecording: conversation.isRecording,
                    isProcessing: conversation.isProcessing,
                    showTextInput: showTextInputBar,
                    inputText: $inputText,
                    onMicTap: {
                        if conversation.isRecording {
                            conversation.stopRecording(
                                entries: entries,
                                modelContext: modelContext,
                                preferences: notifPrefs
                            )
                        } else {
                            conversation.startRecording()
                        }
                    },
                    onKeyboardTap: { showTextInputBar = true },
                    onTextSubmit: {
                        conversation.inputText = inputText
                        inputText = ""
                        showTextInputBar = false
                        conversation.submitText(
                            entries: entries,
                            modelContext: modelContext,
                            preferences: notifPrefs
                        )
                    },
                    onDismissTextInput: {
                        showTextInputBar = false
                        inputText = ""
                    }
                )
            }
            .ignoresSafeArea(.keyboard)
            .sheet(isPresented: $showSettings) {
                SettingsFullView(
                    onBack: { showSettings = false },
                    onTopUp: {
                        openTopUp()
                        showTopUp = true
                    }
                )
            }
    }

    // MARK: - Home Content

    @ViewBuilder
    private var homeContent: some View {
        let conversation = appState.conversation
        HomeView(
            inputText: $inputText,
            entries: activeEntries,
            onMicTap: {
                if conversation.isRecording {
                    conversation.stopRecording(
                        entries: entries,
                        modelContext: modelContext,
                        preferences: notifPrefs
                    )
                } else {
                    conversation.startRecording()
                }
            },
            onSubmit: {
                conversation.inputText = inputText
                inputText = ""
                conversation.submitText(
                    entries: entries,
                    modelContext: modelContext,
                    preferences: notifPrefs
                )
            },
            onEntryTap: { entry in selectedEntry = entry },
            onSettingsTap: { showSettings = true },
            onAction: { entry, action in
                handleEntryAction(entry, action)
            }
        )
    }

    // MARK: - Actions

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

    private func handleUndo(_ undo: UndoTransaction) {
        undo.execute(entries: entries, context: modelContext, preferences: notifPrefs)
        showToast("Undone", type: .info)
    }

    private func handleEntryAction(_ entry: Entry, _ action: EntryAction) {
        switch action {
        case .complete:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            entry.perform(.complete, in: modelContext, preferences: notifPrefs)
            showToast("Completed")

        case .archive:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            entry.perform(.archive, in: modelContext, preferences: notifPrefs)
            showToast("Archived", type: .info)

        case .unarchive:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            entry.perform(.unarchive, in: modelContext, preferences: notifPrefs)
            showToast("Restored")

        case .delete:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            pendingDeleteTask?.cancel()
            pendingDeleteEntry = entry
            showToast("Deleted", type: .warning, actionLabel: "Undo") {
                pendingDeleteTask?.cancel()
                pendingDeleteEntry = nil
            }
            pendingDeleteTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(4))
                guard let pending = pendingDeleteEntry else { return }
                pending.perform(.delete, in: modelContext, preferences: notifPrefs)
                pendingDeleteEntry = nil
            }

        case .checkOffHabit:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            entry.perform(.checkOffHabit, in: modelContext, preferences: notifPrefs)

        case .snooze(nil):
            snoozeEntry = entry
            showSnoozeDialog = true

        case .snooze(let until):
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            entry.perform(.snooze(until: until), in: modelContext, preferences: notifPrefs)
            showToast("Snoozed", type: .info)
        }
    }

    private func showToast(
        _ message: String,
        type: ToastView.ToastType = .success,
        actionLabel: String? = nil,
        action: (() -> Void)? = nil
    ) {
        toastConfig = ToastContainer.ToastConfig(
            message: message,
            type: type,
            duration: action != nil ? 4.0 : 3.0,
            actionLabel: actionLabel,
            action: action
        )
    }

}

// MARK: - Helpers

private extension RootView {
    var activeEntries: [Entry] {
        entries.filter {
            $0.status == .active && $0.persistentModelID != pendingDeleteEntry?.persistentModelID
        }
    }

    func performSnooze(_ component: Calendar.Component, value: Int) {
        let date = Calendar.current.date(byAdding: component, value: value, to: Date())
        commitSnooze(until: date)
    }

    func commitSnooze(until date: Date?) {
        guard let entry = snoozeEntry else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        entry.perform(.snooze(until: date), in: modelContext, preferences: notifPrefs)
        showToast("Snoozed", type: .info)
        snoozeEntry = nil
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

}

#Preview("Empty") {
    @Previewable @State var appState = AppState()

    return RootView()
        .environment(appState)
}

#Preview("With Onboarding") {
    @Previewable @State var appState = AppState()

    appState.showOnboarding = true

    return RootView()
        .environment(appState)
}

#Preview("Recording State") {
    @Previewable @State var appState = AppState()

    return RootView()
        .environment(appState)
}
