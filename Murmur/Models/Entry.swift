import Foundation
import SwiftData

enum EntryCategory: String, Codable, CaseIterable {
    case todo
    case insight
    case idea
    case reminder
    case note
    case question
    case decision
    case learning

    var displayName: String {
        switch self {
        case .todo: return "Todos"
        case .insight: return "Insights"
        case .idea: return "Ideas"
        case .reminder: return "Reminders"
        case .note: return "Notes"
        case .question: return "Questions"
        case .decision: return "Decisions"
        case .learning: return "Learning"
        }
    }
}

enum EntryStatus: String, Codable {
    case active
    case completed
    case dismissed
}

@Model
final class Entry {
    var id: UUID
    var summary: String
    var fullTranscript: String?
    var category: EntryCategory
    var status: EntryStatus
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var dueDate: Date?
    var priority: Int // 0-2 (low, medium, high)
    var tags: [String] // Tag names/IDs
    var aiGenerated: Bool
    var tokenCost: Int

    init(
        id: UUID = UUID(),
        summary: String,
        fullTranscript: String? = nil,
        category: EntryCategory,
        status: EntryStatus = .active,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        dueDate: Date? = nil,
        priority: Int = 1,
        tags: [String] = [],
        aiGenerated: Bool = true,
        tokenCost: Int = 0
    ) {
        self.id = id
        self.summary = summary
        self.fullTranscript = fullTranscript
        self.category = category
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.dueDate = dueDate
        self.priority = priority
        self.tags = tags
        self.aiGenerated = aiGenerated
        self.tokenCost = tokenCost
    }
}
