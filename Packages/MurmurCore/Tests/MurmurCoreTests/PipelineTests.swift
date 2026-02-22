import Foundation
import Testing
@testable import MurmurCore

@Suite("Pipeline", .serialized)
@MainActor
struct PipelineTests {
    var transcriber: MockTranscriber!
    var llm: MockLLMService!
    var pipeline: Pipeline!
    var creditGate: MockCreditGate!

    init() async throws {
        transcriber = MockTranscriber()
        llm = MockLLMService()
        creditGate = MockCreditGate()
        pipeline = Pipeline(transcriber: transcriber, llm: llm)
    }

    @Test("Start and stop recording creates entries")
    func recordingHappyPath() async throws {
        // Start recording
        try await pipeline.startRecording()
        #expect(await pipeline.isRecording == true)

        // Stop and process
        let result = try await pipeline.stopRecording()

        #expect(result.entries.count == 2)
        #expect(result.entries[0].content == "Buy milk")
        #expect(result.entries[0].category == .todo)
        #expect(result.entries[0].summary == "Pick up milk from the store")
        #expect(result.entries[1].content == "Finish the report")
        #expect(result.transcript.text == "Buy milk and finish the report")
    }

    @Test("stopRecording returns entries without persistence")
    func stopRecordingReturnsEntries() async throws {
        try await pipeline.startRecording()
        let result = try await pipeline.stopRecording()

        #expect(result.entries.count == 2)
        #expect(result.entries[0].content == "Buy milk")
    }

    @Test("Transcriber error is wrapped in PipelineError")
    func transcriberStartError() async throws {
        transcriber.errorToThrow = MockError.simulated

        await #expect(throws: PipelineError.self) {
            try await pipeline.startRecording()
        }
    }

    @Test("Cannot stop when not recording")
    func notRecording() async throws {
        await #expect(throws: PipelineError.self) {
            try await pipeline.stopRecording()
        }
    }

    @Test("Empty transcript throws error")
    func emptyTranscript() async throws {
        transcriber.transcriptToReturn = "   "

        try await pipeline.startRecording()

        await #expect(throws: PipelineError.self) {
            try await pipeline.stopRecording()
        }
    }

    @Test("Transcription error is wrapped")
    func transcriptionError() async throws {
        transcriber.errorToThrow = MockError.simulated

        await #expect(throws: PipelineError.self) {
            try await pipeline.startRecording()
        }
    }

    @Test("LLM extraction error is wrapped")
    func extractionError() async throws {
        llm.errorToThrow = MockError.simulated

        try await pipeline.startRecording()

        await #expect(throws: PipelineError.self) {
            try await pipeline.stopRecording()
        }
    }

    @Test("No extracted entries throws error")
    func noEntries() async throws {
        llm.entriesToReturn = []

        try await pipeline.startRecording()

        await #expect(throws: PipelineError.self) {
            try await pipeline.stopRecording()
        }
    }

    @Test("Text extraction happy path")
    func textExtractionHappyPath() async throws {
        let result = try await pipeline.extractFromText("Buy milk and finish the report")

        #expect(result.entries.count == 2)
        #expect(result.entries[0].content == "Buy milk")
        #expect(result.inputText == "Buy milk and finish the report")
    }

    @Test("Text extraction with empty input throws error")
    func textExtractionEmpty() async throws {
        await #expect(throws: PipelineError.self) {
            try await pipeline.extractFromText("   ")
        }
    }

    @Test("Text extraction LLM error is wrapped")
    func textExtractionLLMError() async throws {
        llm.errorToThrow = MockError.simulated

        await #expect(throws: PipelineError.self) {
            try await pipeline.extractFromText("Buy milk")
        }
    }

    // MARK: - Conversation & Refinement

    @Test("Fresh extraction creates a new conversation")
    func freshExtractionCreatesConversation() async throws {
        #expect(pipeline.currentConversation == nil)

        _ = try await pipeline.extractFromText("Buy milk")

        #expect(pipeline.currentConversation != nil)
        #expect(pipeline.currentConversation!.messages.count > 0)
    }

    @Test("Recording creates a new conversation")
    func recordingCreatesConversation() async throws {
        try await pipeline.startRecording()
        _ = try await pipeline.stopRecording()

        #expect(pipeline.currentConversation != nil)
        #expect(pipeline.currentConversation!.messages.count > 0)
    }

    @Test("Refine from text uses existing conversation")
    func refineFromText() async throws {
        // Initial extraction creates conversation
        _ = try await pipeline.extractFromText("Buy milk and finish the report")
        let conversationAfterFirst = pipeline.currentConversation
        let messageCountAfterFirst = conversationAfterFirst!.messages.count

        // Refine reuses the same conversation
        let result = try await pipeline.refineFromText(newInput: "Change milk to eggs")

        #expect(result.entries.count == 2)
        #expect(result.inputText == "Change milk to eggs")
        #expect(pipeline.currentConversation === conversationAfterFirst)

        // Conversation grew (new user message + assistant response appended)
        #expect(conversationAfterFirst!.messages.count > messageCountAfterFirst)

        // LLM received just the new input (not a formatted prompt with EXISTING ENTRIES)
        #expect(llm.lastReceivedTranscript == "Change milk to eggs")
    }

    @Test("Refine from recording uses existing conversation")
    func refineFromRecording() async throws {
        // Initial extraction
        _ = try await pipeline.extractFromText("Buy milk and finish the report")
        let conversation = pipeline.currentConversation

        // Refine via recording
        try await pipeline.startRecording()
        let result = try await pipeline.refineFromRecording()

        #expect(result.entries.count == 2)
        #expect(pipeline.currentConversation === conversation)
    }

    @Test("Refine without active session throws error")
    func refineWithoutSession() async throws {
        await #expect(throws: PipelineError.self) {
            try await pipeline.refineFromText(newInput: "Change something")
        }
    }

    @Test("New extraction replaces conversation")
    func newExtractionReplacesConversation() async throws {
        _ = try await pipeline.extractFromText("Buy milk")
        let firstConversation = pipeline.currentConversation

        _ = try await pipeline.extractFromText("Finish the report")
        let secondConversation = pipeline.currentConversation

        #expect(firstConversation !== secondConversation)
    }

    @Test("Multiple refinements accumulate conversation history")
    func multipleRefinements() async throws {
        _ = try await pipeline.extractFromText("Buy milk")
        let msgCountAfterExtract = pipeline.currentConversation!.messages.count

        _ = try await pipeline.refineFromText(newInput: "Change to eggs")
        let msgCountAfterRefine1 = pipeline.currentConversation!.messages.count
        #expect(msgCountAfterRefine1 > msgCountAfterExtract)

        _ = try await pipeline.refineFromText(newInput: "Also add bread")
        let msgCountAfterRefine2 = pipeline.currentConversation!.messages.count
        #expect(msgCountAfterRefine2 > msgCountAfterRefine1)
    }

    @Test("Transcription error during stopRecording is wrapped")
    func stopRecordingTranscriptionError() async throws {
        try await pipeline.startRecording()
        #expect(await pipeline.isRecording == true)

        // Set error after recording has started
        transcriber.errorToThrow = MockError.simulated

        await #expect(throws: PipelineError.self) {
            try await pipeline.stopRecording()
        }
    }

    @Test("Refine from recording when not recording throws notRecording")
    func refineFromRecordingNotRecording() async throws {
        // Create a conversation first
        _ = try await pipeline.extractFromText("Buy milk")
        #expect(pipeline.currentConversation != nil)

        // Try to refine via recording without starting one
        await #expect(throws: PipelineError.self) {
            try await pipeline.refineFromRecording()
        }
    }

    @Test("Credit authorize and charge run for text extraction")
    func creditAuthorizeAndCharge() async throws {
        let pricing = ServicePricing(
            inputUSDPer1MMicros: 1_000_000,
            outputUSDPer1MMicros: 5_000_000,
            minimumChargeCredits: 1
        )
        let pricedPipeline = Pipeline(
            transcriber: transcriber,
            llm: llm,
            creditGate: creditGate,
            llmPricing: pricing
        )

        let result = try await pricedPipeline.extractFromText("Buy milk")

        #expect(creditGate.authorizeCalled == true)
        #expect(creditGate.chargeCalled == true)
        #expect(result.receipt != nil)
        #expect(result.receipt?.creditsCharged == pricing.credits(for: llm.usageToReturn))
    }

    @Test("Insufficient credits maps to PipelineError")
    func insufficientCredits() async throws {
        creditGate.authorizeError = CreditError.insufficientBalance(current: 0)
        let pricedPipeline = Pipeline(
            transcriber: transcriber,
            llm: llm,
            creditGate: creditGate,
            llmPricing: .zero
        )

        await #expect(throws: PipelineError.self) {
            try await pricedPipeline.extractFromText("Buy milk")
        }
    }
}

@Suite("Enums")
struct EnumTests {
    @Test("EntryCategory display names")
    func categoryDisplayNames() {
        #expect(EntryCategory.todo.displayName == "Todo")
        #expect(EntryCategory.note.displayName == "Note")
        #expect(EntryCategory.reminder.displayName == "Reminder")
        #expect(EntryCategory.idea.displayName == "Idea")
        #expect(EntryCategory.list.displayName == "List")
        #expect(EntryCategory.habit.displayName == "Habit")
        #expect(EntryCategory.question.displayName == "Question")
        #expect(EntryCategory.thought.displayName == "Thought")
    }

    @Test("EntrySource display names")
    func sourceDisplayNames() {
        #expect(EntrySource.voice.displayName == "Voice")
        #expect(EntrySource.text.displayName == "Text")
    }

    @Test("EntryCategory defensive init falls back to note")
    func categoryDefensiveInit() {
        #expect(EntryCategory(from: "todo") == .todo)
        #expect(EntryCategory(from: "unknown") == .note)
        #expect(EntryCategory(from: "") == .note)
    }

    @Test("EntrySource defensive init falls back to voice")
    func sourceDefensiveInit() {
        #expect(EntrySource(from: "text") == .text)
        #expect(EntrySource(from: "unknown") == .voice)
        #expect(EntrySource(from: "") == .voice)
    }
}
