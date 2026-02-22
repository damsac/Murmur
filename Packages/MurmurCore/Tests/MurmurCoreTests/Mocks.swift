import Foundation
@testable import MurmurCore

// MARK: - Mock Transcriber

final class MockTranscriber: Transcriber, @unchecked Sendable {
    var _isRecording = false
    var _isAvailable = true
    var _currentTranscript = ""
    var transcriptToReturn = "Buy milk and finish the report"
    var errorToThrow: Error?

    var currentTranscript: String {
        get async { _currentTranscript }
    }

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

    func cancelRecording() async {
        _isRecording = false
        _currentTranscript = ""
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
    var usageToReturn = TokenUsage(inputTokens: 100, outputTokens: 50)

    func extractEntries(from transcript: String, conversation: LLMConversation) async throws -> LLMResult {
        lastReceivedTranscript = transcript
        lastConversation = conversation
        if let error = errorToThrow {
            throw error
        }
        // Simulate conversation state accumulation (append user + fake assistant)
        conversation.messages.append(["role": "user", "content": transcript])
        conversation.messages.append(["role": "assistant", "content": "extracted"])
        return LLMResult(entries: entriesToReturn, usage: usageToReturn)
    }
}

// MARK: - Mock Error

enum MockError: Error {
    case simulated
}

// MARK: - Mock Credit Gate

final class MockCreditGate: CreditGate, @unchecked Sendable {
    var currentBalance: Int64 = 1_000
    var authorizeCalled = false
    var chargeCalled = false
    var topUpCalled = false
    var authorizeError: Error?
    var chargeError: Error?
    var topUpError: Error?
    var lastAuthorization: CreditAuthorization?
    var lastUsage: TokenUsage?
    var lastPricing: ServicePricing?

    var balance: Int64 {
        get async { currentBalance }
    }

    func authorize() async throws -> CreditAuthorization {
        authorizeCalled = true
        if let authorizeError {
            throw authorizeError
        }
        let auth = CreditAuthorization()
        lastAuthorization = auth
        return auth
    }

    func charge(
        _ authorization: CreditAuthorization,
        usage: TokenUsage,
        pricing: ServicePricing
    ) async throws -> CreditReceipt {
        chargeCalled = true
        lastAuthorization = authorization
        lastUsage = usage
        lastPricing = pricing
        if let chargeError {
            throw chargeError
        }

        let charge = pricing.credits(for: usage)
        currentBalance -= charge
        return CreditReceipt(
            authorization: authorization,
            usage: usage,
            creditsCharged: charge,
            newBalance: currentBalance
        )
    }

    func topUp(credits: Int64) async throws {
        topUpCalled = true
        if let topUpError {
            throw topUpError
        }
        currentBalance += credits
    }
}
