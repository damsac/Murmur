---
date: 2026-02-18
topic: credit-system
---

# Credit System: Usage-Based Pricing with Proxy-Ready Architecture

## What We're Building

A credit system where:
- Users have a credit balance that gets consumed when they use transcription and LLM services
- Each service has configurable pricing based on the provider's actual cost-per-token
- On-device transcription (Apple Speech) is free (0 credits)
- LLM extraction charges credits proportional to actual input/output token usage
- Architecture is designed for easy migration from client-side to server-side proxy

## Why This Approach

**Post-deduct model:** Pipeline runs first, then deducts actual cost. If balance goes negative, next request is blocked until top-up. This avoids estimation complexity and ensures the user always gets their results for a request that starts.

**CreditGate protocol:** The critical abstraction. Pipeline depends on `CreditGate`, not on any specific storage or network implementation. Today it's `LocalCreditGate` (balance in local storage). Tomorrow it swaps to `ServerCreditGate` (balance on server, API key never on client) — zero Pipeline changes.

**Split between layers:**
- **MurmurCore** defines protocols (`CreditGate`, `TokenUsage`, `ServicePricing`) and wires them into Pipeline
- **App layer** provides the concrete implementation (`LocalCreditGate`)

## Key Decisions

### Credit Units
- Credits are an abstract unit (not 1:1 with tokens)
- Each service has a `ServicePricing` config: `inputCreditPerToken` and `outputCreditPerToken`
- Credits charged = `(inputTokens * inputRate) + (outputTokens * outputRate)`
- Exchange rate between credits and dollars is a configurable constant (decide later)

### Token Reporting
- `LLMService.extractEntries(...)` returns `TokenUsage` alongside entries
- `TokenUsage` = `{ inputTokens: Int, outputTokens: Int }` — read from LLM API response
- Apple Speech transcriber reports `TokenUsage(0, 0)` — on-device is free
- Future API-based transcribers will report their actual usage

### Deduction Timing
- **Pre-check:** Pipeline calls `gate.authorize()` before starting — rejects if balance ≤ 0
- **Post-deduct:** After LLM responds, Pipeline calls `gate.charge(auth, usage)` with actual token counts
- If balance goes negative from the charge, that's OK — blocked on next request
- `CreditAuthorization` token links pre-check to post-charge (becomes idempotency key when server-side)

### On-Device Transcription
- Free (0 credits). Only LLM processing and future API-based transcription cost credits.

### Balance Persistence
- Abstracted behind `CreditGate` protocol — storage TBD
- For dev: UserDefaults or local SwiftData
- For production: server-side database via proxy

### Robustness (Current vs Future)

**Client-side (now):** Acceptable for dev and initial user feedback. Not tamper-proof — user could kill the app between API response and deduction. Acknowledged tradeoff.

**Server-side (later):** Proxy holds the API key. Client never sees it. Credits deducted atomically on the server in the same operation that calls the LLM API. Write-ahead log for crash recovery. This is the production-grade path.

**Migration path:** Swap `LocalCreditGate` for `ServerCreditGate` at app init. Pipeline, services, and UI are unchanged. The `CreditGate` protocol ensures this is a one-line swap.

## Architecture

### MurmurCore (protocols + integration)

```swift
// --- Value Types ---

public struct TokenUsage: Sendable {
    public let inputTokens: Int
    public let outputTokens: Int
    public var totalTokens: Int { inputTokens + outputTokens }
}

public struct ServicePricing: Sendable {
    public let inputCreditPerToken: Double
    public let outputCreditPerToken: Double

    public func cost(for usage: TokenUsage) -> Double {
        Double(usage.inputTokens) * inputCreditPerToken
            + Double(usage.outputTokens) * outputCreditPerToken
    }
}

public struct CreditAuthorization: Sendable {
    public let id: UUID  // becomes idempotency key for server-side
    public let timestamp: Date
}

public struct CreditReceipt: Sendable {
    public let authorization: CreditAuthorization
    public let usage: TokenUsage
    public let creditsCharged: Double
    public let newBalance: Double
}

// --- Protocols ---

public protocol CreditGate: Sendable {
    /// Pre-check: can the user start a pipeline run?
    /// Throws CreditError.insufficientBalance if balance <= 0
    func authorize() async throws -> CreditAuthorization

    /// Post-charge: deduct actual cost after processing completes
    func charge(_ auth: CreditAuthorization, usage: TokenUsage, pricing: ServicePricing) async throws -> CreditReceipt

    /// Current balance for UI display
    var balance: Double { get async }
}

public enum CreditError: LocalizedError {
    case insufficientBalance(current: Double)

    public var errorDescription: String? {
        switch self {
        case .insufficientBalance(let balance):
            return "Insufficient credits (balance: \(balance)). Top up to continue."
        }
    }
}

// --- Modified LLMService ---

public protocol LLMService: Sendable {
    /// Extract entries and report token usage
    func extractEntries(
        from transcript: String,
        conversation: LLMConversation
    ) async throws -> LLMResult
}

public struct LLMResult: Sendable {
    public let entries: [ExtractedEntry]
    public let usage: TokenUsage
}

// --- Pipeline Changes ---

// Pipeline gains:
//   - CreditGate dependency (injected at init)
//   - ServicePricing for LLM (injected at init)
//   - authorize() call before LLM processing
//   - charge() call after LLM responds
//   - CreditReceipt on result types
```

### App Layer (concrete implementation)

```swift
// LocalCreditGate — client-side balance for dev/early access
final class LocalCreditGate: CreditGate {
    // Balance stored locally (UserDefaults, Keychain, or SwiftData)
    // authorize() checks balance > 0
    // charge() deducts from local store
}

// Future: ServerCreditGate — production proxy
// final class ServerCreditGate: CreditGate {
//     // authorize() → POST /api/authorize
//     // charge() → POST /api/charge
//     // balance → GET /api/balance (cached)
// }
```

### Modified Result Types

```swift
public struct RecordingResult {
    public let entries: [ExtractedEntry]
    public let transcript: Transcript
    public let receipt: CreditReceipt?  // nil if no credit gate configured
}

public struct TextResult {
    public let entries: [ExtractedEntry]
    public let inputText: String
    public let receipt: CreditReceipt?
}
```

## Open Questions

- What starter balance should new users get?
- Token pack sizes and dollar amounts (existing spec has $0.99/10k, $3.99/50k, $6.99/100k)
- How to set `ServicePricing` rates based on actual provider costs (hardcode vs remote config)
- Should pricing be visible to the user or abstracted behind "credits"?

## Next Steps

→ `/workflows:plan` for implementation — start with MurmurCore types and protocol changes, then Pipeline integration, then LocalCreditGate in the app layer.
