import Foundation

/// Agent-facing status for context snapshots and update fields.
public enum AgentEntryStatus: String, Codable, Sendable, CaseIterable {
    case active
    case completed
    case archived
    case snoozed
}

/// Compact entry snapshot passed into the LLM context.
public struct AgentContextEntry: Sendable, Codable, Identifiable {
    public let id: String
    public let summary: String
    public let category: EntryCategory
    public let priority: Int?
    public let dueDateDescription: String?
    public let cadence: HabitCadence?
    public let status: AgentEntryStatus
    public let createdAt: Date
    public let currentStreak: Int?
    public let notes: String?

    public init(
        id: String,
        summary: String,
        category: EntryCategory,
        priority: Int? = nil,
        dueDateDescription: String? = nil,
        cadence: HabitCadence? = nil,
        status: AgentEntryStatus = .active,
        createdAt: Date = Date(),
        currentStreak: Int? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.summary = summary
        self.category = category
        self.priority = priority
        self.dueDateDescription = dueDateDescription
        self.cadence = cadence
        self.status = status
        self.createdAt = createdAt
        self.currentStreak = currentStreak
        self.notes = notes
    }
}

public struct CreateAction: Sendable {
    public let content: String
    public let category: EntryCategory
    public let sourceText: String
    public let summary: String
    public let priority: Int?
    public let dueDateDescription: String?
    public let cadence: HabitCadence?
    public let notes: String?

    public init(
        content: String,
        category: EntryCategory,
        sourceText: String,
        summary: String,
        priority: Int? = nil,
        dueDateDescription: String? = nil,
        cadence: HabitCadence? = nil,
        notes: String? = nil
    ) {
        self.content = content
        self.category = category
        self.sourceText = sourceText
        self.summary = summary
        self.priority = priority
        self.dueDateDescription = dueDateDescription
        self.cadence = cadence
        self.notes = notes
    }
}

public struct UpdateFields: Sendable {
    public let content: String?
    public let summary: String?
    public let category: EntryCategory?
    public let priority: Int?
    public let dueDateDescription: String?
    public let cadence: HabitCadence?
    public let status: AgentEntryStatus?
    public let snoozeUntilDescription: String?
    public let checkOffHabit: Bool?
    public let notes: String?

    public init(
        content: String? = nil,
        summary: String? = nil,
        category: EntryCategory? = nil,
        priority: Int? = nil,
        dueDateDescription: String? = nil,
        cadence: HabitCadence? = nil,
        status: AgentEntryStatus? = nil,
        snoozeUntilDescription: String? = nil,
        checkOffHabit: Bool? = nil,
        notes: String? = nil
    ) {
        self.content = content
        self.summary = summary
        self.category = category
        self.priority = priority
        self.dueDateDescription = dueDateDescription
        self.cadence = cadence
        self.status = status
        self.snoozeUntilDescription = snoozeUntilDescription
        self.checkOffHabit = checkOffHabit
        self.notes = notes
    }
}

public struct UpdateAction: Sendable {
    public let id: String
    public let fields: UpdateFields
    public let reason: String

    public init(id: String, fields: UpdateFields, reason: String) {
        self.id = id
        self.fields = fields
        self.reason = reason
    }
}

public struct CompleteAction: Sendable {
    public let id: String
    public let reason: String

    public init(id: String, reason: String) {
        self.id = id
        self.reason = reason
    }
}

public struct ArchiveAction: Sendable {
    public let id: String
    public let reason: String

    public init(id: String, reason: String) {
        self.id = id
        self.reason = reason
    }
}

public struct UpdateMemoryAction: Sendable {
    public let content: String

    public init(content: String) {
        self.content = content
    }
}

/// Proposed actions awaiting user confirmation.
public struct ConfirmationRequest: Sendable {
    public let message: String
    public let proposedActions: [AgentAction]

    public init(message: String, proposedActions: [AgentAction]) {
        self.message = message
        self.proposedActions = proposedActions
    }
}

/// Typed actions produced by the agent.
public enum AgentAction: Sendable {
    case create(CreateAction)
    case update(UpdateAction)
    case complete(CompleteAction)
    case archive(ArchiveAction)
    case updateMemory(UpdateMemoryAction)
    case confirm(ConfirmationRequest)
    case layoutRead
    case layoutUpdate([LayoutOperation])
}

public extension AgentAction {
    var isConfirmation: Bool {
        if case .confirm = self { return true }
        return false
    }

    /// The entry ID targeted by a mutation action (update/complete/archive), or nil for creates/other.
    var mutationEntryID: String? {
        switch self {
        case .update(let a): return a.id
        case .complete(let a): return a.id
        case .archive(let a): return a.id
        default: return nil
        }
    }
}

/// A tool call that failed to decode.
public struct ParseFailure: Sendable {
    public let toolName: String
    public let rawArguments: String
    public let errorDescription: String
    public let toolCallID: String?

    public init(toolName: String, rawArguments: String, errorDescription: String, toolCallID: String? = nil) {
        self.toolName = toolName
        self.rawArguments = rawArguments
        self.errorDescription = errorDescription
        self.toolCallID = toolCallID
    }
}

/// Maps a single LLM tool_call_id to the contiguous slice of actions it produced.
public struct ToolCallGroup: Sendable {
    public let toolCallID: String
    public let toolName: String
    public let actionRange: Range<Int>

    public init(toolCallID: String, toolName: String, actionRange: Range<Int>) {
        self.toolCallID = toolCallID
        self.toolName = toolName
        self.actionRange = actionRange
    }
}

/// The agent response for a single turn.
public struct AgentResponse: Sendable {
    public let actions: [AgentAction]
    public let summary: String
    public let usage: TokenUsage
    public let parseFailures: [ParseFailure]
    public let toolCallGroups: [ToolCallGroup]

    /// Text content from the agent when responding without tool calls (clarifications, summaries).
    /// Only populated when the model returns text content — nil when actions-only.
    public let textResponse: String?

    public init(
        actions: [AgentAction],
        summary: String,
        usage: TokenUsage,
        parseFailures: [ParseFailure] = [],
        toolCallGroups: [ToolCallGroup] = [],
        textResponse: String? = nil
    ) {
        self.actions = actions
        self.summary = summary
        self.usage = usage
        self.parseFailures = parseFailures
        self.toolCallGroups = toolCallGroups
        self.textResponse = textResponse
    }
}

/// An entry extracted by the LLM — pure value type, no persistence dependency.
public struct ExtractedEntry: Sendable, Codable, Identifiable {
    /// Stable identity for SwiftUI (not decoded from JSON — always freshly generated)
    public let id: UUID

    /// The processed/cleaned content
    public let content: String

    /// The category assigned by the LLM
    public let category: EntryCategory

    /// The specific part of the transcript this was extracted from
    public let sourceText: String

    /// One-liner summary for cards/lists
    public let summary: String

    /// Priority 1-5 scale (1 = highest), nil if not applicable
    public let priority: Int?

    /// Raw time phrase from transcript (e.g. "next Thursday"), nil if none
    public let dueDateDescription: String?

    /// How often this habit repeats, nil for non-habits
    public let cadence: HabitCadence?

    /// Supplementary notes for the entry
    public let notes: String?

    enum CodingKeys: String, CodingKey {
        case content, category, sourceText, summary, priority, dueDateDescription, cadence, notes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.content = try container.decode(String.self, forKey: .content)
        self.category = try container.decode(EntryCategory.self, forKey: .category)
        self.sourceText = try container.decode(String.self, forKey: .sourceText)
        self.summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        self.priority = try container.decodeIfPresent(Int.self, forKey: .priority)
        self.dueDateDescription = try container.decodeIfPresent(String.self, forKey: .dueDateDescription)
        self.cadence = try container.decodeIfPresent(HabitCadence.self, forKey: .cadence)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    public init(
        content: String,
        category: EntryCategory,
        sourceText: String,
        summary: String = "",
        priority: Int? = nil,
        dueDateDescription: String? = nil,
        cadence: HabitCadence? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.content = content
        self.category = category
        self.sourceText = sourceText
        self.summary = summary
        self.priority = priority
        self.dueDateDescription = dueDateDescription
        self.cadence = cadence
        self.notes = notes
    }
}
