import Foundation

/// Orchestrates recording, transcription, and extraction — returns ExtractedEntry values.
/// Stateless with respect to persistence: the caller owns all storage.
@MainActor
public final class Pipeline {
    private let transcriber: any Transcriber
    private let llm: any LLMService

    /// Conversation state from the most recent extraction session.
    /// Used by refine methods for multi-turn LLM context.
    public private(set) var currentConversation: LLMConversation?

    public init(transcriber: any Transcriber, llm: any LLMService) {
        self.transcriber = transcriber
        self.llm = llm
    }

    // MARK: - Recording Flow

    /// Start recording audio
    public func startRecording() async throws {
        do {
            try await transcriber.startRecording()
        } catch {
            throw PipelineError.transcriptionFailed(underlying: error)
        }
    }

    /// Stop recording, transcribe, extract, and return entries.
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
        let entries = try await extractEntries(from: transcript.text, conversation: conversation)
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
        let entries = try await extractEntries(from: text, conversation: conversation)
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

        let entries = try await extractEntries(from: transcript.text, conversation: conversation)

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

        let entries = try await extractEntries(from: newInput, conversation: conversation)

        return TextResult(entries: entries, inputText: newInput)
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

    /// Extract entries via LLM and return as ExtractedEntry values.
    private func extractEntries(
        from text: String,
        conversation: LLMConversation
    ) async throws -> [ExtractedEntry] {
        let extractedEntries: [ExtractedEntry]
        do {
            extractedEntries = try await llm.extractEntries(from: text, conversation: conversation)
        } catch {
            throw PipelineError.extractionFailed(underlying: error)
        }

        guard !extractedEntries.isEmpty else {
            throw PipelineError.noEntriesExtracted
        }

        return extractedEntries
    }

}

// MARK: - Result Types

/// The result of a completed recording session
public struct RecordingResult {
    /// Entries that were extracted
    public let entries: [ExtractedEntry]

    /// The full transcript from the recording
    public let transcript: Transcript

    public init(entries: [ExtractedEntry], transcript: Transcript) {
        self.entries = entries
        self.transcript = transcript
    }
}

/// The result of a text extraction
public struct TextResult {
    /// Entries that were extracted
    public let entries: [ExtractedEntry]

    /// The original text input
    public let inputText: String

    public init(entries: [ExtractedEntry], inputText: String) {
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
        case .noActiveSession:
            return "No active extraction session to refine"
        }
    }
}
