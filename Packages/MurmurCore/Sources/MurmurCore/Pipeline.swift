import Foundation

/// Orchestrates recording, transcription, and extraction — returns ExtractedEntry values.
/// Stateless with respect to persistence: the caller owns all storage.
@MainActor
public final class Pipeline {
    private let transcriber: any Transcriber
    private let llm: any LLMService
    private let creditGate: (any CreditGate)?
    private let llmPricing: ServicePricing

    /// Conversation state from the most recent extraction session.
    /// Used by refine methods for multi-turn LLM context.
    public private(set) var currentConversation: LLMConversation?

    public init(
        transcriber: any Transcriber,
        llm: any LLMService,
        creditGate: (any CreditGate)? = nil,
        llmPricing: ServicePricing = .zero
    ) {
        self.transcriber = transcriber
        self.llm = llm
        self.creditGate = creditGate
        self.llmPricing = llmPricing
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
        let extraction = try await extractEntries(from: transcript.text, conversation: conversation)
        currentConversation = conversation

        return RecordingResult(
            entries: extraction.entries,
            transcript: transcript,
            receipt: extraction.receipt
        )
    }

    // MARK: - Text Extraction Flow

    /// Extract entries from text input (no transcriber needed).
    /// Creates a fresh conversation for subsequent refinement.
    public func extractFromText(_ text: String) async throws -> TextResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PipelineError.emptyTranscript
        }

        let conversation = LLMConversation()
        let extraction = try await extractEntries(from: text, conversation: conversation)
        currentConversation = conversation

        return TextResult(
            entries: extraction.entries,
            inputText: text,
            receipt: extraction.receipt
        )
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

        let extraction = try await extractEntries(from: transcript.text, conversation: conversation)

        return RecordingResult(
            entries: extraction.entries,
            transcript: transcript,
            receipt: extraction.receipt
        )
    }

    /// Refine via text using multi-turn conversation context.
    public func refineFromText(newInput: String) async throws -> TextResult {
        guard let conversation = currentConversation else {
            throw PipelineError.noActiveSession
        }
        guard !newInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PipelineError.emptyTranscript
        }

        let extraction = try await extractEntries(from: newInput, conversation: conversation)

        return TextResult(
            entries: extraction.entries,
            inputText: newInput,
            receipt: extraction.receipt
        )
    }

    /// The live partial transcript from the current recording session.
    public var currentTranscript: String {
        get async {
            await transcriber.currentTranscript
        }
    }

    /// Cancel recording immediately without finalization or extraction.
    public func cancelRecording() async {
        await transcriber.cancelRecording()
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

    // MARK: - Agent Processing

    /// Process text through the agent with existing entry context.
    /// Returns typed actions (create/update/complete/archive) instead of just extracted entries.
    public func processWithAgent(
        transcript: String,
        existingEntries: [AgentContextEntry],
        conversation: LLMConversation? = nil
    ) async throws -> AgentResult {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PipelineError.emptyTranscript
        }

        var authorization: CreditAuthorization?
        if let creditGate {
            do {
                authorization = try await creditGate.authorize()
            } catch let error as CreditError {
                switch error {
                case .insufficientBalance(let current):
                    throw PipelineError.insufficientCredits(current: current)
                default:
                    throw PipelineError.creditAuthorizationFailed(underlying: error)
                }
            } catch {
                throw PipelineError.creditAuthorizationFailed(underlying: error)
            }
        }

        let conv = conversation ?? LLMConversation()
        let response: AgentResponse
        do {
            response = try await llm.process(
                transcript: transcript,
                existingEntries: existingEntries,
                conversation: conv
            )
        } catch {
            throw PipelineError.extractionFailed(underlying: error)
        }

        currentConversation = conv

        var receipt: CreditReceipt?
        if let creditGate, let authorization {
            do {
                receipt = try await creditGate.charge(
                    authorization,
                    usage: response.usage,
                    pricing: llmPricing
                )
            } catch {
                throw PipelineError.creditChargeFailed(underlying: error)
            }
        }

        return AgentResult(response: response, receipt: receipt)
    }

    // MARK: - Shared Extraction Helper

    /// Extract entries via LLM and return as ExtractedEntry values.
    private func extractEntries(
        from text: String,
        conversation: LLMConversation
    ) async throws -> (entries: [ExtractedEntry], receipt: CreditReceipt?) {
        var authorization: CreditAuthorization?
        if let creditGate {
            do {
                authorization = try await creditGate.authorize()
            } catch let error as CreditError {
                switch error {
                case .insufficientBalance(let current):
                    throw PipelineError.insufficientCredits(current: current)
                default:
                    throw PipelineError.creditAuthorizationFailed(underlying: error)
                }
            } catch {
                throw PipelineError.creditAuthorizationFailed(underlying: error)
            }
        }

        let llmResult: LLMResult
        do {
            llmResult = try await llm.extractEntries(from: text, conversation: conversation)
        } catch {
            throw PipelineError.extractionFailed(underlying: error)
        }

        guard !llmResult.entries.isEmpty else {
            throw PipelineError.noEntriesExtracted
        }

        var receipt: CreditReceipt?
        if let creditGate, let authorization {
            do {
                receipt = try await creditGate.charge(
                    authorization,
                    usage: llmResult.usage,
                    pricing: llmPricing
                )
            } catch {
                throw PipelineError.creditChargeFailed(underlying: error)
            }
        }

        return (llmResult.entries, receipt)
    }

}

// MARK: - Result Types

/// The result of agent processing (create/update/complete/archive actions)
public struct AgentResult {
    public let response: AgentResponse
    public let receipt: CreditReceipt?

    public init(response: AgentResponse, receipt: CreditReceipt? = nil) {
        self.response = response
        self.receipt = receipt
    }
}

/// The result of a completed recording session
public struct RecordingResult {
    /// Entries that were extracted
    public let entries: [ExtractedEntry]

    /// The full transcript from the recording
    public let transcript: Transcript
    public let receipt: CreditReceipt?

    public init(entries: [ExtractedEntry], transcript: Transcript, receipt: CreditReceipt? = nil) {
        self.entries = entries
        self.transcript = transcript
        self.receipt = receipt
    }
}

/// The result of a text extraction
public struct TextResult {
    /// Entries that were extracted
    public let entries: [ExtractedEntry]

    /// The original text input
    public let inputText: String
    public let receipt: CreditReceipt?

    public init(entries: [ExtractedEntry], inputText: String, receipt: CreditReceipt? = nil) {
        self.entries = entries
        self.inputText = inputText
        self.receipt = receipt
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
    case insufficientCredits(current: Int64)
    case creditAuthorizationFailed(underlying: any Error)
    case creditChargeFailed(underlying: any Error)

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
        case .insufficientCredits(let current):
            return "Insufficient credits (\(current)). Top up to continue."
        case .creditAuthorizationFailed(let error):
            return "Credit authorization failed: \(error.localizedDescription)"
        case .creditChargeFailed(let error):
            return "Credit charge failed: \(error.localizedDescription)"
        }
    }
}
