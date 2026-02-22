import Foundation

/// Token accounting reported by billable providers.
public struct TokenUsage: Sendable, Equatable {
    public let inputTokens: Int
    public let outputTokens: Int

    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    public var totalTokens: Int {
        inputTokens + outputTokens
    }

    public static let zero = TokenUsage(inputTokens: 0, outputTokens: 0)
}

/// Pricing in USD micros (1e-6 dollars) per 1M tokens.
/// This avoids floating-point drift and keeps credit math deterministic.
public struct ServicePricing: Sendable, Equatable {
    public let inputUSDPer1MMicros: Int64
    public let outputUSDPer1MMicros: Int64
    public let minimumChargeCredits: Int64

    public init(
        inputUSDPer1MMicros: Int64,
        outputUSDPer1MMicros: Int64,
        minimumChargeCredits: Int64 = 1
    ) {
        self.inputUSDPer1MMicros = inputUSDPer1MMicros
        self.outputUSDPer1MMicros = outputUSDPer1MMicros
        self.minimumChargeCredits = minimumChargeCredits
    }

    public static let zero = ServicePricing(
        inputUSDPer1MMicros: 0,
        outputUSDPer1MMicros: 0,
        minimumChargeCredits: 0
    )

    /// 1 credit = 1000 USD micros ($0.001).
    public func credits(for usage: TokenUsage) -> Int64 {
        guard usage.totalTokens > 0 else { return 0 }

        let inputCostMicros = Int64(usage.inputTokens) * inputUSDPer1MMicros
        let outputCostMicros = Int64(usage.outputTokens) * outputUSDPer1MMicros
        let totalMicros = (inputCostMicros + outputCostMicros) / 1_000_000

        let computed = ceilDiv(totalMicros, by: 1_000)
        return max(minimumChargeCredits, computed)
    }

    private func ceilDiv(_ numerator: Int64, by denominator: Int64) -> Int64 {
        guard denominator > 0 else { return 0 }
        return (numerator + denominator - 1) / denominator
    }
}

public struct CreditAuthorization: Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date

    public init(id: UUID = UUID(), timestamp: Date = Date()) {
        self.id = id
        self.timestamp = timestamp
    }
}

public struct CreditReceipt: Sendable, Equatable {
    public let authorization: CreditAuthorization
    public let usage: TokenUsage
    public let creditsCharged: Int64
    public let newBalance: Int64

    public init(
        authorization: CreditAuthorization,
        usage: TokenUsage,
        creditsCharged: Int64,
        newBalance: Int64
    ) {
        self.authorization = authorization
        self.usage = usage
        self.creditsCharged = creditsCharged
        self.newBalance = newBalance
    }
}

public protocol CreditGate: Sendable {
    func authorize() async throws -> CreditAuthorization
    func charge(
        _ authorization: CreditAuthorization,
        usage: TokenUsage,
        pricing: ServicePricing
    ) async throws -> CreditReceipt
    func topUp(credits: Int64) async throws
    var balance: Int64 { get async }
}

public enum CreditError: LocalizedError, Sendable {
    case insufficientBalance(current: Int64)
    case invalidTopUpAmount

    public var errorDescription: String? {
        switch self {
        case .insufficientBalance(let balance):
            return "Insufficient credits (balance: \(balance)). Top up to continue."
        case .invalidTopUpAmount:
            return "Top-up amount must be greater than zero."
        }
    }
}
