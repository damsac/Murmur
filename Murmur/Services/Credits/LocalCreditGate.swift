import Foundation
import MurmurCore

actor LocalCreditGate: CreditGate {
    private struct PersistedReceipt: Codable {
        let authorizationID: UUID
        let timestamp: Date
        let inputTokens: Int
        let outputTokens: Int
        let creditsCharged: Int64
        let newBalance: Int64
    }

    private struct PersistedState: Codable {
        var balance: Int64
        var receiptsByAuthorizationID: [String: PersistedReceipt]
    }

    private let defaults: UserDefaults
    private let storageKey: String
    private var state: PersistedState

    init(
        starterCredits: Int64 = 1_000,
        defaults: UserDefaults = .standard,
        storageKey: String = "credits.local.state.v1"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey

        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(PersistedState.self, from: data) {
            self.state = decoded
        } else {
            self.state = PersistedState(
                balance: starterCredits,
                receiptsByAuthorizationID: [:]
            )
            Self.persistState(
                state: self.state,
                defaults: defaults,
                storageKey: storageKey
            )
        }
    }

    var balance: Int64 {
        get async {
            state.balance
        }
    }

    func authorize() async throws -> CreditAuthorization {
        guard state.balance > 0 else {
            throw CreditError.insufficientBalance(current: state.balance)
        }
        return CreditAuthorization()
    }

    func charge(
        _ authorization: CreditAuthorization,
        usage: TokenUsage,
        pricing: ServicePricing
    ) async throws -> CreditReceipt {
        let key = authorization.id.uuidString

        if let existing = state.receiptsByAuthorizationID[key] {
            return CreditReceipt(
                authorization: CreditAuthorization(
                    id: existing.authorizationID,
                    timestamp: existing.timestamp
                ),
                usage: TokenUsage(
                    inputTokens: existing.inputTokens,
                    outputTokens: existing.outputTokens
                ),
                creditsCharged: existing.creditsCharged,
                newBalance: existing.newBalance
            )
        }

        let charge = pricing.credits(for: usage)
        let newBalance = state.balance - charge
        state.balance = newBalance

        let persisted = PersistedReceipt(
            authorizationID: authorization.id,
            timestamp: authorization.timestamp,
            inputTokens: usage.inputTokens,
            outputTokens: usage.outputTokens,
            creditsCharged: charge,
            newBalance: newBalance
        )
        state.receiptsByAuthorizationID[key] = persisted
        persistState()

        return CreditReceipt(
            authorization: authorization,
            usage: usage,
            creditsCharged: charge,
            newBalance: newBalance
        )
    }

    func topUp(credits: Int64) async throws {
        guard credits > 0 else {
            throw CreditError.invalidTopUpAmount
        }
        state.balance += credits
        persistState()
    }

    private func persistState() {
        Self.persistState(state: state, defaults: defaults, storageKey: storageKey)
    }

    private static func persistState(
        state: PersistedState,
        defaults: UserDefaults,
        storageKey: String
    ) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
