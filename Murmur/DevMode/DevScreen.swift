import SwiftUI
import MurmurCore

// swiftlint:disable:next type_body_length
enum DevScreen: String, CaseIterable, Identifiable {
    // Onboarding (Pre-L0)
    case onboardingTranscript = "Onboarding: Transcript"
    case onboardingProcessing = "Onboarding: Processing"
    case onboardingConfirm = "Onboarding: Confirm"
    case onboardingFlow = "Onboarding: Flow"

    // Level 0: The Void
    case void = "L0: Void"
    case voidRecording = "L0: Recording"
    case voidProcessing = "L0: Processing"
    case voidConfirm = "L0: Confirm"
    case voidTextProcessing = "L0: Text Processing"
    case voidTextConfirm = "L0: Text Confirm"
    case settingsMinimal = "L0: Settings (Minimal)"

    // Level 1: First Light
    case homeSparse = "L1: Home (Sparse)"
    case focusTodo = "L1: Focus Card (Todo)"
    case focusInsight = "L1: Focus Card (Insight)"
    case focusDismissed = "L1: Focus Card (Dismissed)"
    case successToast = "L1: Success Toast"

    // Level 2: Grid Awakens
    case homeAI = "L2: Home (AI Composed)"
    case entryDetail = "L2: Entry Detail"
    case entryDetailVariants = "L2: Entry Detail (Variants)"
    case swipeActions = "L2: Swipe Actions"
    case keyboardOpen = "L2: Keyboard Input"

    // Level 3: Views Emerge
    case viewsGrid = "L3: Views Grid"
    case todoView = "L3: Todo View"
    case ideasView = "L3: Ideas View"
    case remindersView = "L3: Reminders View"
    case settingsFull = "L3: Settings (Full)"

    // Level 4: Full Power
    case topUp = "L4: Top-Up"
    case recordingLive = "L4: Recording (Live Feed)"

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

    var level: DisclosureLevel {
        switch self {
        case .onboardingTranscript, .onboardingProcessing, .onboardingConfirm, .onboardingFlow:
            return .void

        case .void, .voidRecording, .voidProcessing, .voidConfirm, .voidTextProcessing, .voidTextConfirm, .settingsMinimal:
            return .void

        case .homeSparse, .focusTodo, .focusInsight, .focusDismissed, .successToast:
            return .firstLight

        case .homeAI, .entryDetail, .entryDetailVariants, .swipeActions, .keyboardOpen:
            return .gridAwakens

        case .viewsGrid, .todoView, .ideasView, .remindersView, .settingsFull:
            return .viewsEmerge

        case .topUp, .recordingLive:
            return .fullPower

        case .outOfCredits, .micDenied, .apiError, .lowTokens, .deleteConfirm, .emptyTodo, .emptyIdeas, .emptyReminders, .emptyHome, .confirmCards, .confirmSingle, .voiceCorrection:
            return .void
        }
    }

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

            // Level 0
            case .void:
                VoidView(
                    inputText: .constant(""),
                    onMicTap: {},
                    onSubmit: {},
                    onSettingsTap: {}
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
            case .settingsMinimal:
                SettingsMinimalView(
                    onBack: {},
                    onTopUp: {}
                )

            // Level 1
            case .homeSparse:
                HomeSparseView(
                    inputText: .constant(""),
                    entries: MockDataService.entriesForLevel1(),
                    onMicTap: {},
                    onSubmit: {},
                    onEntryTap: { _ in }
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

            // Level 2
            case .homeAI:
                HomeAIComposedView(
                    inputText: .constant(""),
                    entries: MockDataService.entriesForLevel2(),
                    onMicTap: {},
                    onSubmit: {},
                    onEntryTap: { _ in },
                    onSettingsTap: {},
                    onViewsTap: {}
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
                HomeAIComposedView(
                    inputText: .constant(""),
                    entries: MockDataService.entriesForLevel2(),
                    onMicTap: {},
                    onSubmit: {},
                    onEntryTap: { _ in },
                    onSettingsTap: {},
                    onViewsTap: {}
                )
            case .keyboardOpen:
                MainTabView()

            // Level 3
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
                    onManageViews: {},
                    onExportData: {},
                    onClearData: {},
                    onOpenSourceLicenses: {}
                )

            // Level 4
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
