import Foundation

/// Opaque conversation state for multi-turn LLM interactions.
/// Retains full message history including tool calls and model reasoning.
public final class LLMConversation: @unchecked Sendable {
    var messages: [[String: Any]] = []

    public init() {}
}

public enum LLMToolChoice: Sendable {
    case auto
    case function(name: String)

    var requestBodyValue: Any {
        switch self {
        case .auto:
            return "auto"
        case .function(let name):
            return ["type": "function", "function": ["name": name]]
        }
    }
}

/// Configuration for LLM extraction/agent turns: system prompt + tool definitions.
/// Define once, pass to any LLMService implementation.
public struct LLMPrompt: @unchecked Sendable {
    public let systemPrompt: String
    public let tools: [[String: Any]]
    public let toolChoice: LLMToolChoice

    public init(systemPrompt: String, tools: [[String: Any]], toolChoice: LLMToolChoice) {
        self.systemPrompt = systemPrompt
        self.tools = tools
        self.toolChoice = toolChoice
    }

    /// Agentic entry manager prompt (phase one): create/update/complete/archive tools.
    public static let entryManager = LLMPrompt(
        systemPrompt: """
            You are Murmur, a personal entry manager for voice input.

            You receive:
            1) A compact list of current entries (may be empty)
            2) New user transcript text from speech recognition (contains transcription errors)

            Your job is to decide which actions to take using tools:
            - create_entries: add genuinely new entries
            - update_entries: modify existing entry fields (including snooze via status + snooze_until)
            - complete_entries: mark entries done
            - archive_entries: remove no-longer-relevant entries

            Decision rules:
            - Prefer updating/completing existing entries over creating duplicates.
            - Use fuzzy semantic matching for references ("that one", "the dentist thing", garbled names).
            - If user says done/finished/completed, use complete_entries.
            - If user changes timing/priority/details, use update_entries.
            - Only create when intent is genuinely new.
            - If no current entries are provided, create_entries is usually appropriate.

            Create entry quality rules:
            - Produce concise card-style content, not long prose.
            - summary should be 10 words or fewer.
            - Keep due_date and snooze_until as the user's natural language phrase.
            - For habits, set cadence to daily/weekdays/weekly/monthly when clear.
            - Do not include urgency words in content when priority captures urgency.

            Mutation rules:
            - Every update/complete/archive item must include a short reason.
            - Use the provided entry id exactly as given in context.

            Output rules:
            - Use tool calls only.
            - Call multiple tools when needed.
            - Do not ask clarifying questions; take the best action.
            """,
        tools: [
            createEntriesToolSchema(),
            updateEntriesToolSchema(),
            completeEntriesToolSchema(),
            archiveEntriesToolSchema(),
        ],
        toolChoice: .auto
    )

    /// Backward-compatible extraction prompt for current UI flow.
    /// Uses only create_entries so existing confirm/save UI still works.
    public static let entryCreation = LLMPrompt(
        systemPrompt: """
            You are an extraction assistant for a voice-to-entries app.

            The transcript comes from speech recognition and can contain errors.
            Infer intended meaning and clean up wording.

            Extract intentional items the user wants to track (todo, reminder, note,
            idea, list, habit, question, thought). Skip filler and small talk.

            Return only create_entries tool calls. Each entry should include:
            - content: concise card text
            - category
            - source_text: relevant transcript span
            - summary: 10 words or fewer
            Optional: priority (1-5), due_date (verbatim phrase), cadence (for habits)
            """,
        tools: [createEntriesToolSchema()],
        toolChoice: .function(name: "create_entries")
    )

    @available(*, deprecated, message: "Use entryManager or entryCreation")
    public static let entryExtraction = entryCreation
}

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

    public init(
        id: String,
        summary: String,
        category: EntryCategory,
        priority: Int? = nil,
        dueDateDescription: String? = nil,
        cadence: HabitCadence? = nil,
        status: AgentEntryStatus = .active,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.summary = summary
        self.category = category
        self.priority = priority
        self.dueDateDescription = dueDateDescription
        self.cadence = cadence
        self.status = status
        self.createdAt = createdAt
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

    public init(
        content: String,
        category: EntryCategory,
        sourceText: String,
        summary: String,
        priority: Int? = nil,
        dueDateDescription: String? = nil,
        cadence: HabitCadence? = nil
    ) {
        self.content = content
        self.category = category
        self.sourceText = sourceText
        self.summary = summary
        self.priority = priority
        self.dueDateDescription = dueDateDescription
        self.cadence = cadence
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

    public init(
        content: String? = nil,
        summary: String? = nil,
        category: EntryCategory? = nil,
        priority: Int? = nil,
        dueDateDescription: String? = nil,
        cadence: HabitCadence? = nil,
        status: AgentEntryStatus? = nil,
        snoozeUntilDescription: String? = nil
    ) {
        self.content = content
        self.summary = summary
        self.category = category
        self.priority = priority
        self.dueDateDescription = dueDateDescription
        self.cadence = cadence
        self.status = status
        self.snoozeUntilDescription = snoozeUntilDescription
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

/// Typed actions produced by the agent.
public enum AgentAction: Sendable {
    case create(CreateAction)
    case update(UpdateAction)
    case complete(CompleteAction)
    case archive(ArchiveAction)
}

public extension AgentAction {
    var createdEntry: ExtractedEntry? {
        guard case .create(let action) = self else {
            return nil
        }

        return ExtractedEntry(
            content: action.content,
            category: action.category,
            sourceText: action.sourceText,
            summary: action.summary,
            priority: action.priority,
            dueDateDescription: action.dueDateDescription,
            cadence: action.cadence
        )
    }
}

/// The agent response for a single turn.
public struct AgentResponse: Sendable {
    public let actions: [AgentAction]
    public let summary: String
    public let usage: TokenUsage

    public init(actions: [AgentAction], summary: String, usage: TokenUsage) {
        self.actions = actions
        self.summary = summary
        self.usage = usage
    }
}

/// Protocol for the entry-management agent.
public protocol MurmurAgent: Sendable {
    func process(
        transcript: String,
        existingEntries: [AgentContextEntry],
        conversation: LLMConversation
    ) async throws -> AgentResponse
}

/// LLM-backed implementation contract.
/// Keeps extractEntries for current UI compatibility.
public protocol LLMService: MurmurAgent {
    /// Extract entries from a transcript with auto-categorization.
    /// This is a compatibility method for current extraction-first UI flows.
    func extractEntries(from transcript: String, conversation: LLMConversation) async throws -> LLMResult
}

public extension LLMService {
    func extractEntries(from transcript: String, conversation: LLMConversation) async throws -> LLMResult {
        let response = try await process(
            transcript: transcript,
            existingEntries: [],
            conversation: conversation
        )

        return LLMResult(
            entries: response.actions.compactMap(\.createdEntry),
            usage: response.usage
        )
    }
}

public struct LLMResult: Sendable {
    public let entries: [ExtractedEntry]
    public let usage: TokenUsage

    public init(entries: [ExtractedEntry], usage: TokenUsage) {
        self.entries = entries
        self.usage = usage
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

    enum CodingKeys: String, CodingKey {
        case content, category, sourceText, summary, priority, dueDateDescription, cadence
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
    }

    public init(
        content: String,
        category: EntryCategory,
        sourceText: String,
        summary: String = "",
        priority: Int? = nil,
        dueDateDescription: String? = nil,
        cadence: HabitCadence? = nil
    ) {
        self.id = UUID()
        self.content = content
        self.category = category
        self.sourceText = sourceText
        self.summary = summary
        self.priority = priority
        self.dueDateDescription = dueDateDescription
        self.cadence = cadence
    }
}

private extension LLMPrompt {
    static func createEntriesToolSchema() -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "create_entries",
                "description": "Create new entries from user intent",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "entries": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "content": [
                                        "type": "string",
                                        "description": "Cleaned, concise entry content",
                                    ],
                                    "category": [
                                        "type": "string",
                                        "enum": ["todo", "note", "reminder", "idea", "list", "habit", "question", "thought"],
                                    ],
                                    "source_text": [
                                        "type": "string",
                                        "description": "Relevant source span from transcript",
                                    ],
                                    "summary": [
                                        "type": "string",
                                        "description": "Card title, 10 words or fewer",
                                    ],
                                    "priority": ["type": "integer"],
                                    "due_date": ["type": "string"],
                                    "cadence": [
                                        "type": "string",
                                        "enum": ["daily", "weekdays", "weekly", "monthly"],
                                    ],
                                ] as [String: Any],
                                "required": ["content", "category", "source_text", "summary"],
                            ] as [String: Any],
                        ] as [String: Any],
                    ],
                    "required": ["entries"],
                ] as [String: Any],
            ] as [String: Any],
        ]
    }

    static func updateEntriesToolSchema() -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "update_entries",
                "description": "Update one or more existing entries",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "updates": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "id": ["type": "string"],
                                    "fields": [
                                        "type": "object",
                                        "properties": [
                                            "content": ["type": "string"],
                                            "summary": ["type": "string"],
                                            "category": [
                                                "type": "string",
                                                "enum": ["todo", "note", "reminder", "idea", "list", "habit", "question", "thought"],
                                            ],
                                            "priority": ["type": "integer"],
                                            "due_date": ["type": "string"],
                                            "cadence": [
                                                "type": "string",
                                                "enum": ["daily", "weekdays", "weekly", "monthly"],
                                            ],
                                            "status": [
                                                "type": "string",
                                                "enum": ["active", "snoozed", "completed", "archived"],
                                            ],
                                            "snooze_until": ["type": "string"],
                                        ] as [String: Any],
                                    ],
                                    "reason": [
                                        "type": "string",
                                        "description": "Why this update is being applied",
                                    ],
                                ] as [String: Any],
                                "required": ["id", "fields", "reason"],
                            ] as [String: Any],
                        ] as [String: Any],
                    ],
                    "required": ["updates"],
                ] as [String: Any],
            ] as [String: Any],
        ]
    }

    static func completeEntriesToolSchema() -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "complete_entries",
                "description": "Mark one or more existing entries as completed",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "entries": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "id": ["type": "string"],
                                    "reason": ["type": "string"],
                                ] as [String: Any],
                                "required": ["id", "reason"],
                            ] as [String: Any],
                        ] as [String: Any],
                    ],
                    "required": ["entries"],
                ] as [String: Any],
            ] as [String: Any],
        ]
    }

    static func archiveEntriesToolSchema() -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "archive_entries",
                "description": "Archive one or more existing entries",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "entries": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "id": ["type": "string"],
                                    "reason": ["type": "string"],
                                ] as [String: Any],
                                "required": ["id", "reason"],
                            ] as [String: Any],
                        ] as [String: Any],
                    ],
                    "required": ["entries"],
                ] as [String: Any],
            ] as [String: Any],
        ]
    }
}
