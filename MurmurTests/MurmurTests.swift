import Foundation
import Testing
import MurmurCore
@testable import Murmur

@Suite("EntryCategory")
struct EntryCategoryTests {
    @Test("all cases exist")
    func allCases() {
        #expect(EntryCategory.allCases.count == 8)
    }

    @Test("raw values are lowercase")
    func rawValues() {
        #expect(EntryCategory.todo.rawValue == "todo")
        #expect(EntryCategory.note.rawValue == "note")
    }
}

@Suite("Entry defaults")
struct EntryTests {
    @Test("entry can be created")
    func creation() {
        let entry = Entry(
            transcript: "Buy milk",
            content: "Buy milk",
            category: .todo,
            sourceText: "Buy milk",
            summary: "Test entry"
        )
        #expect(entry.summary == "Test entry")
        #expect(entry.category == .todo)
        #expect(entry.status == .active)
    }

    @Test("entry created from ExtractedEntry")
    func fromExtracted() {
        let extracted = ExtractedEntry(
            content: "Buy milk",
            category: .todo,
            sourceText: "buy milk",
            summary: "Buy milk"
        )
        let entry = Entry(
            from: extracted,
            transcript: "I need to buy milk",
            source: .voice,
            audioDuration: 3.5
        )
        #expect(entry.content == "Buy milk")
        #expect(entry.category == .todo)
        #expect(entry.source == .voice)
        #expect(entry.audioDuration == 3.5)
        #expect(entry.transcript == "I need to buy milk")
    }
}

@Suite("Credit System Integration")
struct CreditSystemTests {
    @Test("LocalCreditGate starts with correct balance")
    func starterBalance() async {
        let defaults = UserDefaults(suiteName: "test.credits.\(UUID().uuidString)")!
        let gate = LocalCreditGate(starterCredits: 500, defaults: defaults, storageKey: "test.state")
        let balance = await gate.balance
        #expect(balance == 500)
    }

    @Test("LocalCreditGate authorize succeeds with positive balance")
    func authorizeSuccess() async throws {
        let defaults = UserDefaults(suiteName: "test.credits.\(UUID().uuidString)")!
        let gate = LocalCreditGate(starterCredits: 100, defaults: defaults, storageKey: "test.state")
        let auth = try await gate.authorize()
        #expect(auth.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    @Test("LocalCreditGate authorize fails with zero balance")
    func authorizeInsufficientBalance() async {
        let defaults = UserDefaults(suiteName: "test.credits.\(UUID().uuidString)")!
        let gate = LocalCreditGate(starterCredits: 0, defaults: defaults, storageKey: "test.state")
        await #expect(throws: CreditError.self) {
            try await gate.authorize()
        }
    }

    @Test("LocalCreditGate charge deducts correctly")
    func chargeDeductsBalance() async throws {
        let defaults = UserDefaults(suiteName: "test.credits.\(UUID().uuidString)")!
        let gate = LocalCreditGate(starterCredits: 1_000, defaults: defaults, storageKey: "test.state")
        let auth = try await gate.authorize()
        let usage = TokenUsage(inputTokens: 500, outputTokens: 200)
        let pricing = ServicePricing(
            inputUSDPer1MMicros: 1_000_000,
            outputUSDPer1MMicros: 5_000_000,
            minimumChargeCredits: 1
        )
        let receipt = try await gate.charge(auth, usage: usage, pricing: pricing)
        #expect(receipt.creditsCharged > 0)
        #expect(receipt.newBalance < 1_000)
        let balance = await gate.balance
        #expect(balance == receipt.newBalance)
    }

    @Test("LocalCreditGate idempotent charge with same authorization")
    func idempotentCharge() async throws {
        let defaults = UserDefaults(suiteName: "test.credits.\(UUID().uuidString)")!
        let gate = LocalCreditGate(starterCredits: 1_000, defaults: defaults, storageKey: "test.state")
        let auth = try await gate.authorize()
        let usage = TokenUsage(inputTokens: 100, outputTokens: 50)
        let pricing = ServicePricing(
            inputUSDPer1MMicros: 1_000_000,
            outputUSDPer1MMicros: 5_000_000,
            minimumChargeCredits: 1
        )
        let receipt1 = try await gate.charge(auth, usage: usage, pricing: pricing)
        let receipt2 = try await gate.charge(auth, usage: usage, pricing: pricing)
        #expect(receipt1.creditsCharged == receipt2.creditsCharged)
        #expect(receipt1.newBalance == receipt2.newBalance)
        // Balance should only be deducted once
        let balance = await gate.balance
        #expect(balance == receipt1.newBalance)
    }

    @Test("LocalCreditGate topUp increases balance")
    func topUpAddsCredits() async throws {
        let defaults = UserDefaults(suiteName: "test.credits.\(UUID().uuidString)")!
        let gate = LocalCreditGate(starterCredits: 100, defaults: defaults, storageKey: "test.state")
        try await gate.topUp(credits: 500)
        let balance = await gate.balance
        #expect(balance == 600)
    }

    @Test("LocalCreditGate topUp rejects zero/negative amount")
    func topUpRejectsInvalid() async {
        let defaults = UserDefaults(suiteName: "test.credits.\(UUID().uuidString)")!
        let gate = LocalCreditGate(starterCredits: 100, defaults: defaults, storageKey: "test.state")
        await #expect(throws: CreditError.self) {
            try await gate.topUp(credits: 0)
        }
        await #expect(throws: CreditError.self) {
            try await gate.topUp(credits: -10)
        }
    }

    @Test("LocalCreditGate persists balance across instances")
    func persistenceAcrossInstances() async throws {
        let suiteName = "test.credits.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let storageKey = "test.persist"

        let gate1 = LocalCreditGate(starterCredits: 1_000, defaults: defaults, storageKey: storageKey)
        try await gate1.topUp(credits: 500)
        let balanceAfterTopUp = await gate1.balance
        #expect(balanceAfterTopUp == 1_500)

        // Create a new instance with same defaults/key
        let gate2 = LocalCreditGate(starterCredits: 1_000, defaults: defaults, storageKey: storageKey)
        let restoredBalance = await gate2.balance
        #expect(restoredBalance == 1_500)
    }

    @Test("ServicePricing credit calculation")
    func pricingCalculation() {
        let pricing = ServicePricing(
            inputUSDPer1MMicros: 1_000_000,
            outputUSDPer1MMicros: 5_000_000,
            minimumChargeCredits: 1
        )
        // 100 input tokens at $1/M = $0.0001 = 0.1 milli-dollars
        // 50 output tokens at $5/M = $0.00025 = 0.25 milli-dollars
        // Total = 0.35 milli-dollars = ceil(0.35) = 1 credit (minimum)
        let usage = TokenUsage(inputTokens: 100, outputTokens: 50)
        let credits = pricing.credits(for: usage)
        #expect(credits >= 1)
    }

    @Test("ServicePricing zero usage returns zero credits")
    func pricingZeroUsage() {
        let pricing = ServicePricing(
            inputUSDPer1MMicros: 1_000_000,
            outputUSDPer1MMicros: 5_000_000,
            minimumChargeCredits: 1
        )
        let credits = pricing.credits(for: .zero)
        #expect(credits == 0)
    }

    @Test("TopUpCatalog product IDs match StoreKit config")
    func catalogProductIDs() {
        let ids = TopUpCatalog.productIDs
        #expect(ids.contains("com.damsac.murmur.credits.1000"))
        #expect(ids.contains("com.damsac.murmur.credits.5000"))
        #expect(ids.contains("com.damsac.murmur.credits.10000"))
        #expect(ids.count == 3)
    }

    @Test("TopUpCatalog credits mapping is correct")
    func catalogCreditsMapping() {
        let mapping = TopUpCatalog.creditsByProductID
        #expect(mapping["com.damsac.murmur.credits.1000"] == 1_000)
        #expect(mapping["com.damsac.murmur.credits.5000"] == 5_000)
        #expect(mapping["com.damsac.murmur.credits.10000"] == 10_000)
    }
}
