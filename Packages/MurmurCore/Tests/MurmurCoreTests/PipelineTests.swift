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

    @Test("Transcriber error is wrapped in PipelineError")
    func transcriberStartError() async throws {
        transcriber.errorToThrow = MockError.simulated

        await #expect(throws: PipelineError.self) {
            try await pipeline.startRecording()
        }
    }

    @Test("Transcription error is wrapped")
    func transcriptionError() async throws {
        transcriber.errorToThrow = MockError.simulated

        await #expect(throws: PipelineError.self) {
            try await pipeline.startRecording()
        }
    }

    // MARK: - Cancel & Live Transcript

    @Test("cancelRecording stops transcriber without extraction")
    func cancelRecordingNoExtraction() async throws {
        try await pipeline.startRecording()
        #expect(await pipeline.isRecording == true)

        await pipeline.cancelRecording()

        #expect(await pipeline.isRecording == false)
        #expect(llm.lastReceivedTranscript == nil, "LLM should not be called on cancel")
    }

    @Test("currentTranscript returns live text from transcriber")
    func currentTranscriptReadsFromTranscriber() async throws {
        transcriber._currentTranscript = "Hello world"
        let text = await pipeline.currentTranscript
        #expect(text == "Hello world")
    }

    @Test("currentTranscript is empty when nothing spoken")
    func currentTranscriptEmptyByDefault() async throws {
        let text = await pipeline.currentTranscript
        #expect(text == "")
    }

    @Test("cancelRecording clears currentTranscript")
    func cancelClearsTranscript() async throws {
        try await pipeline.startRecording()
        transcriber._currentTranscript = "partial text"

        await pipeline.cancelRecording()

        #expect(await transcriber.currentTranscript == "")
    }

    @Test("cancelRecording is safe when not recording")
    func cancelWhenNotRecording() async throws {
        // Should not throw or crash
        await pipeline.cancelRecording()
        #expect(await pipeline.isRecording == false)
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
