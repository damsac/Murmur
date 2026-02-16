import Foundation
import SwiftData

enum DisclosureLevel: Int, Codable, Comparable {
    case void = 0
    case firstLight = 1
    case gridAwakens = 2
    case viewsEmerge = 3
    case fullPower = 4

    static func < (lhs: DisclosureLevel, rhs: DisclosureLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

@Model
final class UserProgress {
    var id: UUID
    var disclosureLevel: DisclosureLevel
    var entryCount: Int
    var lastUpdated: Date

    init(
        id: UUID = UUID(),
        disclosureLevel: DisclosureLevel = .void,
        entryCount: Int = 0,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.disclosureLevel = disclosureLevel
        self.entryCount = entryCount
        self.lastUpdated = lastUpdated
    }
}
