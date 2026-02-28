use chrono::{DateTime, Utc};
use serde_json::json;

use crate::action::AgentResultAction;
use crate::entry::{Entry, EntryCategory, EntryStatus, HabitCadence};

// ---------------------------------------------------------------------------
// AgentContextEntry — compact entry snapshot for LLM context
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct AgentContextEntry {
    pub id: String,
    pub summary: String,
    pub category: EntryCategory,
    pub priority: Option<i32>,
    pub due_date_description: Option<String>,
    pub cadence: Option<HabitCadence>,
    pub status: EntryStatus,
    pub created_at: DateTime<Utc>,
}

impl Entry {
    /// Create a compact snapshot for LLM context.
    pub fn to_agent_context(&self) -> AgentContextEntry {
        AgentContextEntry {
            id: self.short_id(),
            summary: self.summary.clone(),
            category: self.category,
            priority: self.priority,
            due_date_description: self.due_date_description.clone(),
            cadence: self.cadence,
            status: self.status,
            created_at: self.created_at,
        }
    }
}

// ---------------------------------------------------------------------------
// AgentResponse + TokenUsage — domain types for agent results
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct AgentResponse {
    pub actions: Vec<AgentResultAction>,
    pub summary: String,
    pub usage: TokenUsage,
}

#[derive(Debug, Clone, Default)]
pub struct TokenUsage {
    pub input_tokens: u32,
    pub output_tokens: u32,
}

// ---------------------------------------------------------------------------
// System prompt
// ---------------------------------------------------------------------------

pub const ENTRY_MANAGER_SYSTEM_PROMPT: &str = "\
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
- Use fuzzy semantic matching for references (\"that one\", \"the dentist thing\", garbled names).
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
- Do not ask clarifying questions; take the best action.";

// ---------------------------------------------------------------------------
// Tool schemas
// ---------------------------------------------------------------------------

pub fn tool_schemas() -> serde_json::Value {
    json!([
        {
            "type": "function",
            "function": {
                "name": "create_entries",
                "description": "Create new entries from user intent",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "entries": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "content": {
                                        "type": "string",
                                        "description": "Cleaned, concise entry content"
                                    },
                                    "category": {
                                        "type": "string",
                                        "enum": ["todo", "note", "reminder", "idea", "list", "habit", "question", "thought"]
                                    },
                                    "source_text": {
                                        "type": "string",
                                        "description": "Relevant source span from transcript"
                                    },
                                    "summary": {
                                        "type": "string",
                                        "description": "Card title, 10 words or fewer"
                                    },
                                    "priority": { "type": "integer" },
                                    "due_date": { "type": "string" },
                                    "cadence": {
                                        "type": "string",
                                        "enum": ["daily", "weekdays", "weekly", "monthly"]
                                    }
                                },
                                "required": ["content", "category", "source_text", "summary"]
                            }
                        }
                    },
                    "required": ["entries"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "update_entries",
                "description": "Update one or more existing entries",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "updates": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "id": { "type": "string" },
                                    "fields": {
                                        "type": "object",
                                        "properties": {
                                            "content": { "type": "string" },
                                            "summary": { "type": "string" },
                                            "category": {
                                                "type": "string",
                                                "enum": ["todo", "note", "reminder", "idea", "list", "habit", "question", "thought"]
                                            },
                                            "priority": { "type": "integer" },
                                            "due_date": { "type": "string" },
                                            "cadence": {
                                                "type": "string",
                                                "enum": ["daily", "weekdays", "weekly", "monthly"]
                                            },
                                            "status": {
                                                "type": "string",
                                                "enum": ["active", "snoozed", "completed", "archived"]
                                            },
                                            "snooze_until": { "type": "string" }
                                        }
                                    },
                                    "reason": {
                                        "type": "string",
                                        "description": "Why this update is being applied"
                                    }
                                },
                                "required": ["id", "fields", "reason"]
                            }
                        }
                    },
                    "required": ["updates"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "complete_entries",
                "description": "Mark one or more existing entries as completed",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "entries": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "id": { "type": "string" },
                                    "reason": { "type": "string" }
                                },
                                "required": ["id", "reason"]
                            }
                        }
                    },
                    "required": ["entries"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "archive_entries",
                "description": "Archive one or more existing entries",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "entries": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "id": { "type": "string" },
                                    "reason": { "type": "string" }
                                },
                                "required": ["id", "reason"]
                            }
                        }
                    },
                    "required": ["entries"]
                }
            }
        }
    ])
}

// ---------------------------------------------------------------------------
// Context formatting
// ---------------------------------------------------------------------------

/// Build the user content for the LLM request.
/// If no entries, returns just the transcript.
/// Otherwise builds a markdown document with current entries and transcript.
pub fn format_user_content(transcript: &str, entries: &[AgentContextEntry]) -> String {
    if entries.is_empty() {
        return transcript.to_string();
    }

    let mut sorted: Vec<&AgentContextEntry> = entries.iter().collect();
    sorted.sort_by(|a, b| {
        let a_pri = a.priority.unwrap_or(6);
        let b_pri = b.priority.unwrap_or(6);
        a_pri.cmp(&b_pri).then_with(|| b.created_at.cmp(&a.created_at))
    });

    let mut lines = vec!["## Current Entries".to_string(), String::new()];
    for entry in sorted {
        lines.push(format_context_line(entry));
    }
    lines.push(String::new());
    lines.push("## User Transcript".to_string());
    lines.push(transcript.to_string());

    lines.join("\n")
}

fn format_context_line(entry: &AgentContextEntry) -> String {
    let category_upper = category_as_str(entry.category).to_uppercase();
    let mut line = format!("- [{}] {}", entry.id, category_upper);

    if let Some(priority) = entry.priority {
        line.push_str(&format!(" P{}", priority));
    }

    let summary = clean_string(&entry.summary).unwrap_or_else(|| "(no summary)".to_string());
    line.push_str(&format!(" \"{}\"", summary));

    if let Some(ref due) = entry.due_date_description {
        if let Some(cleaned) = clean_string(due) {
            line.push_str(&format!(" due:{}", cleaned));
        }
    }

    if let Some(cadence) = entry.cadence {
        line.push_str(&format!(" cadence:{}", cadence_as_str(cadence)));
    }

    if entry.status != EntryStatus::Active {
        line.push_str(&format!(" status:{}", status_as_str(entry.status)));
    }

    line
}

fn clean_string(s: &str) -> Option<String> {
    let normalized = s.replace('\n', " ").replace('\t', " ");
    let trimmed = normalized.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_string())
    }
}

fn category_as_str(c: EntryCategory) -> &'static str {
    match c {
        EntryCategory::Todo => "todo",
        EntryCategory::Note => "note",
        EntryCategory::Reminder => "reminder",
        EntryCategory::Idea => "idea",
        EntryCategory::List => "list",
        EntryCategory::Habit => "habit",
        EntryCategory::Question => "question",
        EntryCategory::Thought => "thought",
    }
}

fn status_as_str(s: EntryStatus) -> &'static str {
    match s {
        EntryStatus::Active => "active",
        EntryStatus::Completed => "completed",
        EntryStatus::Archived => "archived",
        EntryStatus::Snoozed => "snoozed",
    }
}

fn cadence_as_str(c: HabitCadence) -> &'static str {
    match c {
        HabitCadence::Daily => "daily",
        HabitCadence::Weekdays => "weekdays",
        HabitCadence::Weekly => "weekly",
        HabitCadence::Monthly => "monthly",
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::entry::EntrySource;
    use chrono::TimeZone;

    #[test]
    fn format_user_content_no_entries() {
        let result = format_user_content("buy milk", &[]);
        assert_eq!(result, "buy milk");
    }

    #[test]
    fn format_user_content_single_entry() {
        let entry = AgentContextEntry {
            id: "abc123".to_string(),
            summary: "Buy groceries".to_string(),
            category: EntryCategory::Todo,
            priority: Some(2),
            due_date_description: Some("tomorrow".to_string()),
            cadence: None,
            status: EntryStatus::Active,
            created_at: Utc.with_ymd_and_hms(2026, 1, 1, 0, 0, 0).unwrap(),
        };

        let result = format_user_content("done with groceries", &[entry]);
        assert!(result.contains("## Current Entries"));
        assert!(result.contains("- [abc123] TODO P2 \"Buy groceries\" due:tomorrow"));
        assert!(result.contains("## User Transcript"));
        assert!(result.contains("done with groceries"));
        // Active status should NOT be shown
        assert!(!result.contains("status:"));
    }

    #[test]
    fn format_user_content_sorts_by_priority_then_created_at() {
        let entries = vec![
            AgentContextEntry {
                id: "low_pri".to_string(),
                summary: "Low priority".to_string(),
                category: EntryCategory::Note,
                priority: Some(5),
                due_date_description: None,
                cadence: None,
                status: EntryStatus::Active,
                created_at: Utc.with_ymd_and_hms(2026, 1, 3, 0, 0, 0).unwrap(),
            },
            AgentContextEntry {
                id: "high_pr".to_string(),
                summary: "High priority".to_string(),
                category: EntryCategory::Todo,
                priority: Some(1),
                due_date_description: None,
                cadence: None,
                status: EntryStatus::Active,
                created_at: Utc.with_ymd_and_hms(2026, 1, 1, 0, 0, 0).unwrap(),
            },
            AgentContextEntry {
                id: "no_prio".to_string(),
                summary: "No priority".to_string(),
                category: EntryCategory::Idea,
                priority: None,
                due_date_description: None,
                cadence: None,
                status: EntryStatus::Completed,
                created_at: Utc.with_ymd_and_hms(2026, 1, 2, 0, 0, 0).unwrap(),
            },
        ];

        let result = format_user_content("test", &entries);
        let entry_lines: Vec<&str> = result
            .lines()
            .filter(|l| l.starts_with("- ["))
            .collect();

        assert_eq!(entry_lines.len(), 3);
        // P1 first, P5 second, None (treated as 6) last
        assert!(entry_lines[0].contains("high_pr"));
        assert!(entry_lines[1].contains("low_pri"));
        assert!(entry_lines[2].contains("no_prio"));
        // Non-active status should be shown
        assert!(entry_lines[2].contains("status:completed"));
    }

    #[test]
    fn format_user_content_same_priority_sorts_by_newest_first() {
        let entries = vec![
            AgentContextEntry {
                id: "older_".to_string(),
                summary: "Older".to_string(),
                category: EntryCategory::Todo,
                priority: Some(2),
                due_date_description: None,
                cadence: None,
                status: EntryStatus::Active,
                created_at: Utc.with_ymd_and_hms(2026, 1, 1, 0, 0, 0).unwrap(),
            },
            AgentContextEntry {
                id: "newer_".to_string(),
                summary: "Newer".to_string(),
                category: EntryCategory::Todo,
                priority: Some(2),
                due_date_description: None,
                cadence: None,
                status: EntryStatus::Active,
                created_at: Utc.with_ymd_and_hms(2026, 1, 5, 0, 0, 0).unwrap(),
            },
        ];

        let result = format_user_content("test", &entries);
        let entry_lines: Vec<&str> = result
            .lines()
            .filter(|l| l.starts_with("- ["))
            .collect();

        assert_eq!(entry_lines.len(), 2);
        // Newer first when same priority
        assert!(entry_lines[0].contains("newer_"));
        assert!(entry_lines[1].contains("older_"));
    }

    #[test]
    fn entry_to_agent_context_produces_correct_snapshot() {
        let mut entry = Entry::new(
            "test transcript".into(),
            "Test content".into(),
            EntryCategory::Todo,
            "test".into(),
            EntrySource::Text,
        );
        entry.summary = "Test summary".into();
        entry.priority = Some(3);
        entry.due_date_description = Some("next week".into());
        entry.cadence = Some(HabitCadence::Weekly);

        let ctx = entry.to_agent_context();

        assert_eq!(ctx.id, entry.short_id());
        assert_eq!(ctx.summary, "Test summary");
        assert_eq!(ctx.category, EntryCategory::Todo);
        assert_eq!(ctx.priority, Some(3));
        assert_eq!(ctx.due_date_description.as_deref(), Some("next week"));
        assert_eq!(ctx.cadence, Some(HabitCadence::Weekly));
        assert_eq!(ctx.status, EntryStatus::Active);
        assert_eq!(ctx.created_at, entry.created_at);
    }

    #[test]
    fn tool_schemas_has_four_tools() {
        let schemas = tool_schemas();
        let arr = schemas.as_array().unwrap();
        assert_eq!(arr.len(), 4);

        let names: Vec<&str> = arr
            .iter()
            .map(|t| t["function"]["name"].as_str().unwrap())
            .collect();

        assert!(names.contains(&"create_entries"));
        assert!(names.contains(&"update_entries"));
        assert!(names.contains(&"complete_entries"));
        assert!(names.contains(&"archive_entries"));
    }

    #[test]
    fn format_context_line_shows_cadence() {
        let entry = AgentContextEntry {
            id: "hab123".to_string(),
            summary: "Morning run".to_string(),
            category: EntryCategory::Habit,
            priority: None,
            due_date_description: None,
            cadence: Some(HabitCadence::Daily),
            status: EntryStatus::Active,
            created_at: Utc::now(),
        };

        let result = format_user_content("test", &[entry]);
        assert!(result.contains("cadence:daily"));
        assert!(result.contains("HABIT"));
    }

    #[test]
    fn format_context_line_shows_snoozed_status() {
        let entry = AgentContextEntry {
            id: "snz123".to_string(),
            summary: "Snoozed item".to_string(),
            category: EntryCategory::Reminder,
            priority: Some(1),
            due_date_description: None,
            cadence: None,
            status: EntryStatus::Snoozed,
            created_at: Utc::now(),
        };

        let result = format_user_content("test", &[entry]);
        assert!(result.contains("status:snoozed"));
    }
}
