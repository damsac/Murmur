use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::entry::{EntryCategory, EntrySource, HabitCadence};

// ---------------------------------------------------------------------------
// AppAction — every user intent and lifecycle event
// ---------------------------------------------------------------------------

/// Top-level action enum for the TEA loop.
#[derive(Debug, Clone)]
pub enum AppAction {
    /// Entry CRUD actions.
    Entry(EntryAction),

    /// Agent/LLM pipeline actions.
    Agent(AgentPipelineAction),

    /// Dismiss the current toast.
    DismissToast,
}

/// Actions on individual entries.
#[derive(Debug, Clone)]
pub enum EntryAction {
    Create(CreateEntryData),
    Update { id: Uuid, fields: UpdateFields },
    Complete { id: Uuid },
    Archive { id: Uuid },
    Unarchive { id: Uuid },
    Snooze { id: Uuid, until: Option<DateTime<Utc>> },
    Delete { id: Uuid },
}

/// Data needed to create a new entry.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateEntryData {
    pub transcript: String,
    pub content: String,
    pub category: EntryCategory,
    pub source_text: String,
    pub summary: String,
    pub priority: Option<i32>,
    pub due_date_description: Option<String>,
    pub cadence: Option<HabitCadence>,
    pub source: EntrySource,
    pub audio_duration: Option<f64>,
}

/// Fields that can be updated on an existing entry (all optional).
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct UpdateFields {
    pub content: Option<String>,
    pub summary: Option<String>,
    pub category: Option<EntryCategory>,
    pub priority: Option<i32>,
    pub due_date_description: Option<String>,
    pub cadence: Option<HabitCadence>,
}

/// Agent pipeline lifecycle actions.
#[derive(Debug, Clone)]
pub enum AgentPipelineAction {
    /// User submitted text for the agent to process.
    ProcessTranscript {
        transcript: String,
        source: EntrySource,
    },
    /// Agent produced actions to apply to state.
    ApplyAgentActions(Vec<AgentResultAction>),
    /// Agent encountered an error.
    AgentError(String),
}

/// An action produced by the LLM agent (mirrors Swift AgentAction).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AgentResultAction {
    Create(AgentCreateAction),
    Update(AgentUpdateAction),
    Complete(AgentCompleteAction),
    Archive(AgentArchiveAction),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentCreateAction {
    pub content: String,
    pub category: EntryCategory,
    pub source_text: String,
    pub summary: String,
    pub priority: Option<i32>,
    pub due_date_description: Option<String>,
    pub cadence: Option<HabitCadence>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentUpdateAction {
    pub id: String,
    pub fields: AgentUpdateFields,
    pub reason: String,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct AgentUpdateFields {
    pub content: Option<String>,
    pub summary: Option<String>,
    pub category: Option<EntryCategory>,
    pub priority: Option<i32>,
    pub due_date_description: Option<String>,
    pub cadence: Option<HabitCadence>,
    pub status: Option<String>,
    pub snooze_until: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentCompleteAction {
    pub id: String,
    pub reason: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentArchiveAction {
    pub id: String,
    pub reason: String,
}
