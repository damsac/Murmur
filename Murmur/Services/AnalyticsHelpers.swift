import Foundation
import MurmurCore
import StudioAnalytics

// MARK: - LLM Request Event Builder

/// Builder that wraps `LLMRequestEvent` with Murmur-specific conveniences:
/// computed cost from `ServicePricing`, latency from `ContinuousClock`, error classification.
struct LLMRequestTracker {
    let requestId: UUID
    let conversationId: UUID
    let callType: String
    let model: String
    let pricing: ServicePricing
    let start: ContinuousClock.Instant

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
        var event = LLMRequestEvent(
            requestId: requestId,
            conversationId: conversationId,
            callType: callType,
            tokensIn: tokensIn,
            tokensOut: tokensOut,
            model: model,
            costMicros: costMicros,
            latencyMs: latencyMs,
            streaming: streaming,
            turnNumber: turnNumber,
            conversationMessages: conversationMessages,
            toolCalls: toolCalls,
            actionCount: actionCount,
            parseFailureCount: parseFailureCount,
            hasTextResponse: hasTextResponse
        )
        event.ttftMs = ttftMs
        event.variant = variant
        event.itemsCount = itemsCount
        StudioAnalytics.track(event)
    }

    func trackError(_ error: Error) {
        let (errorType, statusCode) = Self.classifyError(error)
        var event = LLMRequestEvent(
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
            hasTextResponse: false
        )
        event.variant = variant
        event.error = errorType
        event.errorStatusCode = statusCode
        StudioAnalytics.track(event)
    }

    // MARK: - Shared Helpers

    static func computeCost(usage: TokenUsage, pricing: ServicePricing) -> Int64 {
        let inputCost = Int64(usage.inputTokens) * pricing.inputUSDPer1MMicros
        let outputCost = Int64(usage.outputTokens) * pricing.outputUSDPer1MMicros
        return (inputCost + outputCost) / 1_000_000
    }

    static func classifyError(_ error: Error) -> (type: String, statusCode: Int?) {
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
