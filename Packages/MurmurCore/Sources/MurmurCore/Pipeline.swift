import Foundation
import os.log

private let sseLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "murmur", category: "SSE")

/// Orchestrates recording, transcription, and LLM agent processing.
/// Stateless with respect to persistence: the caller owns all storage.
@MainActor
public final class Pipeline {
    public let transcriber: any Transcriber
    private let llm: any MurmurAgent
    private let creditGate: (any CreditGate)?
    public let llmPricing: ServicePricing

    /// Conversation state from the most recent agent session.
    public private(set) var currentConversation: LLMConversation?

    public init(
        transcriber: any Transcriber,
        llm: any MurmurAgent,
        creditGate: (any CreditGate)? = nil,
        llmPricing: ServicePricing = .zero
    ) {
        self.transcriber = transcriber
        self.llm = llm
        self.creditGate = creditGate
        self.llmPricing = llmPricing
    }

    // MARK: - Recording

    /// Start recording audio
    public func startRecording() async throws {
        do {
            try await transcriber.startRecording()
        } catch {
            throw PipelineError.transcriptionFailed(underlying: error)
        }
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

    // MARK: - Streaming Agent Processing

    public func processWithAgentStreaming(
        transcript: String,
        existingEntries: [AgentContextEntry],
        conversation: LLMConversation? = nil
    ) async throws -> AsyncThrowingStream<AgentStreamEvent, Error> {
        sseLog.info("[SSE] Pipeline.processWithAgentStreaming — STREAMING path")
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PipelineError.emptyTranscript
        }

        let authorization = try await authorizeCredits()
        let conv = conversation ?? LLMConversation()

        guard let streamingLLM = llm as? any StreamingMurmurAgent else {
            sseLog.info("[SSE] Pipeline — LLM does not support streaming, falling back to batch")
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

            if let creditGate, let authorization {
                _ = try? await creditGate.charge(
                    authorization,
                    usage: response.usage,
                    pricing: llmPricing
                )
            }

            return AsyncThrowingStream { continuation in
                continuation.yield(.completed(response))
                continuation.finish()
            }
        }

        let innerStream = streamingLLM.processStreaming(
            transcript: transcript,
            existingEntries: existingEntries,
            conversation: conv
        )
        currentConversation = conv

        let capturedCreditGate = self.creditGate
        let capturedPricing = self.llmPricing

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await event in innerStream {
                        if case .completed(let response) = event,
                           let cg = capturedCreditGate, let auth = authorization {
                            _ = try? await cg.charge(
                                auth,
                                usage: response.usage,
                                pricing: capturedPricing
                            )
                        }
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(
                        throwing: PipelineError.extractionFailed(underlying: error)
                    )
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Authorize credits before a pipeline operation. Returns nil if no credit gate.
    private func authorizeCredits() async throws -> CreditAuthorization? {
        guard let creditGate else { return nil }
        do {
            return try await creditGate.authorize()
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

}

// MARK: - Errors

public enum PipelineError: LocalizedError, Sendable {
    case notRecording
    case transcriptionFailed(underlying: any Error)
    case emptyTranscript
    case extractionFailed(underlying: any Error)
    case noEntriesExtracted
    case insufficientCredits(current: Int64)
    case creditAuthorizationFailed(underlying: any Error)
    case creditChargeFailed(underlying: any Error)

    public var errorDescription: String? {
        switch self {
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
        case .insufficientCredits(let current):
            return "Insufficient credits (\(current)). Top up to continue."
        case .creditAuthorizationFailed(let error):
            return "Credit authorization failed: \(error.localizedDescription)"
        case .creditChargeFailed(let error):
            return "Credit charge failed: \(error.localizedDescription)"
        }
    }
}
