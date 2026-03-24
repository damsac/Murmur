import Foundation

/// Configuration for LLM extraction/agent turns: system prompt + tool definitions.
/// Define once, pass to any MurmurAgent implementation.
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
            - update_list_items: manage checklist items on list entries
            - complete_entries: mark entries done
            - archive_entries: remove no-longer-relevant entries

            Decision rules:
            - Prefer updating/completing existing entries over creating duplicates.
            - Use fuzzy semantic matching for references ("that one", "the dentist thing", garbled names).
            - If user says done/finished/completed a non-habit entry, use complete_entries.
            - For habits: when user says they did/completed their habit, use update_entries
              with check_off_habit: true. Marks it done for the period, keeps it active.
              Do NOT use complete_entries for habits — that archives them permanently.
            - If user changes timing/priority/details, use update_entries.
            - Only create when intent is genuinely new.
            - If no current entries are provided, create_entries is usually appropriate.

            Create entry quality rules:
            - Produce concise card-style content, not long prose.
            - summary should be 10 words or fewer.
            - Set due_date as an ISO 8601 datetime string resolved from the current time (e.g. "2025-03-17T15:30:00"). Always set it when the user mentions any time reference.
            - Keep snooze_until as the user's natural language phrase.
            - For habits, set cadence to daily/weekdays/weekly/monthly when clear.
            - Priority 1-5 (1=highest). Default 3 unless words signal urgency ("urgent", "ASAP", "critical" → 1-2) or low importance ("whenever", "someday" → 4-5).
            - Do not include urgency words in content when priority captures urgency.
            - For list entries, format content as markdown checkboxes: "- [ ] item" or "- [x] item".

            List entry rules:
            - For list entries, use update_list_items to manage checklist items. Format each item with text and checked status.
            - Use update_list_items instead of update_entries when modifying list items.

            Mutation rules:
            - Every update/complete/archive item must include a short reason.
            - Use the provided entry id exactly as given in context.

            Output rules:
            - Use tool calls for all entry operations.
            - After tool calls, include a brief status message (under 15 words) summarizing what you did.
              Examples: "Added 2 reminders for tomorrow", "Marked dentist appointment complete", "Updated grocery list with 3 items"
              This message appears as a notification to the user — be concise and specific.
            - Call multiple tools when needed.
            - Act decisively on clear inputs — never ask for confirmation on straightforward requests.
            - When genuinely ambiguous (e.g., multiple entries match, or intent unclear), use confirm_actions to propose what you'd do — the user sees a preview and confirms or declines.

            Memory rules:
            - You have persistent memory across sessions via update_memory.
            - Store: user preferences, naming patterns, recurring schedules, vocabulary corrections.
            - Do NOT store entry data (already in context). Keep under 500 words.
            - Replace full content each time. Only update when you learn something new.

            Layout tools:
            - get_current_layout reads the current home screen layout as JSON.
            - update_layout applies incremental changes as an animated batch.
            - After entry operations, call get_current_layout then update_layout to reflect changes.
            - If the layout is empty (cold start), build it with add_section + insert_entry.
            - Calling update_layout is optional — entries without placement appear above the layout.
            - See ## Layout Instructions in the user message for the active layout style.
            """,
        tools: [
            createEntriesToolSchema(),
            updateEntriesToolSchema(),
            updateListItemsToolSchema(),
            completeEntriesToolSchema(),
            archiveEntriesToolSchema(),
            updateMemoryToolSchema(),
            confirmActionsToolSchema(),
            getCurrentLayoutToolSchema(),
            updateLayoutToolSchema(),
        ],
        toolChoice: .auto
    )

    /// Home composition prompt: composes the entire home screen layout via compose_view tool.
    public static let homeComposition = LLMPrompt(
        systemPrompt: """
            You are composing a home screen for a personal voice assistant app.
            You receive the user's current entries. Compose 3-5 sections showing what matters RIGHT NOW.

            Rules:
            - Most entries stay hidden. Show up to 7 items total.
            - Group by urgency and context, NOT by category.
            - First section: what needs attention now (overdue, due today, P1/P2). Use relaxed density, hero emphasis for urgent items.
            - Later sections: things to keep in mind, upcoming items. Use compact density.
            - Include a brief message (under 15 words) if it adds context. Don't force one.
            - Assign badges: "Overdue" for past-due, "Today" for due today, "Stale" for untouched 7+ days.
            - Use hero emphasis sparingly (1-2 items max). Compact for low-priority items.
            - If nothing is urgent, compose a calm view with a reassuring message.
            - If no entries exist, return zero sections.
            """,
        tools: [composeViewToolSchema()],
        toolChoice: .function(name: "compose_view")
    )

    /// Navigator composition prompt: category-grouped, up to 7 items, with briefing.
    public static let navigatorComposition = LLMPrompt(
        systemPrompt: """
            You are composing a home screen for a personal voice assistant app.
            You receive the user's current entries. Select up to 7 entries that deserve attention today.

            Rules:
            - One section per category (section title = category name lowercase: todo, reminder, habit, note, idea, list, question).
            - Only include categories that have selected entries — don't create empty sections.
            - Use relaxed density for all sections.
            - Use standard emphasis for all entries.
            - Badge = short human-readable reason this entry needs attention: "Overdue", "Due today", "High priority", "New", "Stale".
            - Produce a briefing: one friendly sentence summarizing what the day looks like.
              Example: "You have 3 things due today and a habit to maintain."
            - No inline message items — use the briefing field instead.
            - If nothing deserves focus, return zero sections and a calm briefing like "All clear — nothing pressing today."

            Selection criteria (in priority order):
            1. Overdue entries (due date has passed)
            2. Due today
            3. High priority (P1, P2)
            4. Stale entries (created long ago, never updated)
            5. Habits not yet done for the current period
            """,
        tools: [composeViewToolSchema()],
        toolChoice: .function(name: "compose_view")
    )

    /// Layout refresh prompt: compare current layout against entries, output diffs only.
    public static let layoutRefresh = LLMPrompt(
        systemPrompt: """
            You are refreshing a home screen layout for a voice assistant app.
            You receive the current layout (JSON) and the current entries.
            Compare them and output update_layout operations to bring the layout up to date.

            Rules:
            - Remove entries no longer active (completed, archived, deleted).
            - Add entries that deserve attention but are missing from the layout.
            - Update badges based on current dates: "Overdue" if past due, "Today" if due today, etc.
            - Move entries whose urgency or context has changed.
            - Update emphasis if priority has shifted.
            - Preserve the overall layout structure — minimize churn.
            - If no changes are needed, call update_layout with an empty operations array.
            - See ## Layout Instructions for the active layout style constraints.

            Always call update_layout exactly once.
            """,
        tools: [updateLayoutToolSchema()],
        toolChoice: .function(name: "update_layout")
    )
}

// MARK: - Tool Schema Builders

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
                                        "enum": ["todo", "note", "reminder", "idea", "list", "habit", "question"],
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
                                    "notes": [
                                        "type": "string",
                                        "description": "Supplementary notes for the entry",
                                    ] as [String: Any],
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
                                                "enum": ["todo", "note", "reminder", "idea", "list", "habit", "question"],
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
                                            "check_off_habit": [
                                                "type": "boolean",
                                                "description": "Mark a habit as done for its current period (daily/weekly/monthly). Do NOT use complete_entries for habits.",
                                            ] as [String: Any],
                                            "notes": [
                                                "type": "string",
                                                "description": "Supplementary notes for the entry",
                                            ] as [String: Any],
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

    static func updateListItemsToolSchema() -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "update_list_items",
                "description": "Update the items in a list entry. Use this instead of update_entries when modifying list items.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "entry_id": [
                            "type": "string",
                            "description": "ID of the list entry to update",
                        ],
                        "items": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "text": ["type": "string"],
                                    "checked": ["type": "boolean"],
                                ] as [String: Any],
                                "required": ["text", "checked"],
                            ] as [String: Any],
                        ] as [String: Any],
                    ],
                    "required": ["entry_id", "items"],
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

    static func getCurrentLayoutToolSchema() -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "get_current_layout",
                "description": "Read the current home screen layout. Returns sections with their entries, emphasis levels, and badges. Call this before update_layout to understand what's on screen.",
                "parameters": [
                    "type": "object",
                    "properties": [:] as [String: Any],
                ] as [String: Any],
            ] as [String: Any],
        ]
    }

    static func updateLayoutToolSchema() -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "update_layout",
                "description": """
                    Apply incremental changes to the home screen layout. Operations are applied in order \
                    as a single animated transaction. Use after create_entries/complete_entries/update_entries \
                    to place or remove entries on screen. For a fresh layout (cold start), use a batch of \
                    add_section + insert_entry operations.
                    """,
                "parameters": [
                    "type": "object",
                    "properties": [
                        "operations": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "op": [
                                        "type": "string",
                                        "enum": ["add_section", "remove_section", "update_section",
                                                 "insert_entry", "remove_entry", "move_entry", "update_entry"],
                                    ],
                                    "title": ["type": "string", "description": "Section title (for section ops)"],
                                    "density": ["type": "string", "enum": ["compact", "relaxed"]],
                                    "position": ["type": "integer", "description": "0-indexed position (optional, omit to append)"],
                                    "new_title": ["type": "string", "description": "New title for update_section"],
                                    "entry_id": ["type": "string", "description": "Entry short ID (for entry ops)"],
                                    "section": ["type": "string", "description": "Target section title (for insert_entry)"],
                                    "to_section": ["type": "string", "description": "Destination section (for move_entry)"],
                                    "to_position": ["type": "integer", "description": "Destination position (for move_entry)"],
                                    "emphasis": ["type": "string", "enum": ["hero", "standard", "compact"]],
                                    "badge": ["type": "string", "description": "Badge text: Overdue, Today, New, Stale, etc."],
                                ] as [String: Any],
                                "required": ["op"],
                            ] as [String: Any],
                        ] as [String: Any],
                    ],
                    "required": ["operations"],
                ] as [String: Any],
            ] as [String: Any],
        ]
    }

    static func composeViewToolSchema() -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "compose_view",
                "description": "Compose the home view. Surface what matters right now. Most entries stay hidden. Group by urgency/context, not category. 3-5 sections max, up to 7 total items.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "sections": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "title": ["type": "string"],
                                    "density": [
                                        "type": "string",
                                        "enum": ["compact", "relaxed"],
                                    ],
                                    "items": [
                                        "type": "array",
                                        "items": [
                                            "type": "object",
                                            "properties": [
                                                "type": [
                                                    "type": "string",
                                                    "enum": ["entry", "message"],
                                                ],
                                                "id": ["type": "string"],
                                                "emphasis": [
                                                    "type": "string",
                                                    "enum": ["hero", "standard", "compact"],
                                                ],
                                                "badge": ["type": "string"],
                                                "text": ["type": "string"],
                                            ] as [String: Any],
                                            "required": ["type"],
                                        ] as [String: Any],
                                    ] as [String: Any],
                                ] as [String: Any],
                                "required": ["items"],
                            ] as [String: Any],
                        ] as [String: Any],
                        "briefing": [
                            "type": "string",
                            "description": "One friendly sentence summarizing the day",
                        ] as [String: Any],
                    ],
                    "required": ["sections"],
                ] as [String: Any],
            ] as [String: Any],
        ]
    }

    static func updateMemoryToolSchema() -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "update_memory",
                "description": "Replace your persistent memory with updated content. Called when you learn something new about the user.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "content": [
                            "type": "string",
                            "description": "Full replacement text for your memory. Keep under 500 words.",
                        ],
                    ],
                    "required": ["content"],
                ] as [String: Any],
            ] as [String: Any],
        ]
    }

    static func confirmActionsToolSchema() -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "confirm_actions",
                "description": "Propose actions for user confirmation when intent is ambiguous. The user sees a preview and confirms or declines.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "message": [
                            "type": "string",
                            "description": "Brief explanation of the ambiguity, under 20 words",
                        ],
                        "actions": [
                            "type": "array",
                            "description": "Proposed actions to preview",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "tool": [
                                        "type": "string",
                                        "enum": ["create_entries", "update_entries", "update_list_items",
                                                 "complete_entries", "archive_entries"],
                                        "description": "Which tool to call if confirmed",
                                    ],
                                    "arguments": [
                                        "type": "object",
                                        "description": "Arguments in the same format as the respective tool",
                                    ],
                                ] as [String: Any],
                                "required": ["tool", "arguments"],
                            ] as [String: Any],
                        ] as [String: Any],
                    ] as [String: Any],
                    "required": ["message", "actions"],
                ] as [String: Any],
            ] as [String: Any],
        ]
    }
}
