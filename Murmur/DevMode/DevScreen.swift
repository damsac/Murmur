import SwiftUI
import MurmurCore

enum DevScreen: String, CaseIterable, Identifiable {
    // Onboarding
    case onboardingTranscript = "Onboarding: Transcript"
    case onboardingProcessing = "Onboarding: Processing"
    case onboardingConfirm = "Onboarding: Confirm"
    case onboardingFlow = "Onboarding: Flow"

    // Home
    case void = "Home: Empty"
    case voidRecording = "Recording"
    case voidProcessing = "Processing"
    case voidConfirm = "Confirm"
    case voidTextProcessing = "Text Processing"
    case voidTextConfirm = "Text Confirm"
    case focusTodo = "Focus Card (Todo)"
    case focusInsight = "Focus Card (Insight)"
    case focusDismissed = "Focus Card (Dismissed)"
    case successToast = "Success Toast"
    case homeAI = "Home (AI Composed)"
    case entryDetail = "Entry Detail"
    case entryDetailVariants = "Entry Detail (Variants)"
    case swipeActions = "Swipe Actions"
    case keyboardOpen = "Keyboard Input"

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

    // Confirm Flows
    case confirmCards = "Confirm: Cards Flow"
    case confirmSingle = "Confirm: Single Item"
    case voiceCorrection = "Confirm: Voice Correction"

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
                    entries: [
                        ExtractedEntry(
                            content: "Start capturing ideas as they come up",
                            category: .todo,
                            sourceText: "",
                            summary: "Start capturing ideas as they come up",
                            priority: 2
                        )
                    ],
                    transcript: "hmm I keep forgetting things..."
                )
            case .onboardingConfirm:
                ConfirmView(
                    entries: [
                        ExtractedEntry(
                            content: "Start capturing ideas as they come up",
                            category: .todo,
                            sourceText: "",
                            summary: "Start capturing ideas as they come up",
                            priority: 2
                        )
                    ],
                    onAccept: {},
                    onVoiceCorrect: { _ in },
                    onDiscard: { _ in }
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
                    entries: [
                        ExtractedEntry(content: "Pick up dry cleaning", category: .todo, sourceText: "", summary: "Pick up dry cleaning")
                    ],
                    transcript: "I need to pick up dry cleaning"
                )
            case .voidConfirm:
                ConfirmView(
                    entries: [
                        ExtractedEntry(content: "Pick up dry cleaning", category: .todo, sourceText: "", summary: "Pick up dry cleaning")
                    ],
                    onAccept: {},
                    onVoiceCorrect: { _ in },
                    onDiscard: { _ in }
                )
            case .voidTextProcessing:
                ProcessingView(
                    entries: [
                        ExtractedEntry(content: "Call dentist tomorrow", category: .reminder, sourceText: "", summary: "Call dentist tomorrow")
                    ],
                    transcript: "Call dentist tomorrow"
                )
            case .voidTextConfirm:
                ConfirmView(
                    entries: [
                        ExtractedEntry(content: "Call dentist tomorrow", category: .reminder, sourceText: "", summary: "Call dentist tomorrow")
                    ],
                    onAccept: {},
                    onVoiceCorrect: { _ in },
                    onDiscard: { _ in }
                )
            case .focusTodo:
                FocusCardView(
                    entry: Entry(
                        transcript: "",
                        content: "Review design mockups and provide feedback",
                        category: .todo,
                        sourceText: "",
                        summary: "Review design mockups and provide feedback",
                        priority: 1
                    ),
                    onMarkDone: {},
                    onSnooze: {},
                    onDismiss: {}
                )
            case .focusInsight:
                FocusCardView(
                    entry: Entry(
                        transcript: "",
                        content: "The best interfaces are invisible",
                        category: .thought,
                        sourceText: "",
                        summary: "The best interfaces are invisible"
                    ),
                    onMarkDone: nil,
                    onSnooze: nil,
                    onDismiss: {}
                )
            case .focusDismissed:
                FocusCardView(
                    entry: Entry(
                        transcript: "",
                        content: "Team standup at 10am",
                        category: .reminder,
                        sourceText: "",
                        summary: "Team standup at 10am"
                    ),
                    onMarkDone: {},
                    onSnooze: {},
                    onDismiss: {}
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
            case .keyboardOpen:
                MainTabView()

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

            // Confirm Flows
            case .confirmCards:
                ConfirmCardsView(
                    transcript: "I need to pick up dry cleaning before six, oh and remind me about the DMV on Thursday",
                    duration: 12,
                    items: [
                        ConfirmItem(category: .todo, summary: "Pick up dry cleaning before 6pm", priority: "High", dueDate: "Today, 6:00 PM"),
                        ConfirmItem(category: .reminder, summary: "DMV appointment Thursday", priority: nil, dueDate: "In 2 days")
                    ],
                    onAccept: { _ in },
                    onDiscard: { _ in },
                    onCorrect: { _ in },
                    onComplete: {}
                )
            case .confirmSingle:
                ConfirmSingleView(
                    transcript: "Remind me to call the dentist tomorrow morning",
                    duration: 5,
                    items: [
                        ConfirmItem(category: .todo, summary: "Call the dentist", priority: nil, dueDate: "Tomorrow morning")
                    ],
                    inputTokens: 82,
                    outputTokens: 94,
                    onAccept: {},
                    onDiscard: {},
                    onCorrect: { _ in }
                )
            case .voiceCorrection:
                VoiceCorrectionView(
                    transcript: "...remind me about the DMV on Thursday...",
                    duration: 12,
                    items: [
                        ConfirmItem(category: .todo, summary: "Pick up dry cleaning before 6pm", priority: nil, dueDate: nil),
                        ConfirmItem(category: .reminder, summary: "DMV appointment Thursday", priority: nil, dueDate: nil),
                        ConfirmItem(category: .idea, summary: "App that turns grocery receipts into meal plans", priority: nil, dueDate: nil)
                    ],
                    editingIndex: 1,
                    correctionDuration: 3,
                    correctionTranscript: "Actually it's not Thursday, it's next Friday the",
                    onFinishCorrection: {},
                    onCancelCorrection: {}
                )
            }
        }
        .environment(mockAppState)
    }
}
