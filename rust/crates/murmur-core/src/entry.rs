use chrono::{DateTime, Duration, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// ---------------------------------------------------------------------------
// Enums (ported from Enums.swift + Entry.swift)
// ---------------------------------------------------------------------------

/// AI-assigned entry category.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Default)]
#[serde(rename_all = "lowercase")]
pub enum EntryCategory {
    Todo,
    #[default]
    Note,
    Reminder,
    Idea,
    List,
    Habit,
    Question,
    Thought,
}

impl EntryCategory {
    pub fn display_name(&self) -> &'static str {
        match self {
            Self::Todo => "Todo",
            Self::Note => "Note",
            Self::Reminder => "Reminder",
            Self::Idea => "Idea",
            Self::List => "List",
            Self::Habit => "Habit",
            Self::Question => "Question",
            Self::Thought => "Thought",
        }
    }
}

/// How the entry was captured.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Default)]
#[serde(rename_all = "lowercase")]
pub enum EntrySource {
    #[default]
    Voice,
    Text,
}

impl EntrySource {
    pub fn display_name(&self) -> &'static str {
        match self {
            Self::Voice => "Voice",
            Self::Text => "Text",
        }
    }
}

/// How often a habit repeats.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum HabitCadence {
    Daily,
    Weekdays,
    Weekly,
    Monthly,
}

impl HabitCadence {
    pub fn display_name(&self) -> &'static str {
        match self {
            Self::Daily => "Daily",
            Self::Weekdays => "Weekdays",
            Self::Weekly => "Weekly",
            Self::Monthly => "Monthly",
        }
    }
}

/// Entry lifecycle status.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, Default)]
#[serde(rename_all = "lowercase")]
pub enum EntryStatus {
    #[default]
    Active,
    Completed,
    Archived,
    Snoozed,
}

impl EntryStatus {
    pub fn display_name(&self) -> &'static str {
        match self {
            Self::Active => "Active",
            Self::Completed => "Completed",
            Self::Archived => "Archived",
            Self::Snoozed => "Snoozed",
        }
    }
}

// ---------------------------------------------------------------------------
// Entry — the atomic unit of Murmur
// ---------------------------------------------------------------------------

/// Every voice/text input is interpreted, categorized, and stored as an Entry.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Entry {
    pub id: Uuid,

    /// Original voice-to-text transcription (full recording).
    pub transcript: String,

    /// AI-structured version of the transcript (cleaned/formatted).
    pub content: String,

    /// AI-assigned category.
    pub category: EntryCategory,

    /// The specific part of the transcript this entry was extracted from.
    pub source_text: String,

    /// When the entry was captured.
    pub created_at: DateTime<Utc>,

    /// When the entry was last modified.
    pub updated_at: DateTime<Utc>,

    // -- LLM-populated fields --
    /// One-liner summary for cards/lists.
    pub summary: String,

    /// User-added supplementary notes.
    pub notes: String,

    /// Priority 1-5 scale (1 = highest).
    pub priority: Option<i32>,

    /// Raw time phrase extracted by LLM (e.g. "next Thursday", "in 2 hours").
    pub due_date_description: Option<String>,

    /// Resolved date from due_date_description.
    pub due_date: Option<DateTime<Utc>>,

    /// How often this habit repeats.
    pub cadence: Option<HabitCadence>,

    // -- Status (app-managed, not LLM) --
    /// Entry lifecycle status.
    pub status: EntryStatus,

    /// When the entry was marked completed.
    pub completed_at: Option<DateTime<Utc>>,

    /// When a snoozed entry should resurface.
    pub snooze_until: Option<DateTime<Utc>>,

    // -- Source metadata --
    /// Recording length in seconds.
    pub audio_duration: Option<f64>,

    /// How the entry was captured.
    pub source: EntrySource,
}

impl Entry {
    pub fn new(
        transcript: String,
        content: String,
        category: EntryCategory,
        source_text: String,
        source: EntrySource,
    ) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            transcript,
            content,
            category,
            source_text,
            created_at: now,
            updated_at: now,
            summary: String::new(),
            notes: String::new(),
            priority: None,
            due_date_description: None,
            due_date: None,
            cadence: None,
            status: EntryStatus::Active,
            completed_at: None,
            snooze_until: None,
            audio_duration: None,
            source,
        }
    }

    /// Short ID for LLM context — first 6 chars of UUID, lowercased.
    pub fn short_id(&self) -> String {
        self.id.to_string()[..6].to_lowercase()
    }

    /// Mark entry as completed.
    pub fn complete(&mut self) {
        let now = Utc::now();
        self.status = EntryStatus::Completed;
        self.completed_at = Some(now);
        self.updated_at = now;
    }

    /// Archive the entry.
    pub fn archive(&mut self) {
        self.status = EntryStatus::Archived;
        self.updated_at = Utc::now();
    }

    /// Unarchive — return to active.
    pub fn unarchive(&mut self) {
        self.status = EntryStatus::Active;
        self.updated_at = Utc::now();
    }

    /// Snooze the entry. `None` means default 1 hour from now.
    pub fn snooze(&mut self, until: Option<DateTime<Utc>>) {
        let target = until.unwrap_or_else(|| Utc::now() + Duration::hours(1));
        self.snooze_until = Some(target);
        self.status = EntryStatus::Snoozed;
        self.updated_at = Utc::now();
    }

    /// Resolve a short ID prefix back to an Entry from a list.
    /// Returns `None` if zero or 2+ entries match (ambiguous).
    pub fn resolve_short_id<'a>(short_id: &str, entries: &'a [Entry]) -> Option<&'a Entry> {
        let lower = short_id.to_lowercase();
        let matches: Vec<_> = entries
            .iter()
            .filter(|e| e.id.to_string().to_lowercase().starts_with(&lower))
            .collect();
        if matches.len() == 1 {
            Some(matches[0])
        } else {
            None
        }
    }

    /// Resolve (mutable) a short ID prefix back to an Entry from a list.
    pub fn resolve_short_id_mut<'a>(
        short_id: &str,
        entries: &'a mut [Entry],
    ) -> Option<&'a mut Entry> {
        let lower = short_id.to_lowercase();
        let mut found_idx = None;
        let mut count = 0;
        for (i, e) in entries.iter().enumerate() {
            if e.id.to_string().to_lowercase().starts_with(&lower) {
                found_idx = Some(i);
                count += 1;
            }
        }
        if count == 1 {
            found_idx.map(move |i| &mut entries[i])
        } else {
            None
        }
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn create_entry_with_defaults() {
        let entry = Entry::new(
            "pick up dry cleaning tomorrow".into(),
            "Pick up dry cleaning".into(),
            EntryCategory::Todo,
            "pick up dry cleaning tomorrow".into(),
            EntrySource::Voice,
        );

        assert_eq!(entry.category, EntryCategory::Todo);
        assert_eq!(entry.status, EntryStatus::Active);
        assert_eq!(entry.source, EntrySource::Voice);
        assert_eq!(entry.content, "Pick up dry cleaning");
        assert!(entry.completed_at.is_none());
        assert!(entry.snooze_until.is_none());
        assert_eq!(entry.notes, "");
    }

    #[test]
    fn complete_entry() {
        let mut entry = Entry::new(
            "test".into(),
            "Test".into(),
            EntryCategory::Todo,
            "test".into(),
            EntrySource::Text,
        );
        entry.complete();
        assert_eq!(entry.status, EntryStatus::Completed);
        assert!(entry.completed_at.is_some());
    }

    #[test]
    fn archive_and_unarchive() {
        let mut entry = Entry::new(
            "test".into(),
            "Test".into(),
            EntryCategory::Note,
            "test".into(),
            EntrySource::Text,
        );
        entry.archive();
        assert_eq!(entry.status, EntryStatus::Archived);
        entry.unarchive();
        assert_eq!(entry.status, EntryStatus::Active);
    }

    #[test]
    fn snooze_default_one_hour() {
        let mut entry = Entry::new(
            "test".into(),
            "Test".into(),
            EntryCategory::Reminder,
            "test".into(),
            EntrySource::Voice,
        );
        let before = Utc::now();
        entry.snooze(None);
        assert_eq!(entry.status, EntryStatus::Snoozed);
        let snooze_target = entry.snooze_until.unwrap();
        // Should be roughly 1 hour from now (within 2 seconds tolerance)
        let diff = snooze_target - before;
        assert!(diff.num_minutes() >= 59 && diff.num_minutes() <= 61);
    }

    #[test]
    fn short_id_is_six_chars() {
        let entry = Entry::new(
            "test".into(),
            "Test".into(),
            EntryCategory::Note,
            "test".into(),
            EntrySource::Text,
        );
        assert_eq!(entry.short_id().len(), 6);
    }

    #[test]
    fn resolve_short_id_finds_unique_match() {
        let entries = vec![
            Entry::new("a".into(), "A".into(), EntryCategory::Note, "a".into(), EntrySource::Text),
            Entry::new("b".into(), "B".into(), EntryCategory::Todo, "b".into(), EntrySource::Text),
        ];
        let short = entries[0].short_id();
        let found = Entry::resolve_short_id(&short, &entries);
        assert!(found.is_some());
        assert_eq!(found.unwrap().id, entries[0].id);
    }

    #[test]
    fn serde_roundtrip() {
        let entry = Entry::new(
            "buy eggs".into(),
            "Buy eggs".into(),
            EntryCategory::Todo,
            "buy eggs".into(),
            EntrySource::Voice,
        );
        let json = serde_json::to_string(&entry).unwrap();
        let deserialized: Entry = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized.id, entry.id);
        assert_eq!(deserialized.category, EntryCategory::Todo);
        assert_eq!(deserialized.content, "Buy eggs");
    }

    #[test]
    fn category_display_names() {
        assert_eq!(EntryCategory::Todo.display_name(), "Todo");
        assert_eq!(EntryCategory::Habit.display_name(), "Habit");
        assert_eq!(EntryCategory::Question.display_name(), "Question");
    }

    #[test]
    fn default_category_is_note() {
        assert_eq!(EntryCategory::default(), EntryCategory::Note);
    }

    #[test]
    fn default_status_is_active() {
        assert_eq!(EntryStatus::default(), EntryStatus::Active);
    }
}
