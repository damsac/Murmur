use chrono::{DateTime, Utc};
use rusqlite::{params, Connection, Result};
use uuid::Uuid;

use crate::entry::{Entry, EntryCategory, EntrySource, EntryStatus, HabitCadence};

// ---------------------------------------------------------------------------
// Enum <-> string helpers (matches serde rename_all = "lowercase")
// ---------------------------------------------------------------------------

fn category_to_str(c: EntryCategory) -> &'static str {
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

fn str_to_category(s: &str) -> EntryCategory {
    match s {
        "todo" => EntryCategory::Todo,
        "note" => EntryCategory::Note,
        "reminder" => EntryCategory::Reminder,
        "idea" => EntryCategory::Idea,
        "list" => EntryCategory::List,
        "habit" => EntryCategory::Habit,
        "question" => EntryCategory::Question,
        "thought" => EntryCategory::Thought,
        _ => EntryCategory::Note,
    }
}

fn source_to_str(s: EntrySource) -> &'static str {
    match s {
        EntrySource::Voice => "voice",
        EntrySource::Text => "text",
    }
}

fn str_to_source(s: &str) -> EntrySource {
    match s {
        "voice" => EntrySource::Voice,
        "text" => EntrySource::Text,
        _ => EntrySource::Text,
    }
}

fn status_to_str(s: EntryStatus) -> &'static str {
    match s {
        EntryStatus::Active => "active",
        EntryStatus::Completed => "completed",
        EntryStatus::Archived => "archived",
        EntryStatus::Snoozed => "snoozed",
    }
}

fn str_to_status(s: &str) -> EntryStatus {
    match s {
        "active" => EntryStatus::Active,
        "completed" => EntryStatus::Completed,
        "archived" => EntryStatus::Archived,
        "snoozed" => EntryStatus::Snoozed,
        _ => EntryStatus::Active,
    }
}

fn cadence_to_str(c: HabitCadence) -> &'static str {
    match c {
        HabitCadence::Daily => "daily",
        HabitCadence::Weekdays => "weekdays",
        HabitCadence::Weekly => "weekly",
        HabitCadence::Monthly => "monthly",
    }
}

fn str_to_cadence(s: &str) -> Option<HabitCadence> {
    match s {
        "daily" => Some(HabitCadence::Daily),
        "weekdays" => Some(HabitCadence::Weekdays),
        "weekly" => Some(HabitCadence::Weekly),
        "monthly" => Some(HabitCadence::Monthly),
        _ => None,
    }
}

fn dt_to_str(dt: DateTime<Utc>) -> String {
    dt.to_rfc3339()
}

fn str_to_dt(s: &str) -> DateTime<Utc> {
    DateTime::parse_from_rfc3339(s)
        .expect("invalid ISO 8601 date in database")
        .with_timezone(&Utc)
}

fn opt_dt_to_str(dt: Option<DateTime<Utc>>) -> Option<String> {
    dt.map(|d| d.to_rfc3339())
}

fn opt_str_to_dt(s: Option<String>) -> Option<DateTime<Utc>> {
    s.map(|v| str_to_dt(&v))
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

pub struct Database {
    conn: Connection,
}

impl Database {
    /// Open or create a SQLite database at the given path.
    pub fn open(path: &str) -> Result<Self> {
        let conn = Connection::open(path)?;
        let db = Self { conn };
        db.init_tables()?;
        Ok(db)
    }

    /// Open an in-memory database (for tests).
    pub fn open_in_memory() -> Result<Self> {
        let conn = Connection::open_in_memory()?;
        let db = Self { conn };
        db.init_tables()?;
        Ok(db)
    }

    fn init_tables(&self) -> Result<()> {
        self.conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS entries (
                id                  TEXT PRIMARY KEY,
                transcript          TEXT NOT NULL,
                content             TEXT NOT NULL,
                category            TEXT NOT NULL,
                source_text         TEXT NOT NULL,
                summary             TEXT NOT NULL DEFAULT '',
                notes               TEXT NOT NULL DEFAULT '',
                priority            INTEGER,
                due_date_description TEXT,
                due_date            TEXT,
                cadence             TEXT,
                status              TEXT NOT NULL DEFAULT 'active',
                completed_at        TEXT,
                snooze_until        TEXT,
                audio_duration      REAL,
                source              TEXT NOT NULL DEFAULT 'text',
                created_at          TEXT NOT NULL,
                updated_at          TEXT NOT NULL
            );",
        )?;
        Ok(())
    }

    /// Insert a new entry.
    pub fn insert_entry(&self, entry: &Entry) -> Result<()> {
        self.conn.execute(
            "INSERT INTO entries (
                id, transcript, content, category, source_text,
                summary, notes, priority, due_date_description, due_date,
                cadence, status, completed_at, snooze_until,
                audio_duration, source, created_at, updated_at
            ) VALUES (
                ?1, ?2, ?3, ?4, ?5,
                ?6, ?7, ?8, ?9, ?10,
                ?11, ?12, ?13, ?14,
                ?15, ?16, ?17, ?18
            )",
            params![
                entry.id.to_string(),
                entry.transcript,
                entry.content,
                category_to_str(entry.category),
                entry.source_text,
                entry.summary,
                entry.notes,
                entry.priority,
                entry.due_date_description,
                opt_dt_to_str(entry.due_date),
                entry.cadence.map(cadence_to_str),
                status_to_str(entry.status),
                opt_dt_to_str(entry.completed_at),
                opt_dt_to_str(entry.snooze_until),
                entry.audio_duration,
                source_to_str(entry.source),
                dt_to_str(entry.created_at),
                dt_to_str(entry.updated_at),
            ],
        )?;
        Ok(())
    }

    /// Full row replacement by id.
    pub fn update_entry(&self, entry: &Entry) -> Result<()> {
        self.conn.execute(
            "UPDATE entries SET
                transcript = ?2, content = ?3, category = ?4, source_text = ?5,
                summary = ?6, notes = ?7, priority = ?8, due_date_description = ?9,
                due_date = ?10, cadence = ?11, status = ?12, completed_at = ?13,
                snooze_until = ?14, audio_duration = ?15, source = ?16,
                created_at = ?17, updated_at = ?18
            WHERE id = ?1",
            params![
                entry.id.to_string(),
                entry.transcript,
                entry.content,
                category_to_str(entry.category),
                entry.source_text,
                entry.summary,
                entry.notes,
                entry.priority,
                entry.due_date_description,
                opt_dt_to_str(entry.due_date),
                entry.cadence.map(cadence_to_str),
                status_to_str(entry.status),
                opt_dt_to_str(entry.completed_at),
                opt_dt_to_str(entry.snooze_until),
                entry.audio_duration,
                source_to_str(entry.source),
                dt_to_str(entry.created_at),
                dt_to_str(entry.updated_at),
            ],
        )?;
        Ok(())
    }

    /// Delete an entry by id. Returns whether a row was deleted.
    pub fn delete_entry(&self, id: Uuid) -> Result<bool> {
        let rows = self
            .conn
            .execute("DELETE FROM entries WHERE id = ?1", params![id.to_string()])?;
        Ok(rows > 0)
    }

    /// Get a single entry by id.
    pub fn get_entry(&self, id: Uuid) -> Result<Option<Entry>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, transcript, content, category, source_text,
                    summary, notes, priority, due_date_description, due_date,
                    cadence, status, completed_at, snooze_until,
                    audio_duration, source, created_at, updated_at
             FROM entries WHERE id = ?1",
        )?;
        let mut rows = stmt.query_map(params![id.to_string()], row_to_entry)?;
        match rows.next() {
            Some(row) => Ok(Some(row?)),
            None => Ok(None),
        }
    }

    /// All entries, ordered by created_at desc.
    pub fn list_entries(&self) -> Result<Vec<Entry>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, transcript, content, category, source_text,
                    summary, notes, priority, due_date_description, due_date,
                    cadence, status, completed_at, snooze_until,
                    audio_duration, source, created_at, updated_at
             FROM entries ORDER BY created_at DESC",
        )?;
        let rows = stmt.query_map([], row_to_entry)?;
        rows.collect()
    }

    /// Entries filtered by status, ordered by created_at desc.
    pub fn list_entries_by_status(&self, status: EntryStatus) -> Result<Vec<Entry>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, transcript, content, category, source_text,
                    summary, notes, priority, due_date_description, due_date,
                    cadence, status, completed_at, snooze_until,
                    audio_duration, source, created_at, updated_at
             FROM entries WHERE status = ?1 ORDER BY created_at DESC",
        )?;
        let rows = stmt.query_map(params![status_to_str(status)], row_to_entry)?;
        rows.collect()
    }
}

/// Map a database row to an Entry.
fn row_to_entry(row: &rusqlite::Row<'_>) -> rusqlite::Result<Entry> {
    let id_str: String = row.get(0)?;
    let cadence_str: Option<String> = row.get(10)?;

    Ok(Entry {
        id: Uuid::parse_str(&id_str).unwrap_or_else(|_| Uuid::nil()),
        transcript: row.get(1)?,
        content: row.get(2)?,
        category: str_to_category(&row.get::<_, String>(3)?),
        source_text: row.get(4)?,
        summary: row.get(5)?,
        notes: row.get(6)?,
        priority: row.get(7)?,
        due_date_description: row.get(8)?,
        due_date: opt_str_to_dt(row.get(9)?),
        cadence: cadence_str.and_then(|s| str_to_cadence(&s)),
        status: str_to_status(&row.get::<_, String>(11)?),
        completed_at: opt_str_to_dt(row.get(12)?),
        snooze_until: opt_str_to_dt(row.get(13)?),
        audio_duration: row.get(14)?,
        source: str_to_source(&row.get::<_, String>(15)?),
        created_at: str_to_dt(&row.get::<_, String>(16)?),
        updated_at: str_to_dt(&row.get::<_, String>(17)?),
    })
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::entry::{EntryCategory, EntrySource, EntryStatus, HabitCadence};
    use chrono::{Duration, Utc};

    fn make_entry(content: &str, category: EntryCategory) -> Entry {
        Entry::new(
            format!("said: {content}"),
            content.to_string(),
            category,
            content.to_string(),
            EntrySource::Text,
        )
    }

    fn make_full_entry() -> Entry {
        let now = Utc::now();
        let mut entry = Entry::new(
            "full transcript".to_string(),
            "Full content".to_string(),
            EntryCategory::Habit,
            "full source".to_string(),
            EntrySource::Voice,
        );
        entry.summary = "A habit summary".to_string();
        entry.notes = "Some notes here".to_string();
        entry.priority = Some(2);
        entry.due_date_description = Some("next monday".to_string());
        entry.due_date = Some(now + Duration::days(3));
        entry.cadence = Some(HabitCadence::Weekly);
        entry.status = EntryStatus::Active;
        entry.audio_duration = Some(12.5);
        entry
    }

    #[test]
    fn insert_and_retrieve() {
        let db = Database::open_in_memory().unwrap();
        let entry = make_entry("Buy milk", EntryCategory::Todo);
        let id = entry.id;

        db.insert_entry(&entry).unwrap();
        let loaded = db.get_entry(id).unwrap().expect("entry should exist");

        assert_eq!(loaded.id, id);
        assert_eq!(loaded.content, "Buy milk");
        assert_eq!(loaded.category, EntryCategory::Todo);
        assert_eq!(loaded.source, EntrySource::Text);
        assert_eq!(loaded.status, EntryStatus::Active);
    }

    #[test]
    fn update_entry_persists() {
        let db = Database::open_in_memory().unwrap();
        let mut entry = make_entry("Original", EntryCategory::Note);
        let id = entry.id;
        db.insert_entry(&entry).unwrap();

        entry.content = "Updated content".to_string();
        entry.category = EntryCategory::Todo;
        entry.priority = Some(1);
        entry.updated_at = Utc::now();
        db.update_entry(&entry).unwrap();

        let loaded = db.get_entry(id).unwrap().unwrap();
        assert_eq!(loaded.content, "Updated content");
        assert_eq!(loaded.category, EntryCategory::Todo);
        assert_eq!(loaded.priority, Some(1));
    }

    #[test]
    fn delete_entry_removes_row() {
        let db = Database::open_in_memory().unwrap();
        let entry = make_entry("Delete me", EntryCategory::Note);
        let id = entry.id;
        db.insert_entry(&entry).unwrap();

        let deleted = db.delete_entry(id).unwrap();
        assert!(deleted);

        let loaded = db.get_entry(id).unwrap();
        assert!(loaded.is_none());

        // Deleting again returns false
        let deleted_again = db.delete_entry(id).unwrap();
        assert!(!deleted_again);
    }

    #[test]
    fn list_entries_by_status() {
        let db = Database::open_in_memory().unwrap();

        let active = make_entry("Active one", EntryCategory::Todo);
        db.insert_entry(&active).unwrap();

        let mut completed = make_entry("Completed one", EntryCategory::Todo);
        completed.complete();
        db.insert_entry(&completed).unwrap();

        let mut archived = make_entry("Archived one", EntryCategory::Note);
        archived.archive();
        db.insert_entry(&archived).unwrap();

        let active_entries = db.list_entries_by_status(EntryStatus::Active).unwrap();
        assert_eq!(active_entries.len(), 1);
        assert_eq!(active_entries[0].content, "Active one");

        let completed_entries = db.list_entries_by_status(EntryStatus::Completed).unwrap();
        assert_eq!(completed_entries.len(), 1);
        assert_eq!(completed_entries[0].content, "Completed one");

        let all = db.list_entries().unwrap();
        assert_eq!(all.len(), 3);
    }

    #[test]
    fn round_trip_all_fields() {
        let db = Database::open_in_memory().unwrap();
        let entry = make_full_entry();
        let id = entry.id;

        db.insert_entry(&entry).unwrap();
        let loaded = db.get_entry(id).unwrap().unwrap();

        assert_eq!(loaded.id, entry.id);
        assert_eq!(loaded.transcript, entry.transcript);
        assert_eq!(loaded.content, entry.content);
        assert_eq!(loaded.category, entry.category);
        assert_eq!(loaded.source_text, entry.source_text);
        assert_eq!(loaded.summary, entry.summary);
        assert_eq!(loaded.notes, entry.notes);
        assert_eq!(loaded.priority, entry.priority);
        assert_eq!(loaded.due_date_description, entry.due_date_description);
        assert_eq!(loaded.cadence, entry.cadence);
        assert_eq!(loaded.status, entry.status);
        assert_eq!(loaded.source, entry.source);
        assert_eq!(loaded.audio_duration, entry.audio_duration);

        // DateTime round-trip: compare to_rfc3339 since sub-nanosecond precision may differ
        assert_eq!(
            loaded.created_at.to_rfc3339(),
            entry.created_at.to_rfc3339()
        );
        assert_eq!(
            loaded.updated_at.to_rfc3339(),
            entry.updated_at.to_rfc3339()
        );
        assert_eq!(
            loaded.due_date.map(|d| d.to_rfc3339()),
            entry.due_date.map(|d| d.to_rfc3339())
        );

        // Optional fields that are None on a completed entry
        assert!(loaded.completed_at.is_none());
        assert!(loaded.snooze_until.is_none());
    }

    #[test]
    fn round_trip_completed_and_snoozed_fields() {
        let db = Database::open_in_memory().unwrap();

        let mut entry = make_entry("Completed", EntryCategory::Todo);
        entry.complete();
        db.insert_entry(&entry).unwrap();

        let loaded = db.get_entry(entry.id).unwrap().unwrap();
        assert_eq!(loaded.status, EntryStatus::Completed);
        assert!(loaded.completed_at.is_some());
        assert_eq!(
            loaded.completed_at.map(|d| d.to_rfc3339()),
            entry.completed_at.map(|d| d.to_rfc3339())
        );

        let mut snoozed = make_entry("Snoozed", EntryCategory::Reminder);
        snoozed.snooze(None);
        db.insert_entry(&snoozed).unwrap();

        let loaded = db.get_entry(snoozed.id).unwrap().unwrap();
        assert_eq!(loaded.status, EntryStatus::Snoozed);
        assert!(loaded.snooze_until.is_some());
        assert_eq!(
            loaded.snooze_until.map(|d| d.to_rfc3339()),
            snoozed.snooze_until.map(|d| d.to_rfc3339())
        );
    }

    #[test]
    fn round_trip_none_optional_fields() {
        let db = Database::open_in_memory().unwrap();
        let entry = make_entry("Minimal", EntryCategory::Note);
        db.insert_entry(&entry).unwrap();

        let loaded = db.get_entry(entry.id).unwrap().unwrap();
        assert!(loaded.priority.is_none());
        assert!(loaded.due_date_description.is_none());
        assert!(loaded.due_date.is_none());
        assert!(loaded.cadence.is_none());
        assert!(loaded.completed_at.is_none());
        assert!(loaded.snooze_until.is_none());
        assert!(loaded.audio_duration.is_none());
    }

    #[test]
    fn actor_with_db_persistence() {
        use crate::action::{AppAction, CreateEntryData, EntryAction};
        use crate::update::App;

        let dir = tempfile::tempdir().unwrap();
        let db_path = dir.path().join("test.db");
        let db_str = db_path.to_str().unwrap();

        // Create an app with db, dispatch an entry, wait for processing
        {
            let app = App::with_db(db_str).unwrap();
            app.dispatch(AppAction::Entry(EntryAction::Create(CreateEntryData {
                transcript: "test transcript".to_string(),
                content: "Persistent entry".to_string(),
                category: EntryCategory::Idea,
                source_text: "persistent".to_string(),
                summary: "persist test".to_string(),
                priority: Some(3),
                due_date_description: None,
                cadence: None,
                source: EntrySource::Text,
                audio_duration: None,
            })));
            let _ = app.recv_update().unwrap();

            // Verify it's in state
            let state = app.state();
            let guard = state.read().unwrap();
            assert_eq!(guard.entries.len(), 1);
            assert_eq!(guard.entries[0].content, "Persistent entry");
        }
        // App dropped, actor thread stops

        // Create a new app with the same db — entry should be loaded from disk
        {
            let app = App::with_db(db_str).unwrap();
            let state = app.state();
            let guard = state.read().unwrap();
            assert_eq!(guard.entries.len(), 1);
            assert_eq!(guard.entries[0].content, "Persistent entry");
            assert_eq!(guard.entries[0].category, EntryCategory::Idea);
            assert_eq!(guard.entries[0].priority, Some(3));
        }
    }
}
