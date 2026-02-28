use std::sync::{Arc, RwLock};
use std::thread;

use uuid::Uuid;

use crate::action::{
    AgentPipelineAction, AgentResultAction, AppAction, CreateEntryData, EntryAction, UpdateFields,
};
use crate::db::Database;
use crate::entry::{Entry, EntrySource};
use crate::state::AppState;

// ---------------------------------------------------------------------------
// handle_message — pure TEA update function
// ---------------------------------------------------------------------------

/// Process an action against the current state. Pure function (no I/O).
/// Always call state.bump_rev() after mutations.
pub fn handle_message(state: &mut AppState, action: AppAction) {
    match action {
        AppAction::Entry(entry_action) => handle_entry_action(state, entry_action),
        AppAction::Agent(agent_action) => handle_agent_action(state, agent_action),
        AppAction::DismissToast => {
            state.toast = None;
            state.bump_rev();
        }
    }
}

fn handle_entry_action(state: &mut AppState, action: EntryAction) {
    match action {
        EntryAction::Create(data) => {
            let mut entry = Entry::new(
                data.transcript,
                data.content,
                data.category,
                data.source_text,
                data.source,
            );
            entry.summary = data.summary;
            entry.priority = data.priority;
            entry.due_date_description = data.due_date_description;
            entry.cadence = data.cadence;
            entry.audio_duration = data.audio_duration;
            state.entries.push(entry);
            state.bump_rev();
        }
        EntryAction::Update { id, fields } => {
            if let Some(entry) = state.entries.iter_mut().find(|e| e.id == id) {
                if let Some(content) = fields.content {
                    entry.content = content;
                }
                if let Some(summary) = fields.summary {
                    entry.summary = summary;
                }
                if let Some(category) = fields.category {
                    entry.category = category;
                }
                if let Some(priority) = fields.priority {
                    entry.priority = Some(priority);
                }
                if let Some(due) = fields.due_date_description {
                    entry.due_date_description = Some(due);
                }
                if let Some(cadence) = fields.cadence {
                    entry.cadence = Some(cadence);
                }
                entry.updated_at = chrono::Utc::now();
                state.bump_rev();
            }
        }
        EntryAction::Complete { id } => {
            if let Some(entry) = state.entries.iter_mut().find(|e| e.id == id) {
                entry.complete();
                state.bump_rev();
            }
        }
        EntryAction::Archive { id } => {
            if let Some(entry) = state.entries.iter_mut().find(|e| e.id == id) {
                entry.archive();
                state.bump_rev();
            }
        }
        EntryAction::Unarchive { id } => {
            if let Some(entry) = state.entries.iter_mut().find(|e| e.id == id) {
                entry.unarchive();
                state.bump_rev();
            }
        }
        EntryAction::Snooze { id, until } => {
            if let Some(entry) = state.entries.iter_mut().find(|e| e.id == id) {
                entry.snooze(until);
                state.bump_rev();
            }
        }
        EntryAction::Delete { id } => {
            let before = state.entries.len();
            state.entries.retain(|e| e.id != id);
            if state.entries.len() != before {
                state.bump_rev();
            }
        }
    }
}

fn handle_agent_action(state: &mut AppState, action: AgentPipelineAction) {
    match action {
        AgentPipelineAction::ProcessTranscript { transcript, source } => {
            state.current_transcript = Some(transcript);
            state.current_source = source;
            state.processing = true;
            state.bump_rev();
        }
        AgentPipelineAction::ApplyAgentActions(actions) => {
            let transcript = state
                .current_transcript
                .clone()
                .unwrap_or_default();
            let source = state.current_source;

            for agent_action in actions {
                let entry_action = agent_result_to_entry_action(agent_action, &transcript, source);
                handle_entry_action(state, entry_action);
            }

            state.processing = false;
            state.current_transcript = None;
            // bump_rev already called by each handle_entry_action, but bump once more
            // to reflect the processing flag change
            state.bump_rev();
        }
        AgentPipelineAction::AgentError(msg) => {
            state.toast = Some(msg);
            state.processing = false;
            state.bump_rev();
        }
    }
}

/// Convert an agent result action into an entry action.
fn agent_result_to_entry_action(
    action: AgentResultAction,
    transcript: &str,
    source: EntrySource,
) -> EntryAction {
    match action {
        AgentResultAction::Create(create) => EntryAction::Create(CreateEntryData {
            transcript: transcript.to_string(),
            content: create.content,
            category: create.category,
            source_text: create.source_text,
            summary: create.summary,
            priority: create.priority,
            due_date_description: create.due_date_description,
            cadence: create.cadence,
            source,
            audio_duration: None,
        }),
        AgentResultAction::Update(update) => {
            let id = Uuid::parse_str(&update.id).unwrap_or_else(|_| Uuid::nil());
            EntryAction::Update {
                id,
                fields: UpdateFields {
                    content: update.fields.content,
                    summary: update.fields.summary,
                    category: update.fields.category,
                    priority: update.fields.priority,
                    due_date_description: update.fields.due_date_description,
                    cadence: update.fields.cadence,
                },
            }
        }
        AgentResultAction::Complete(complete) => {
            let id = Uuid::parse_str(&complete.id).unwrap_or_else(|_| Uuid::nil());
            EntryAction::Complete { id }
        }
        AgentResultAction::Archive(archive) => {
            let id = Uuid::parse_str(&archive.id).unwrap_or_else(|_| Uuid::nil());
            EntryAction::Archive { id }
        }
    }
}

// ---------------------------------------------------------------------------
// App — actor thread owning AppState, communicates via flume channels
// ---------------------------------------------------------------------------

/// Outbound update sent from the actor to listeners.
#[derive(Debug, Clone)]
pub enum AppUpdate {
    /// Full state snapshot after every mutation.
    StateChanged(u64),
}

/// The main application handle. Owns channels to the actor thread.
pub struct App {
    /// Send actions to the actor thread (fire-and-forget).
    tx: flume::Sender<AppAction>,

    /// Shared state readable from any thread.
    state: Arc<RwLock<AppState>>,

    /// Receive update notifications from the actor.
    update_rx: flume::Receiver<AppUpdate>,
}

impl Default for App {
    fn default() -> Self {
        Self::new()
    }
}

impl App {
    /// Create a new App without persistence, spawning the actor thread.
    pub fn new() -> Self {
        let (action_tx, action_rx) = flume::unbounded::<AppAction>();
        let (update_tx, update_rx) = flume::unbounded::<AppUpdate>();
        let state = Arc::new(RwLock::new(AppState::new()));
        let actor_state = Arc::clone(&state);

        thread::spawn(move || {
            actor_loop_with_entries(action_rx, update_tx, actor_state, None, Vec::new());
        });

        Self {
            tx: action_tx,
            state,
            update_rx,
        }
    }

    /// Create a new App with SQLite persistence at the given path.
    /// Loads existing entries from the database on startup.
    pub fn with_db(path: &str) -> rusqlite::Result<Self> {
        let db = Database::open(path)?;
        let initial_entries = db.list_entries()?;

        let (action_tx, action_rx) = flume::unbounded::<AppAction>();
        let (update_tx, update_rx) = flume::unbounded::<AppUpdate>();

        // Shared state gets a copy of the loaded entries for immediate reads.
        let mut shared_init = AppState::new();
        shared_init.entries = initial_entries.clone();
        let state = Arc::new(RwLock::new(shared_init));
        let actor_state = Arc::clone(&state);

        thread::spawn(move || {
            actor_loop_with_entries(action_rx, update_tx, actor_state, Some(db), initial_entries);
        });

        Ok(Self {
            tx: action_tx,
            state,
            update_rx,
        })
    }

    /// Dispatch an action to the actor (non-blocking, fire-and-forget).
    pub fn dispatch(&self, action: AppAction) {
        // Ignore send errors (actor thread has shut down).
        let _ = self.tx.send(action);
    }

    /// Read the current state snapshot.
    pub fn state(&self) -> Arc<RwLock<AppState>> {
        Arc::clone(&self.state)
    }

    /// Receive the next update notification (blocks until available).
    pub fn recv_update(&self) -> Result<AppUpdate, flume::RecvError> {
        self.update_rx.recv()
    }

    /// Try to receive an update notification without blocking.
    pub fn try_recv_update(&self) -> Result<AppUpdate, flume::TryRecvError> {
        self.update_rx.try_recv()
    }
}

/// The actor event loop. Runs on a dedicated std::thread.
/// Accepts an optional Database for persistence and initial entries to seed state.
fn actor_loop_with_entries(
    rx: flume::Receiver<AppAction>,
    update_tx: flume::Sender<AppUpdate>,
    shared_state: Arc<RwLock<AppState>>,
    db: Option<Database>,
    initial_entries: Vec<Entry>,
) {
    let mut state = AppState::new();
    state.entries = initial_entries;

    while let Ok(action) = rx.recv() {
        // Track which action we're processing for db persistence.
        let db_op = classify_db_op(&action);

        handle_message(&mut state, action);

        // Persist to database if available.
        if let Some(ref db) = db {
            persist_db_op(db, &state, db_op);
        }

        // Publish state to the shared RwLock for synchronous reads.
        if let Ok(mut shared) = shared_state.write() {
            shared.entries = state.entries.clone();
            shared.rev = state.rev;
            shared.toast = state.toast.clone();
            shared.current_transcript = state.current_transcript.clone();
            shared.current_source = state.current_source;
            shared.processing = state.processing;
        }

        // Notify listeners.
        let _ = update_tx.send(AppUpdate::StateChanged(state.rev));
    }
}

/// What kind of db operation is needed after handle_message.
enum DbOp {
    /// A new entry was just created (will be the last in state.entries).
    Insert,
    /// An entry was updated/completed/archived/unarchived/snoozed.
    Update(Uuid),
    /// An entry was deleted.
    Delete(Uuid),
    /// Agent applied multiple actions — persist all entries that changed.
    AgentBatch,
    /// No db operation needed.
    None,
}

fn classify_db_op(action: &AppAction) -> DbOp {
    match action {
        AppAction::Entry(ea) => match ea {
            EntryAction::Create(_) => DbOp::Insert,
            EntryAction::Update { id, .. }
            | EntryAction::Complete { id }
            | EntryAction::Archive { id }
            | EntryAction::Unarchive { id }
            | EntryAction::Snooze { id, .. } => DbOp::Update(*id),
            EntryAction::Delete { id } => DbOp::Delete(*id),
        },
        AppAction::Agent(AgentPipelineAction::ApplyAgentActions(_)) => DbOp::AgentBatch,
        _ => DbOp::None,
    }
}

fn persist_db_op(db: &Database, state: &AppState, op: DbOp) {
    match op {
        DbOp::Insert => {
            // The newly created entry is the last one in the vec.
            if let Some(entry) = state.entries.last() {
                if let Err(e) = db.insert_entry(entry) {
                    eprintln!("db insert error: {e}");
                }
            }
        }
        DbOp::Update(id) => {
            if let Some(entry) = state.entries.iter().find(|e| e.id == id) {
                if let Err(e) = db.update_entry(entry) {
                    eprintln!("db update error: {e}");
                }
            }
        }
        DbOp::Delete(id) => {
            if let Err(e) = db.delete_entry(id) {
                eprintln!("db delete error: {e}");
            }
        }
        DbOp::AgentBatch => {
            // Agent actions can create and modify entries. Simplest approach:
            // upsert all entries in state. For now, just insert-or-replace all.
            for entry in &state.entries {
                // Try insert first; if it fails (duplicate), update.
                if db.insert_entry(entry).is_err() {
                    if let Err(e) = db.update_entry(entry) {
                        eprintln!("db agent batch error: {e}");
                    }
                }
            }
        }
        DbOp::None => {}
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::action::*;
    use crate::entry::*;

    fn make_create_data(content: &str, category: EntryCategory) -> CreateEntryData {
        CreateEntryData {
            transcript: format!("said: {content}"),
            content: content.to_string(),
            category,
            source_text: content.to_string(),
            summary: format!("{content} summary"),
            priority: None,
            due_date_description: None,
            cadence: None,
            source: EntrySource::Text,
            audio_duration: None,
        }
    }

    #[test]
    fn handle_message_creates_entry() {
        let mut state = AppState::new();
        let data = make_create_data("Buy milk", EntryCategory::Todo);

        handle_message(&mut state, AppAction::Entry(EntryAction::Create(data)));

        assert_eq!(state.entries.len(), 1);
        assert_eq!(state.entries[0].content, "Buy milk");
        assert_eq!(state.entries[0].category, EntryCategory::Todo);
        assert_eq!(state.entries[0].summary, "Buy milk summary");
        assert_eq!(state.rev, 1);
    }

    #[test]
    fn handle_message_completes_entry() {
        let mut state = AppState::new();
        let data = make_create_data("Do laundry", EntryCategory::Todo);
        handle_message(&mut state, AppAction::Entry(EntryAction::Create(data)));
        let id = state.entries[0].id;

        handle_message(
            &mut state,
            AppAction::Entry(EntryAction::Complete { id }),
        );

        assert_eq!(state.entries[0].status, EntryStatus::Completed);
        assert!(state.entries[0].completed_at.is_some());
        assert_eq!(state.rev, 2);
    }

    #[test]
    fn handle_message_deletes_entry() {
        let mut state = AppState::new();
        let data = make_create_data("Throwaway", EntryCategory::Note);
        handle_message(&mut state, AppAction::Entry(EntryAction::Create(data)));
        assert_eq!(state.entries.len(), 1);
        let id = state.entries[0].id;

        handle_message(
            &mut state,
            AppAction::Entry(EntryAction::Delete { id }),
        );

        assert!(state.entries.is_empty());
        assert_eq!(state.rev, 2);
    }

    #[test]
    fn handle_message_updates_entry_fields() {
        let mut state = AppState::new();
        let data = make_create_data("Original", EntryCategory::Note);
        handle_message(&mut state, AppAction::Entry(EntryAction::Create(data)));
        let id = state.entries[0].id;

        handle_message(
            &mut state,
            AppAction::Entry(EntryAction::Update {
                id,
                fields: UpdateFields {
                    content: Some("Updated content".to_string()),
                    category: Some(EntryCategory::Todo),
                    ..Default::default()
                },
            }),
        );

        assert_eq!(state.entries[0].content, "Updated content");
        assert_eq!(state.entries[0].category, EntryCategory::Todo);
        assert_eq!(state.rev, 2);
    }

    #[test]
    fn handle_message_applies_agent_actions() {
        let mut state = AppState::new();

        // First create an entry to complete
        let data = make_create_data("Existing task", EntryCategory::Todo);
        handle_message(&mut state, AppAction::Entry(EntryAction::Create(data)));
        let existing_id = state.entries[0].id;

        // Set up transcript context
        state.current_transcript = Some("create a note and complete the task".to_string());
        state.current_source = EntrySource::Text;

        // Apply agent actions: create a new entry + complete existing
        let agent_actions = vec![
            AgentResultAction::Create(AgentCreateAction {
                content: "New agent note".to_string(),
                category: EntryCategory::Note,
                source_text: "create a note".to_string(),
                summary: "Agent note".to_string(),
                priority: None,
                due_date_description: None,
                cadence: None,
            }),
            AgentResultAction::Complete(AgentCompleteAction {
                id: existing_id.to_string(),
                reason: "User said to complete it".to_string(),
            }),
        ];

        handle_message(
            &mut state,
            AppAction::Agent(AgentPipelineAction::ApplyAgentActions(agent_actions)),
        );

        assert_eq!(state.entries.len(), 2);
        assert_eq!(state.entries[1].content, "New agent note");
        assert_eq!(state.entries[1].category, EntryCategory::Note);
        assert_eq!(state.entries[0].status, EntryStatus::Completed);
        assert!(!state.processing);
        assert!(state.current_transcript.is_none());
    }

    #[test]
    fn handle_message_agent_error_sets_toast() {
        let mut state = AppState::new();
        state.processing = true;

        handle_message(
            &mut state,
            AppAction::Agent(AgentPipelineAction::AgentError(
                "LLM timeout".to_string(),
            )),
        );

        assert_eq!(state.toast.as_deref(), Some("LLM timeout"));
        assert!(!state.processing);
    }

    #[test]
    fn handle_message_process_transcript_sets_flags() {
        let mut state = AppState::new();

        handle_message(
            &mut state,
            AppAction::Agent(AgentPipelineAction::ProcessTranscript {
                transcript: "buy eggs and milk".to_string(),
                source: EntrySource::Voice,
            }),
        );

        assert!(state.processing);
        assert_eq!(
            state.current_transcript.as_deref(),
            Some("buy eggs and milk")
        );
        assert_eq!(state.current_source, EntrySource::Voice);
    }

    #[test]
    fn handle_message_dismiss_toast() {
        let mut state = AppState::new();
        state.toast = Some("Error!".to_string());

        handle_message(&mut state, AppAction::DismissToast);

        assert!(state.toast.is_none());
    }

    #[test]
    fn handle_message_archive_and_unarchive() {
        let mut state = AppState::new();
        let data = make_create_data("Archive me", EntryCategory::Note);
        handle_message(&mut state, AppAction::Entry(EntryAction::Create(data)));
        let id = state.entries[0].id;

        handle_message(
            &mut state,
            AppAction::Entry(EntryAction::Archive { id }),
        );
        assert_eq!(state.entries[0].status, EntryStatus::Archived);

        handle_message(
            &mut state,
            AppAction::Entry(EntryAction::Unarchive { id }),
        );
        assert_eq!(state.entries[0].status, EntryStatus::Active);
    }

    #[test]
    fn handle_message_snooze() {
        let mut state = AppState::new();
        let data = make_create_data("Snooze me", EntryCategory::Reminder);
        handle_message(&mut state, AppAction::Entry(EntryAction::Create(data)));
        let id = state.entries[0].id;

        handle_message(
            &mut state,
            AppAction::Entry(EntryAction::Snooze { id, until: None }),
        );

        assert_eq!(state.entries[0].status, EntryStatus::Snoozed);
        assert!(state.entries[0].snooze_until.is_some());
    }

    #[test]
    fn actor_dispatch_state_roundtrip() {
        let app = App::new();

        // Dispatch a create action
        app.dispatch(AppAction::Entry(EntryAction::Create(make_create_data(
            "Actor test",
            EntryCategory::Idea,
        ))));

        // Wait for the actor to process it
        let update = app.recv_update().expect("should receive update");
        match update {
            AppUpdate::StateChanged(rev) => assert!(rev > 0),
        }

        // Read state back
        let state = app.state();
        let guard = state.read().unwrap();
        assert_eq!(guard.entries.len(), 1);
        assert_eq!(guard.entries[0].content, "Actor test");
        assert_eq!(guard.entries[0].category, EntryCategory::Idea);
    }

    #[test]
    fn actor_multiple_dispatches() {
        let app = App::new();

        app.dispatch(AppAction::Entry(EntryAction::Create(make_create_data(
            "First",
            EntryCategory::Todo,
        ))));
        app.dispatch(AppAction::Entry(EntryAction::Create(make_create_data(
            "Second",
            EntryCategory::Note,
        ))));

        // Wait for both updates
        let _ = app.recv_update().unwrap();
        let _ = app.recv_update().unwrap();

        let state = app.state();
        let guard = state.read().unwrap();
        assert_eq!(guard.entries.len(), 2);
        assert_eq!(guard.rev, 2);
    }

    #[test]
    fn delete_nonexistent_entry_is_noop() {
        let mut state = AppState::new();
        let fake_id = Uuid::new_v4();
        let rev_before = state.rev;

        handle_message(
            &mut state,
            AppAction::Entry(EntryAction::Delete { id: fake_id }),
        );

        assert_eq!(state.rev, rev_before);
    }
}
