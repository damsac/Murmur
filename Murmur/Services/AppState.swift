import Foundation
import Observation
import MurmurCore

enum RecordingState {
    case idle
    case recording
    case processing
}

enum RecentInsert: Identifiable {
    case entry(UUID)
    case message(String, UUID)

    var id: String {
        switch self {
        case .entry(let uuid): return "recent-entry-\(uuid.uuidString)"
        case .message(_, let uuid): return "recent-msg-\(uuid.uuidString)"
        }
    }
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

    // Home composition
    var homeComposition: HomeComposition?
    var isHomeCompositionLoading: Bool = false
    private var homeCompositionStore: HomeCompositionStore?

    // Recent inserts — entries/messages created since last composition (ephemeral, in-memory only)
    var recentInserts: [RecentInsert] = []

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
        homeCompositionStore = HomeCompositionStore()

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

    func invalidateDailyFocus() {
        dailyFocus = nil
        isFocusLoading = false
        dailyFocusStore?.clear()
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
            : "Focus on these things today."
        return DailyFocus(items: items, message: message)
    }

    func invalidateHomeComposition() {
        homeComposition = nil
        isHomeCompositionLoading = false
        homeCompositionStore?.clear()
        recentInserts.removeAll()
    }

    func addRecentEntry(_ id: UUID) {
        recentInserts.insert(.entry(id), at: 0)
    }

    func addRecentMessage(_ text: String) {
        recentInserts.insert(.message(text, UUID()), at: 0)
    }

    func requestHomeComposition(entries: [Entry]) async {
        // Check cache first
        if let cached = homeCompositionStore?.load(), cached.isFromToday {
            homeComposition = cached
            return
        }

        guard let llmService, let creditGate else {
            homeComposition = buildDeterministicComposition(entries: entries)
            return
        }

        isHomeCompositionLoading = true
        defer { isHomeCompositionLoading = false }

        do {
            let authorization = try await creditGate.authorize()
            let agentEntries = entries.map { $0.toAgentContext() }
            let composition = try await llmService.composeHomeView(entries: agentEntries)

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

            try? homeCompositionStore?.save(composition)
            homeComposition = composition
        } catch {
            homeComposition = buildDeterministicComposition(entries: entries)
        }
    }

    private func buildDeterministicComposition(entries: [Entry]) -> HomeComposition {
        let now = Date()
        var sections: [ComposedSection] = []

        // Section 1: "Needs attention" — overdue, P1/P2, due today
        var attentionItems: [ComposedItem] = []
        for entry in entries {
            let isOverdue = entry.dueDate.map { $0 < now } ?? false
            let isHighPriority = (entry.priority ?? Int.max) <= 2
            let isDueToday = entry.dueDate.map { Calendar.current.isDateInToday($0) } ?? false

            if isOverdue {
                attentionItems.append(.entry(ComposedEntry(
                    id: entry.shortID,
                    emphasis: .hero,
                    badge: "Overdue"
                )))
            } else if isHighPriority {
                attentionItems.append(.entry(ComposedEntry(
                    id: entry.shortID,
                    emphasis: .standard,
                    badge: "P\(entry.priority ?? 1)"
                )))
            } else if isDueToday {
                attentionItems.append(.entry(ComposedEntry(
                    id: entry.shortID,
                    emphasis: .standard,
                    badge: "Today"
                )))
            }
        }
        if !attentionItems.isEmpty {
            sections.append(ComposedSection(
                title: "Needs attention",
                density: .relaxed,
                items: attentionItems
            ))
        }

        // Section 2: "Recent" — last 5 created entries as compact
        let recentEntries = entries
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(5)
        var recentItems: [ComposedItem] = []
        for entry in recentEntries {
            // Skip entries already shown in attention section
            let alreadyShown = attentionItems.contains { item in
                if case .entry(let composed) = item {
                    return composed.id == entry.shortID
                }
                return false
            }
            if !alreadyShown {
                recentItems.append(.entry(ComposedEntry(
                    id: entry.shortID,
                    emphasis: .compact
                )))
            }
        }
        if !recentItems.isEmpty {
            sections.append(ComposedSection(
                title: "Recent",
                density: .compact,
                items: recentItems
            ))
        }

        return HomeComposition(sections: sections, composedAt: now)
    }

    func applyTopUp(credits: Int64) async throws {
        guard let creditGate else { return }
        try await creditGate.topUp(credits: credits)
        await refreshCreditBalance()
    }
}
