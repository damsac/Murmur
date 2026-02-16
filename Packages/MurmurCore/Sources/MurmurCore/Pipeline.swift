import Foundation

/// Orchestrates recording, transcription, extraction, and storage of entries.
@MainActor
public final class Pipeline {
    private let transcriber: any Transcriber
    private let llm: any LLMService
    private let store: EntryStore

    /// Conversation state from the most recent extraction session.
    /// Used by refine methods for multi-turn LLM context.
    public private(set) var currentConversation: LLMConversation?

    public init(transcriber: any Transcriber, llm: any LLMService, store: EntryStore) {
        self.transcriber = transcriber
        self.llm = llm
        self.store = store
    }

    // MARK: - Recording Flow

    /// Start recording audio
    public func startRecording() async throws {
        guard await transcriber.isAvailable else {
            throw PipelineError.transcriberUnavailable
        }
        do {
            try await transcriber.startRecording()
        } catch {
            throw PipelineError.transcriptionFailed(underlying: error)
        }
    }

    /// Stop recording, transcribe, extract, and return entries WITHOUT saving.
    /// Creates a fresh conversation for subsequent refinement.
    public func stopRecording() async throws -> RecordingResult {
        guard await transcriber.isRecording else {
            throw PipelineError.notRecording
        }

        let transcript: Transcript
        do {
            transcript = try await transcriber.stopRecording()
        } catch {
            throw PipelineError.transcriptionFailed(underlying: error)
        }

        guard !transcript.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PipelineError.emptyTranscript
        }

        let conversation = LLMConversation()
        let entries = try await extractAndMakeEntries(
            from: transcript.text,
            transcript: transcript.text,
            source: .voice,
            audioDuration: transcript.duration,
            conversation: conversation
        )
        currentConversation = conversation

        return RecordingResult(entries: entries, transcript: transcript)
    }

    // MARK: - Text Extraction Flow

    /// Extract entries from text input (no transcriber needed).
    /// Creates a fresh conversation for subsequent refinement.
    public func extractFromText(_ text: String) async throws -> TextResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PipelineError.emptyTranscript
        }

        let conversation = LLMConversation()
        let entries = try await extractAndMakeEntries(
            from: text,
            transcript: text,
            source: .text,
            audioDuration: nil,
            conversation: conversation
        )
        currentConversation = conversation

        return TextResult(entries: entries, inputText: text)
    }

    // MARK: - Refinement Flow

    /// Stop recording and refine using multi-turn conversation context.
    /// The LLM sees its previous extraction + the new voice input.
    public func refineFromRecording() async throws -> RecordingResult {
        guard let conversation = currentConversation else {
            throw PipelineError.noActiveSession
        }
        guard await transcriber.isRecording else {
            throw PipelineError.notRecording
        }

        let transcript: Transcript
        do {
            transcript = try await transcriber.stopRecording()
        } catch {
            throw PipelineError.transcriptionFailed(underlying: error)
        }

        guard !transcript.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PipelineError.emptyTranscript
        }

        let entries = try await extractAndMakeEntries(
            from: transcript.text,
            transcript: transcript.text,
            source: .voice,
            audioDuration: transcript.duration,
            conversation: conversation
        )

        return RecordingResult(entries: entries, transcript: transcript)
    }

    /// Refine via text using multi-turn conversation context.
    public func refineFromText(newInput: String) async throws -> TextResult {
        guard let conversation = currentConversation else {
            throw PipelineError.noActiveSession
        }
        guard !newInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PipelineError.emptyTranscript
        }

        let entries = try await extractAndMakeEntries(
            from: newInput,
            transcript: newInput,
            source: .text,
            audioDuration: nil,
            conversation: conversation
        )

        return TextResult(entries: entries, inputText: newInput)
    }

    // MARK: - Save

    /// Persist entries from a RecordingResult into the store.
    public func save(_ result: RecordingResult) throws {
        try save(entries: result.entries)
    }

    /// Persist entries from a TextResult into the store.
    public func save(_ result: TextResult) throws {
        try save(entries: result.entries)
    }

    /// Persist a specific set of entries into the store.
    public func save(entries: [Entry]) throws {
        do {
            try store.save(entries)
        } catch {
            throw PipelineError.storageFailed(underlying: error)
        }
    }

    /// Check if currently recording
    public var isRecording: Bool {
        get async {
            await transcriber.isRecording
        }
    }

    /// Check if transcriber is available (permissions granted, etc.)
    public var isAvailable: Bool {
        get async {
            await transcriber.isAvailable
        }
    }

    // MARK: - Shared Extraction Helper

    /// Extract entries via LLM and convert to Entry models.
    private func extractAndMakeEntries(
        from text: String,
        transcript: String,
        source: EntrySource,
        audioDuration: TimeInterval?,
        conversation: LLMConversation
    ) async throws -> [Entry] {
        let extractedEntries: [ExtractedEntry]
        do {
            extractedEntries = try await llm.extractEntries(from: text, conversation: conversation)
        } catch {
            throw PipelineError.extractionFailed(underlying: error)
        }

        guard !extractedEntries.isEmpty else {
            throw PipelineError.noEntriesExtracted
        }

        let now = Date()
        return extractedEntries.map { extracted in
            Entry(
                transcript: transcript,
                content: extracted.content,
                category: extracted.category,
                sourceText: extracted.sourceText,
                createdAt: now,
                updatedAt: now,
                summary: extracted.summary,
                priority: extracted.priority,
                dueDateDescription: extracted.dueDateDescription,
                dueDate: Entry.resolveDate(from: extracted.dueDateDescription),
                audioDuration: audioDuration,
                source: source
            )
        }
    }

}

// MARK: - Result Types

/// The result of a completed recording session
public struct RecordingResult {
    /// Entries that were extracted (not yet saved — call Pipeline.save() to persist)
    public let entries: [Entry]

    /// The full transcript from the recording
    public let transcript: Transcript

    public init(entries: [Entry], transcript: Transcript) {
        self.entries = entries
        self.transcript = transcript
    }
}

/// The result of a text extraction
public struct TextResult {
    /// Entries that were extracted (not yet saved — call Pipeline.save() to persist)
    public let entries: [Entry]

    /// The original text input
    public let inputText: String

    public init(entries: [Entry], inputText: String) {
        self.entries = entries
        self.inputText = inputText
    }
}

// MARK: - Errors

public enum PipelineError: LocalizedError, Sendable {
    case transcriberUnavailable
    case notRecording
    case transcriptionFailed(underlying: any Error)
    case emptyTranscript
    case extractionFailed(underlying: any Error)
    case noEntriesExtracted
    case storageFailed(underlying: any Error)
    case noActiveSession

    public var errorDescription: String? {
        switch self {
        case .transcriberUnavailable:
            return "Transcriber is not available. Check permissions."
        case .notRecording:
            return "Not currently recording"
        case .transcriptionFailed(let error):
            return "Transcription failed: \(error.localizedDescription)"
        case .emptyTranscript:
            return "Transcript is empty"
        case .extractionFailed(let error):
            return "Entry extraction failed: \(error.localizedDescription)"
        case .noEntriesExtracted:
            return "No entries were extracted from the transcript"
        case .storageFailed(let error):
            return "Failed to save entries: \(error.localizedDescription)"
        case .noActiveSession:
            return "No active extraction session to refine"
        }
    }
}
