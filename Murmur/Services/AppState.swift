import Foundation
import Observation
import SwiftUI
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
    enum Tab { case focus, all }
    var recordingState: RecordingState = .idle
    var showOnboarding: Bool = false
    var showFocusCard: Bool = false
    var selectedTab: Tab = .focus
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

    // Home composition
    var homeComposition: HomeComposition?
    var isHomeCompositionLoading: Bool = false
    private(set) var homeCompositionStore: HomeCompositionStore?

    // Session tracking — composition is "fresh" for current session
    private(set) var currentSessionID: UUID = UUID()
    var refreshTask: Task<Void, Never>?

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

        homeCompositionStore = HomeCompositionStore()

        // One-time cleanup of orphaned DailyFocus cache
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: docs.appendingPathComponent("daily-focus.json"))

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

    // MARK: - Session

    func startNewSession() {
        refreshTask?.cancel()
        currentSessionID = UUID()
    }

    func resetConversation() {
        _conversation = nil
    }

    // MARK: - Home Composition

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

    /// Remove entries from recentInserts that have been placed in the layout by update_layout.
    func clearRecentInsertForEntry(shortID: String, entries: [Entry]) {
        guard let entry = Entry.resolve(shortID: shortID, in: entries) else { return }
        recentInserts.removeAll { insert in
            if case .entry(let uuid) = insert {
                return uuid == entry.id
            }
            return false
        }
    }

    func requestHomeComposition(entries: [Entry], variant: CompositionVariant) async {
        // Deduplicate: skip if already loading a fresh composition
        guard !isHomeCompositionLoading else { return }

        // Set variant on LLM service
        llmService?.compositionVariant = variant

        // Check cache (variant-aware)
        if let cached = homeCompositionStore?.load(expectedVariant: variant), cached.isFromToday {
            homeComposition = cached
            // Background diff refresh
            requestLayoutRefresh(entries: entries, variant: variant)
            return
        }

        guard let llmService, let creditGate else {
            homeComposition = buildDeterministicComposition(entries: entries, variant: variant)
            return
        }

        isHomeCompositionLoading = true
        defer { isHomeCompositionLoading = false }

        do {
            let authorization = try await creditGate.authorize()
            let agentEntries = entries.map { $0.toAgentContext() }
            let composition = try await llmService.composeHomeView(
                entries: agentEntries,
                variant: variant
            )

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
            homeComposition = buildDeterministicComposition(entries: entries, variant: variant)
        }
    }

    // MARK: - Layout Refresh

    func requestLayoutRefresh(entries: [Entry], variant: CompositionVariant) {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            guard let self,
                  let llmService = self.llmService,
                  let creditGate = self.creditGate,
                  let currentComposition = self.homeComposition else { return }

            do {
                let authorization = try await creditGate.authorize()
                let agentEntries = entries.map { $0.toAgentContext() }
                let operations = try await llmService.refreshLayout(
                    entries: agentEntries,
                    currentLayout: currentComposition,
                    variant: variant
                )

                try Task.checkCancellation()

                guard !operations.isEmpty else { return }

                let pricing = ServicePricing(
                    inputUSDPer1MMicros: 1_000_000,
                    outputUSDPer1MMicros: 5_000_000,
                    minimumChargeCredits: 1
                )
                _ = try await creditGate.charge(
                    authorization,
                    usage: TokenUsage(inputTokens: 300, outputTokens: 50),
                    pricing: pricing
                )
                await self.refreshCreditBalance()

                _ = withAnimation(Animations.layoutSpring) {
                    self.homeComposition!.apply(operations: operations)
                }
                try? self.homeCompositionStore?.save(self.homeComposition!)
            } catch is CancellationError {
                // Variant switched during refresh — discard silently
            } catch {
                // Silent failure — layout stays as-is, still usable
            }
        }
    }

    // MARK: - Deterministic Fallback

    func buildDeterministicComposition(
        entries: [Entry],
        variant: CompositionVariant
    ) -> HomeComposition {
        switch variant {
        case .scanner:
            return buildScannerFallback(entries: entries)
        case .navigator:
            return buildNavigatorFallback(entries: entries)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func buildScannerFallback(entries: [Entry]) -> HomeComposition {
        let now = Date()
        var sections: [ComposedSection] = []

        let maxTotal = 7
        var totalCount = 0

        // Section 1: "Needs attention" — overdue, P1/P2, due today
        var attentionItems: [ComposedItem] = []
        for entry in entries {
            guard totalCount < maxTotal else { break }
            let isOverdue = entry.dueDate.map { $0 < now } ?? false
            let isHighPriority = (entry.priority ?? Int.max) <= 2
            let isDueToday = entry.dueDate.map { Calendar.current.isDateInToday($0) } ?? false

            if isOverdue {
                attentionItems.append(.entry(ComposedEntry(
                    id: entry.shortID,
                    emphasis: .hero,
                    badge: "Overdue"
                )))
                totalCount += 1
            } else if isHighPriority {
                attentionItems.append(.entry(ComposedEntry(
                    id: entry.shortID,
                    emphasis: .standard,
                    badge: "P\(entry.priority ?? 1)"
                )))
                totalCount += 1
            } else if isDueToday {
                attentionItems.append(.entry(ComposedEntry(
                    id: entry.shortID,
                    emphasis: .standard,
                    badge: "Today"
                )))
                totalCount += 1
            }
        }
        if !attentionItems.isEmpty {
            sections.append(ComposedSection(
                title: "Needs attention",
                density: .relaxed,
                items: attentionItems
            ))
        }

        // Section 2: "Recent" — fill remaining slots with recent entries
        let remaining = maxTotal - totalCount
        guard remaining > 0 else {
            return HomeComposition(sections: sections, composedAt: now, variant: .scanner)
        }
        let recentEntries = entries
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(remaining + attentionItems.count) // over-fetch to account for dedup
        var recentItems: [ComposedItem] = []
        for entry in recentEntries {
            guard recentItems.count < remaining else { break }
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

        return HomeComposition(sections: sections, composedAt: now, variant: .scanner)
    }

    private func buildNavigatorFallback(entries: [Entry]) -> HomeComposition {
        let now = Date()
        let categoryOrder: [EntryCategory] = [.todo, .reminder, .habit, .idea, .list, .note, .question]

        // Sort entries by priority then recency
        let sorted = entries.sorted { lhs, rhs in
            let pa = lhs.priority ?? Int.max
            let pb = rhs.priority ?? Int.max
            if pa != pb { return pa < pb }
            return lhs.createdAt > rhs.createdAt
        }

        // Group by category, take top entries, 7 total max
        var sections: [ComposedSection] = []
        var totalCount = 0
        let maxTotal = 7

        for category in categoryOrder {
            guard totalCount < maxTotal else { break }
            let catEntries = sorted.filter { $0.category == category }
            guard !catEntries.isEmpty else { continue }

            let remaining = maxTotal - totalCount
            let selected = Array(catEntries.prefix(remaining))
            let items: [ComposedItem] = selected.map { entry in
                let badge = badgeForEntry(entry, now: now)
                return .entry(ComposedEntry(
                    id: entry.shortID,
                    emphasis: .standard,
                    badge: badge
                ))
            }

            sections.append(ComposedSection(
                title: category.rawValue,
                density: .relaxed,
                items: items
            ))
            totalCount += selected.count
        }

        let briefing: String? = totalCount > 0
            ? "Here's what needs your attention today."
            : nil

        return HomeComposition(
            sections: sections,
            composedAt: now,
            briefing: briefing,
            variant: .navigator
        )
    }

    private func badgeForEntry(_ entry: Entry, now: Date) -> String? {
        if let dueDate = entry.dueDate {
            if dueDate < now { return "Overdue" }
            if Calendar.current.isDateInToday(dueDate) { return "Due today" }
        }
        if let p = entry.priority, p <= 2 { return "High priority" }
        // Recent = created in last 24h
        if now.timeIntervalSince(entry.createdAt) < 86400 { return "New" }
        return nil
    }

    func applyTopUp(credits: Int64) async throws {
        guard let creditGate else { return }
        try await creditGate.topUp(credits: credits)
        await refreshCreditBalance()
    }
}
