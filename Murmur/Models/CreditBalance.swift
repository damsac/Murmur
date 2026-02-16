import Foundation
import SwiftData

@Model
final class CreditBalance {
    var id: UUID
    var balance: Int
    var lastUpdated: Date

    init(
        id: UUID = UUID(),
        balance: Int = 1000,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.balance = balance
        self.lastUpdated = lastUpdated
    }
}
