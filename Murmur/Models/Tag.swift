import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID
    var name: String
    var colorHex: String
    var isSystemGenerated: Bool

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#7C6FF7",
        isSystemGenerated: Bool = false
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isSystemGenerated = isSystemGenerated
    }
}
