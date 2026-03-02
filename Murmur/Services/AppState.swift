import Foundation
import Observation
import MurmurCore

enum RecordingState {
    case idle
    case recording
    case processing
}

@Observable
@MainActor
final class AppState {
    var recordingState: RecordingState = .idle
    var showOnboarding: Bool = false
    var showFocusCard: Bool = false
    #if DEBUG
    var isDevMode: Bool = true
    #else
    var isDevMode: Bool = false
    #endif

    // Pipeline
    var pipeline: Pipeline?
    var pipelineError: String?
    var creditGate: LocalCreditGate?
    var creditBalance: Int64 = 0
    private(set) var llmService: PPQLLMService?
    var memoryStore: AgentMemoryStore?

    // Daily focus
    var dailyFocus: DailyFocus?
    var isFocusLoading: Bool = false
    var dailyFocusStore: DailyFocusStore?

    // Lazy conversation state — only allocated on first access
    private var _conversation: ConversationState?
    var conversation: ConversationState {
        if _conversation == nil {
            let state = ConversationState()
            state.appState = self
            _conversation = state
        }
        return _conversation!
    }

    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    init() {}

    /// Configure the real MurmurCore pipeline — no persistence dependency.
    func configurePipeline() {
        guard let apiKey = APIKeyProvider.ppqAPIKey else {
            pipelineError = "No PPQ API key configured"
            print("⚠️ Pipeline not configured — missing PPQ_API_KEY")
            return
        }

        let transcriber = AppleSpeechTranscriber()
        let llm = PPQLLMService(apiKey: apiKey)
        let gate = LocalCreditGate(starterCredits: 1_000)
        let pricing = ServicePricing(
            // Claude Haiku style baseline pricing; replaced with model catalog later.
            inputUSDPer1MMicros: 1_000_000,
            outputUSDPer1MMicros: 5_000_000,
            minimumChargeCredits: 1
        )
        pipeline = Pipeline(
            transcriber: transcriber,
            llm: llm,
            creditGate: gate,
            llmPricing: pricing
        )
        creditGate = gate
        llmService = llm

        let store = AgentMemoryStore()
        memoryStore = store
        llm.agentMemory = store.load()

        dailyFocusStore = DailyFocusStore()

        Task { @MainActor in
            await refreshCreditBalance()
        }
    }

    func refreshCreditBalance() async {
        guard let creditGate else {
            creditBalance = 0
            return
        }
        creditBalance = await creditGate.balance
    }

    func requestDailyFocus(entries: [Entry]) async {
        // Check cache first
        if let cached = dailyFocusStore?.load(), cached.isFromToday {
            dailyFocus = cached
            return
        }

        guard let llmService, let creditGate else {
            dailyFocus = buildDeterministicFocus(entries: entries)
            return
        }

        isFocusLoading = true
        defer { isFocusLoading = false }

        do {
            let authorization = try await creditGate.authorize()
            let agentEntries = entries.map { $0.toAgentContext() }
            let focus = try await llmService.composeDailyFocus(entries: agentEntries)

            let pricing = ServicePricing(
                inputUSDPer1MMicros: 1_000_000,
                outputUSDPer1MMicros: 5_000_000,
                minimumChargeCredits: 1
            )
            _ = try await creditGate.charge(
                authorization,
                usage: TokenUsage(inputTokens: 200, outputTokens: 100),
                pricing: pricing
            )
            await refreshCreditBalance()

            try? dailyFocusStore?.save(focus)
            dailyFocus = focus
        } catch {
            dailyFocus = buildDeterministicFocus(entries: entries)
        }
    }

    private func buildDeterministicFocus(entries: [Entry]) -> DailyFocus {
        let now = Date()
        var focusEntries: [(entry: Entry, reason: String)] = []

        for entry in entries {
            let isOverdue = entry.dueDate.map { $0 < now } ?? false
            let isHighPriority = (entry.priority ?? Int.max) <= 2
            if isOverdue {
                focusEntries.append((entry, "Overdue"))
            } else if isHighPriority {
                focusEntries.append((entry, "P\(entry.priority ?? 1)"))
            }
        }

        // Sort: overdue first, then by priority
        focusEntries.sort { lhs, rhs in
            let lo = lhs.entry.dueDate.map { $0 < now } ?? false
            let ro = rhs.entry.dueDate.map { $0 < now } ?? false
            if lo != ro { return lo }
            let pa = lhs.entry.priority ?? Int.max
            let pb = rhs.entry.priority ?? Int.max
            return pa < pb
        }

        let items = focusEntries.prefix(3).map { FocusItem(id: $0.entry.shortID, reason: $0.reason) }
        let message = items.isEmpty
            ? "All clear — nothing pressing today."
            : "\(Greeting.current). Focus on these things today."
        return DailyFocus(items: items, message: message)
    }

    func applyTopUp(credits: Int64) async throws {
        guard let creditGate else { return }
        try await creditGate.topUp(credits: credits)
        await refreshCreditBalance()
    }
}
