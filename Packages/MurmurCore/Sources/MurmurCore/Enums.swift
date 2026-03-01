import Foundation

/// Entry categories — AI determines what the user said and picks the right category
public enum EntryCategory: String, Codable, Sendable, CaseIterable {
    case todo       // Actionable task: "pick up dry cleaning"
    case note       // Informational: "the wifi password is ..."
    case reminder   // Time-bound: "DMV appointment Thursday"
    case idea       // Creative/conceptual: "app that converts receipts to meal plans"
    case list       // Multi-item list: "groceries: eggs, bread, butter"
    case habit      // Recurring behavior: "start meditating every morning"
    case question   // Something to look up: "what's the capital of Portugal?"
    case thought    // Reflection/observation: "I've been feeling more productive lately"

    public var displayName: String {
        switch self {
        case .todo: return "Todo"
        case .note: return "Note"
        case .reminder: return "Reminder"
        case .idea: return "Idea"
        case .list: return "List"
        case .habit: return "Habit"
        case .question: return "Question"
        case .thought: return "Thought"
        }
    }

    /// Defensive initializer — falls back to .note for unknown raw values
    public init(from rawValue: String) {
        self = EntryCategory(rawValue: rawValue) ?? .note
    }

    /// Custom Decodable — unknown values decode as .note instead of throwing
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = EntryCategory(rawValue: rawValue) ?? .note
    }
}

/// How the entry was captured
public enum EntrySource: String, Codable, Sendable, CaseIterable {
    case voice
    case text

    public var displayName: String {
        switch self {
        case .voice: return "Voice"
        case .text: return "Text"
        }
    }

    /// Defensive initializer — falls back to .voice for unknown raw values
    public init(from rawValue: String) {
        self = EntrySource(rawValue: rawValue) ?? .voice
    }
}

/// How often a habit repeats
public enum HabitCadence: String, CaseIterable, Codable, Sendable {
    case daily
    case weekdays
    case weekly
    case monthly

    public var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekdays: return "Weekdays"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
}
