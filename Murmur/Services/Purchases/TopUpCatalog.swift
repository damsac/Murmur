import Foundation

/// Canonical top-up packs sold as StoreKit consumables.
/// Product IDs must match App Store Connect exactly.
enum TopUpCatalog {
    struct Pack: Sendable, Identifiable {
        let productIDs: [String]
        let credits: Int64
        let marketingLabel: String

        var id: String { productIDs.first ?? UUID().uuidString }
    }

    static let packs: [Pack] = [
        Pack(
            productIDs: [
                "com.damsac.murmur.credits.1000",
            ],
            credits: 1_000,
            marketingLabel: "Starter"
        ),
        Pack(
            productIDs: [
                "com.damsac.murmur.credits.5000",
            ],
            credits: 5_000,
            marketingLabel: "Popular"
        ),
        Pack(
            productIDs: [
                "com.damsac.murmur.credits.10000",
            ],
            credits: 10_000,
            marketingLabel: "Best value"
        ),
    ]

    static var productIDs: [String] {
        Array(Set(packs.flatMap(\.productIDs)))
    }

    static var creditsByProductID: [String: Int64] {
        Dictionary(
            uniqueKeysWithValues: packs.flatMap { pack in
                pack.productIDs.map { ($0, pack.credits) }
            }
        )
    }
}
