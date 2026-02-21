import Foundation
import StoreKit

struct TopUpProduct: Sendable, Identifiable {
    let id: String
    let title: String
    let priceText: String
    let credits: Int64
}

struct TopUpPurchaseReceipt: Sendable {
    let productID: String
    let transactionID: UInt64
    let creditsGranted: Int64
    let purchaseDate: Date
}

protocol TopUpPurchaseService: Sendable {
    func loadProducts() async throws -> [TopUpProduct]
    func purchase(productID: String) async throws -> TopUpPurchaseReceipt
    func syncTransactions() async throws
}

enum StoreKitTopUpError: LocalizedError {
    case unknownProduct(String)
    case unverifiedTransaction
    case userCancelled
    case pending
    case missingCreditsMapping(String)

    var errorDescription: String? {
        switch self {
        case .unknownProduct(let id):
            return "Top-up product not found: \(id)"
        case .unverifiedTransaction:
            return "Could not verify App Store transaction."
        case .userCancelled:
            return "Purchase cancelled."
        case .pending:
            return "Purchase is pending approval."
        case .missingCreditsMapping(let id):
            return "Missing credit mapping for product: \(id)"
        }
    }
}

@MainActor
final class StoreKitTopUpService: TopUpPurchaseService {
    private let productIDs: [String]
    private let creditsByProductID: [String: Int64]

    init(
        productIDs: [String] = TopUpCatalog.productIDs,
        creditsByProductID: [String: Int64] = TopUpCatalog.creditsByProductID
    ) {
        self.productIDs = productIDs
        self.creditsByProductID = creditsByProductID
    }

    func loadProducts() async throws -> [TopUpProduct] {
        let products = try await Product.products(for: productIDs)

        return products.compactMap { product in
            guard let credits = creditsByProductID[product.id] else { return nil }
            return TopUpProduct(
                id: product.id,
                title: product.displayName,
                priceText: product.displayPrice,
                credits: credits
            )
        }
        .sorted { $0.credits < $1.credits }
    }

    func purchase(productID: String) async throws -> TopUpPurchaseReceipt {
        let products = try await Product.products(for: [productID])
        guard let product = products.first else {
            throw StoreKitTopUpError.unknownProduct(productID)
        }

        guard let credits = creditsByProductID[product.id] else {
            throw StoreKitTopUpError.missingCreditsMapping(product.id)
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verifiedTransaction(from: verification)
            await transaction.finish()
            return TopUpPurchaseReceipt(
                productID: transaction.productID,
                transactionID: transaction.id,
                creditsGranted: credits,
                purchaseDate: transaction.purchaseDate
            )
        case .userCancelled:
            throw StoreKitTopUpError.userCancelled
        case .pending:
            throw StoreKitTopUpError.pending
        @unknown default:
            throw StoreKitTopUpError.pending
        }
    }

    /// Sync and finish any restorable completed transactions for this product catalog.
    /// For consumables, this is mainly useful to catch interrupted local grant flows.
    func syncTransactions() async throws {
        try await AppStore.sync()

        for await entitlement in Transaction.currentEntitlements {
            let transaction = try verifiedTransaction(from: entitlement)
            guard creditsByProductID[transaction.productID] != nil else { continue }
            await transaction.finish()
        }
    }

    private func verifiedTransaction(
        from result: VerificationResult<Transaction>
    ) throws -> Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            throw StoreKitTopUpError.unverifiedTransaction
        }
    }
}
