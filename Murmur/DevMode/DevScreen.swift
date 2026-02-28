import SwiftUI
import MurmurCore

enum DevScreen: String, CaseIterable, Identifiable {
    // Onboarding
    case onboardingTranscript = "Onboarding: Transcript"
    case onboardingProcessing = "Onboarding: Processing"
    case onboardingFlow = "Onboarding: Flow"

    // Home
    case void = "Home: Empty"
    case voidRecording = "Recording"
    case voidProcessing = "Processing"
    case successToast = "Success Toast"
    case homeAI = "Home (AI Composed)"
    case entryDetail = "Entry Detail"
    case entryDetailVariants = "Entry Detail (Variants)"
    case swipeActions = "Swipe Actions"

    // Views & Settings
    case viewsGrid = "Views Grid"
    case todoView = "Todo View"
    case ideasView = "Ideas View"
    case remindersView = "Reminders View"
    case settingsFull = "Settings (Full)"

    // Top-Up & Recording
    case topUp = "Top-Up"
    case recordingLive = "Recording (Live Feed)"

    // Edge Cases & Errors
    case outOfCredits = "Error: Out of Credits"
    case micDenied = "Error: Mic Denied"
    case apiError = "Error: API Error"
    case lowTokens = "Warning: Low Tokens"
    case deleteConfirm = "Dialog: Delete Confirm"

    // Empty States
    case emptyTodo = "Empty: Todo View"
    case emptyIdeas = "Empty: Ideas"
    case emptyReminders = "Empty: Reminders"
    case emptyHome = "Empty: Home"

    var id: String { rawValue }

    @ViewBuilder
    var view: some View {
        let mockAppState = AppState()

        Group {
            switch self {
            // Onboarding
            case .onboardingTranscript:
                OnboardingTranscriptView(
                    transcript: "hmm I keep forgetting things... I should try capturing ideas when they come up",
                    onComplete: {}
                )
            case .onboardingProcessing:
                ProcessingView(
                    transcript: "hmm I keep forgetting things..."
                )
            case .onboardingFlow:
                OnboardingFlowView(onComplete: {})

            // Home (Empty)
            case .void:
                HomeView(
                    inputText: .constant(""),
                    entries: [],
                    onMicTap: {},
                    onSubmit: {},
                    onEntryTap: { _ in },
                    onSettingsTap: {},
                    onAction: { _, _ in }
                )
            case .voidRecording:
                RecordingView(
                    transcript: .constant("I need to pick up dry cleaning..."),
                    onStop: {}
                )
            case .voidProcessing:
                ProcessingView(
                    transcript: "I need to pick up dry cleaning"
                )
            case .successToast:
                ZStack {
                    Theme.Colors.bgDeep.ignoresSafeArea()
                    VStack {
                        ToastView(
                            message: "Entry saved",
                            type: .success
                        )
                        .padding(.top, 60)
                        Spacer()
                    }
                }

            // Home (with entries)
            case .homeAI:
                HomeView(
                    inputText: .constant(""),
                    entries: MockDataService.entriesForLevel2(),
                    onMicTap: {},
                    onSubmit: {},
                    onEntryTap: { _ in },
                    onSettingsTap: {},
                    onAction: { _, _ in }
                )
            case .entryDetail:
                EntryDetailView(
                    entry: Entry(
                        transcript: "",
                        content: "Review design system and provide feedback",
                        category: .todo,
                        sourceText: "",
                        summary: "Review design system and provide feedback",
                        priority: 1
                    ),
                    onBack: {},
                    onViewTranscript: {},
                    onArchive: {},
                    onSnooze: {},
                    onDelete: {}
                )
            case .entryDetailVariants:
                EntryDetailView(
                    entry: Entry(
                        transcript: "",
                        content: "Voice-controlled home garden watering system",
                        category: .idea,
                        sourceText: "",
                        summary: "Voice-controlled home garden watering system"
                    ),
                    onBack: {},
                    onViewTranscript: {},
                    onArchive: {},
                    onSnooze: {},
                    onDelete: {}
                )
            case .swipeActions:
                HomeView(
                    inputText: .constant(""),
                    entries: MockDataService.entriesForLevel2(),
                    onMicTap: {},
                    onSubmit: {},
                    onEntryTap: { _ in },
                    onSettingsTap: {},
                    onAction: { _, _ in }
                )
            // Views & Settings
            case .viewsGrid:
                ViewsGridView(
                    onViewSelected: { _ in },
                    onCreateView: {},
                    onDismiss: {}
                )
            case .todoView:
                CategoryListView(
                    category: .todo,
                    entries: MockDataService.entriesForLevel2().filter { $0.category == .todo },
                    onBack: {},
                    onEntryTap: { _ in },
                    onToggleComplete: { _ in },
                    onMarkDone: { _ in },
                    onSnooze: { _ in },
                    onDelete: { _ in }
                )
            case .ideasView:
                CategoryListView(
                    category: .idea,
                    entries: MockDataService.entriesForLevel2().filter { $0.category == .idea },
                    onBack: {},
                    onEntryTap: { _ in },
                    onToggleComplete: { _ in },
                    onMarkDone: { _ in },
                    onSnooze: { _ in },
                    onDelete: { _ in }
                )
            case .remindersView:
                CategoryListView(
                    category: .reminder,
                    entries: MockDataService.entriesForLevel2().filter { $0.category == .reminder },
                    onBack: {},
                    onEntryTap: { _ in },
                    onToggleComplete: { _ in },
                    onMarkDone: { _ in },
                    onSnooze: { _ in },
                    onDelete: { _ in }
                )
            case .settingsFull:
                SettingsFullView(
                    onBack: {},
                    onTopUp: {},
                    onManageViews: {},
                    onExportData: {},
                    onClearData: {},
                    onOpenSourceLicenses: {}
                )

            // Top-Up & Recording
            case .topUp:
                TopUpView(
                    onBack: {},
                    onPurchase: { _ in }
                )
            case .recordingLive:
                LiveFeedRecordingView(onStopRecording: {})

            // Errors & Edge Cases
            case .outOfCredits:
                OutOfCreditsView(
                    transcript: "I need to pick up dry cleaning",
                    duration: 8,
                    onTopUp: {},
                    onSaveRaw: {}
                )
            case .micDenied:
                MicDeniedView(onOpenSettings: {})
            case .apiError:
                APIErrorView(
                    duration: 12,
                    inputTokens: 247,
                    onRetry: {},
                    onSaveRaw: {},
                    onDismiss: {}
                )
            case .lowTokens:
                ZStack {
                    Theme.Colors.bgDeep.ignoresSafeArea()
                    VStack {
                        Spacer()
                        LowTokensView(
                            balance: 312,
                            estimatedRecordingsLeft: 3,
                            onTopUp: {}
                        )
                        .padding(.horizontal, Theme.Spacing.screenPadding)
                        Spacer()
                    }
                }
            case .deleteConfirm:
                DeleteConfirmDialog(onDelete: {}, onCancel: {})

            // Empty States
            case .emptyTodo:
                EmptyStateView(type: .todo)
            case .emptyIdeas:
                EmptyStateView(type: .ideas)
            case .emptyReminders:
                EmptyStateView(type: .reminders)
            case .emptyHome:
                EmptyStateView(type: .home, onAction: {})

            }
        }
        .environment(mockAppState)
    }
}
