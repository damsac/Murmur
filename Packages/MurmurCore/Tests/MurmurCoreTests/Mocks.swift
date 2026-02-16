import Foundation
@testable import MurmurCore

// MARK: - Mock Transcriber

final class MockTranscriber: Transcriber, @unchecked Sendable {
    var _isRecording = false
    var _isAvailable = true
    var transcriptToReturn = "Buy milk and finish the report"
    var errorToThrow: Error?

    var isRecording: Bool {
        get async { _isRecording }
    }

    var isAvailable: Bool {
        get async { _isAvailable }
    }

    func startRecording() async throws {
        if let error = errorToThrow {
            throw error
        }
        _isRecording = true
    }

    func stopRecording() async throws -> Transcript {
        if let error = errorToThrow {
            throw error
        }
        _isRecording = false
        return Transcript(text: transcriptToReturn)
    }
}

// MARK: - Mock LLM Service

final class MockLLMService: LLMService, @unchecked Sendable {
    var entriesToReturn: [ExtractedEntry] = [
        ExtractedEntry(
            content: "Buy milk",
            category: .todo,
            sourceText: "Buy milk",
            summary: "Pick up milk from the store"
        ),
        ExtractedEntry(
            content: "Finish the report",
            category: .todo,
            sourceText: "finish the report",
            summary: "Complete the report"
        ),
    ]
    var errorToThrow: Error?
    var lastReceivedTranscript: String?
    var lastConversation: LLMConversation?

    func extractEntries(from transcript: String, conversation: LLMConversation) async throws -> [ExtractedEntry] {
        lastReceivedTranscript = transcript
        lastConversation = conversation
        if let error = errorToThrow {
            throw error
        }
        // Simulate conversation state accumulation (append user + fake assistant)
        conversation.messages.append(["role": "user", "content": transcript])
        conversation.messages.append(["role": "assistant", "content": "extracted"])
        return entriesToReturn
    }
}

// MARK: - Mock Error

enum MockError: Error {
    case simulated
}
