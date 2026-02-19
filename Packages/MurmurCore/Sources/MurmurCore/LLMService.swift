import Foundation

/// Opaque conversation state for multi-turn LLM interactions.
/// Retains full message history including tool calls and model reasoning.
public final class LLMConversation: @unchecked Sendable {
    var messages: [[String: Any]] = []

    public init() {}
}

/// Configuration for LLM extraction: system prompt + tool definitions.
/// Define once, pass to any LLMService implementation.
public struct LLMPrompt: @unchecked Sendable {
    public let systemPrompt: String
    public let tools: [[String: Any]]
    public let toolChoice: [String: Any]

    public init(systemPrompt: String, tools: [[String: Any]], toolChoice: [String: Any]) {
        self.systemPrompt = systemPrompt
        self.tools = tools
        self.toolChoice = toolChoice
    }

    /// Default prompt for extracting entries from voice transcripts.
    public static let entryExtraction = LLMPrompt(
        systemPrompt: """
            You are an extraction assistant for a voice-to-entries app. \
            The user provides transcribed speech (from Apple Speech-to-Text). \
            \
            TRANSCRIPTION AWARENESS: \
            The transcript comes from automatic speech recognition and WILL contain errors. \
            Proper nouns, names, technical terms, and uncommon words are frequently \
            mistranscribed as similar-sounding common words. Use context to infer the \
            intended meaning. For example: a person's name transcribed as a common word, \
            a brand name split into separate words, or technical jargon simplified. \
            Always clean up and correct likely transcription errors in the content you produce. \
            If the speaker corrects themselves ("actually not X, I mean Y"), use only the corrected version. \
            \
            EXTRACTION RULES: \
            Extract actionable items, notes, reminders, ideas, lists, habits, questions, \
            and thoughts that the speaker intentionally wants to record or revisit. \
            Skip conversational filler, small talk, rhetorical musings, and casual observations \
            that nobody would want stored as a card. \
            If the speaker mentions the same item multiple times in different words, \
            merge them into a single entry using the most detailed or final version. \
            Use the provided tool to return the extracted items. \
            Each item should have cleaned/structured content, an appropriate category, \
            the relevant source text from the transcript, and a short summary \
            (10 words or fewer — think card title, not description). \
            \
            CONTENT STYLE: \
            Content should read like a concise card or sticky note, not a sentence from an essay. \
            Write in a natural, human voice — the way someone would jot a quick note to themselves. \
            Do NOT echo urgency or priority language in the content \
            (e.g. don't write "This is urgent" or "(urgent)" — that's what the priority field is for). \
            Do NOT include meta-commentary like "This is important" or "Absolutely must do this". \
            Keep useful context (e.g. "leak has been going on for 2 weeks") but drop emotional emphasis. \
            No trailing periods on short card-style content. \
            \
            PRIORITY: \
            For actionable items (todos, reminders), assign a priority from 1 (highest) to 5 (lowest). \
            Priority reflects a combination of importance and urgency. \
            Items due sooner should generally receive higher priority \
            unless the speaker explicitly indicates otherwise (e.g. "low priority but do it today"). \
            Interpret verbal cues: "highest priority" / "critical" / "most urgent" → P1. \
            "high priority" / "really urgent" / "important" → P1. \
            "normal" / no urgency cue → P3. \
            "low priority" / "when I get a chance" → P4. \
            "eventually" / "someday" / "no rush" → P5. \
            When the user explicitly says "high priority" or "mark it urgent", use P1. \
            \
            DUE DATES: \
            If the text mentions a time or date phrase (e.g. "next Thursday", "in two hours", \
            "by end of week"), extract it verbatim into the due_date field. \
            Only include due_date if there is an explicit time reference. \
            IMPORTANT: Distinguish between TASK deadlines and EVENT dates. \
            If a time phrase describes when a related event occurs (a BBQ, conference, party, etc.) \
            and the task is something to do BEFORE that event \
            (e.g. "DM Jake about the BBQ Saturday", "book flights for the conference in two weeks"), \
            do NOT use the event date as due_date — omit due_date entirely for these. \
            Only set due_date when the time phrase is the actual deadline for completing the task. \
            \
            CATEGORIES: \
            Use "reminder" for anything time-bound the speaker wants to remember \
            (appointments, meetings, deadlines they might forget). \
            Only use "question" for things the speaker genuinely wants answered or looked up, \
            not rhetorical musings or wondering aloud. \
            Only use "thought" for reflections the speaker seems to intentionally want to capture, \
            not passing observations. \
            \
            MULTI-TURN REFINEMENT: \
            In follow-up messages, the user may ask you to modify your previous extraction. \
            They are speaking conversationally — things like "change the first one", \
            "remove that reminder", "make it higher priority", "add a note about X". \
            The speech-to-text will often garble names and references to your previous entries. \
            Use fuzzy/semantic matching to figure out which entry they mean. \
            Apply their changes, keep everything they didn't mention, add anything new, \
            and return the complete updated list.
            """,
        tools: [
            [
                "type": "function",
                "function": [
                    "name": "extract_entries",
                    "description": "Extract structured entries from a voice transcript",
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
                                            "description": "The cleaned, structured content of the entry",
                                        ],
                                        "category": [
                                            "type": "string",
                                            "enum": ["todo", "note", "reminder", "idea", "list", "habit", "question", "thought"],
                                            // swiftlint:disable:next line_length
                                            "description": "The category: todo (actionable task), note (informational), reminder (time-bound), idea (creative/conceptual), list (multi-item), habit (recurring behavior), question (genuinely wants answered — not rhetorical), thought (intentional reflection — not small talk)",
                                        ],
                                        "source_text": [
                                            "type": "string",
                                            "description": "The relevant portion of the original transcript this was extracted from",
                                        ],
                                        "summary": [
                                            "type": "string",
                                            "description": "Card title, 10 words or fewer (e.g. 'Buy groceries', 'Dentist appointment Thursday')",
                                        ],
                                        "priority": [
                                            "type": "integer",
                                            "description": "Priority 1-5 (1=highest). Reflects importance + urgency. Sooner deadline = higher priority unless speaker says otherwise.",
                                        ],
                                        "due_date": [
                                            "type": "string",
                                            "description": "Verbatim time/date phrase from the transcript, if any (e.g. 'next Thursday', 'by Friday')",
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
        ],
        toolChoice: ["type": "function", "function": ["name": "extract_entries"]]
    )
}

/// A service that uses an LLM to extract and categorize entries from transcripts.
public protocol LLMService: Sendable {
    /// Extract entries from a transcript with auto-categorization.
    /// The conversation accumulates message history across calls —
    /// pass the same instance for multi-turn refinement.
    func extractEntries(from transcript: String, conversation: LLMConversation) async throws -> [ExtractedEntry]
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

    enum CodingKeys: String, CodingKey {
        case content, category, sourceText, summary, priority, dueDateDescription
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
    }

    public init(
        content: String,
        category: EntryCategory,
        sourceText: String,
        summary: String = "",
        priority: Int? = nil,
        dueDateDescription: String? = nil
    ) {
        self.id = UUID()
        self.content = content
        self.category = category
        self.sourceText = sourceText
        self.summary = summary
        self.priority = priority
        self.dueDateDescription = dueDateDescription
    }
}
