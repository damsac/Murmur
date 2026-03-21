import Foundation
import MurmurCore
import StudioAnalytics

// MARK: - LLM Request Event Builder

/// Reduces the 20-parameter `trackLLMRequest` call sites to a builder pattern.
/// Construct with required fields, set optionals, then call `.track()` or `.trackError(_:)`.
struct LLMRequestEvent {
    let requestId: UUID
    let conversationId: UUID
    let callType: String
    let model: String
    let pricing: ServicePricing
    let start: ContinuousClock.Instant

    // Populated on success
    var tokensIn: Int = 0
    var tokensOut: Int = 0
    var streaming: Bool = false
    var turnNumber: Int = 1
    var conversationMessages: Int = 2
    var toolCalls: [String] = []
    var actionCount: Int = 0
    var parseFailureCount: Int = 0
    var hasTextResponse: Bool = false
    var variant: String?
    var itemsCount: Int?
    var ttftMs: Int?

    var costMicros: Int64 {
        let usage = TokenUsage(inputTokens: tokensIn, outputTokens: tokensOut)
        return Self.computeCost(usage: usage, pricing: pricing)
    }

    var latencyMs: Int {
        Int(start.duration(to: .now).totalMilliseconds)
    }

    func track() {
        StudioAnalytics.trackLLMRequest(
            requestId: requestId,
            conversationId: conversationId,
            callType: callType,
            tokensIn: tokensIn,
            tokensOut: tokensOut,
            model: model,
            costMicros: costMicros,
            latencyMs: latencyMs,
            ttftMs: ttftMs,
            streaming: streaming,
            turnNumber: turnNumber,
            conversationMessages: conversationMessages,
            toolCalls: toolCalls,
            actionCount: actionCount,
            parseFailureCount: parseFailureCount,
            hasTextResponse: hasTextResponse,
            variant: variant,
            itemsCount: itemsCount
        )
    }

    func trackError(_ error: Error) {
        let (errorType, statusCode) = Self.classifyError(error)
        StudioAnalytics.trackLLMRequest(
            requestId: requestId,
            conversationId: conversationId,
            callType: callType,
            tokensIn: 0,
            tokensOut: 0,
            model: model,
            costMicros: 0,
            latencyMs: latencyMs,
            streaming: streaming,
            turnNumber: turnNumber,
            conversationMessages: conversationMessages,
            toolCalls: [],
            actionCount: 0,
            parseFailureCount: 0,
            hasTextResponse: false,
            variant: variant,
            error: errorType,
            errorStatusCode: statusCode
        )
    }

    // MARK: - Shared Helpers

    static func computeCost(usage: TokenUsage, pricing: ServicePricing) -> Int64 {
        let inputCost = Int64(usage.inputTokens) * pricing.inputUSDPer1MMicros
        let outputCost = Int64(usage.outputTokens) * pricing.outputUSDPer1MMicros
        return (inputCost + outputCost) / 1_000_000
    }

    static func classifyError(_ error: Error) -> (type: String, statusCode: Int?) {
        // Unwrap PipelineError wrapper if present
        var inner = error
        if case PipelineError.extractionFailed(let underlying) = error {
            inner = underlying
        }
        if let ppqError = inner as? PPQError {
            switch ppqError {
            case .httpError(let code, _):
                return ("http_error", code)
            case .invalidResponse, .noToolCalls:
                return ("parse_error", nil)
            }
        }
        if inner is URLError {
            return ("network", nil)
        }
        return ("unknown", nil)
    }
}

// MARK: - Duration Helpers

extension Duration {
    var totalMilliseconds: Int64 {
        let (seconds, attoseconds) = components
        return seconds * 1000 + attoseconds / 1_000_000_000_000_000
    }
}
