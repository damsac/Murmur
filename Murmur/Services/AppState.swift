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
    var isDevMode: Bool = false

    // Pipeline
    var pipeline: Pipeline?
    var pipelineError: String?
    var creditGate: LocalCreditGate?
    var creditBalance: Int64 = 0
    private(set) var llmService: PPQLLMService?
    var memoryStore: AgentMemoryStore?

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

    func applyTopUp(credits: Int64) async throws {
        guard let creditGate else { return }
        try await creditGate.topUp(credits: credits)
        await refreshCreditBalance()
    }
}
