//! `NotesPayload` (Plan 13 D2): the exact `finish()` record after the Stage 2
//! flip. A walk's finish output is items + summary — the document build moves
//! to the on-demand, engine-keyed `build_document(kind)` (Stage 1, additive).
//!
//! Plan 14 D2-14/D5-14: `NotesPayload` grows additively with a `notes: Vec<NotesEntry>`
//! field — the comprehensive, bucketed coordination detail behind the terse
//! `items` board. `bucket` is a string in the core-side artifact (tolerant of
//! drift) but an exhaustive enum here at the FFI boundary — any entry whose
//! bucket string doesn't map to a known variant is DROPPED (R6: never
//! fabricate/coerce a bucket), so Swift's exhaustive `switch` is safe.

use murmur_core::CapturedItem;

use crate::convert;
use crate::events::BoardItem;

/// The three entry buckets (D2-14). The top-level narrative summary is NOT
/// a bucket — it's `NotesPayload.summary`.
#[derive(uniffi::Enum, Clone, Copy, Debug, PartialEq, Eq)]
pub enum NotesBucket {
    ScopeOfWork,
    Constraints,
    ConditionsAndIssues,
}

impl NotesBucket {
    /// Maps the core-side wire string -> enum. Returns `None` for anything
    /// outside the three known buckets — the caller drops that row (R6).
    pub(crate) fn from_wire(s: &str) -> Option<Self> {
        match s {
            "scope_of_work" => Some(NotesBucket::ScopeOfWork),
            "constraints" => Some(NotesBucket::Constraints),
            "conditions_and_issues" => Some(NotesBucket::ConditionsAndIssues),
            _ => None,
        }
    }
}

#[derive(uniffi::Record, Clone, Debug, PartialEq)]
pub struct NotesEntry {
    pub bucket: NotesBucket,
    pub label: String,
    pub detail: String,
}

#[derive(uniffi::Record, Clone, Debug, PartialEq)]
pub struct NotesPayload {
    pub session_id: String,
    /// The template's DEFAULT kind (`doc_kind_for_template`) — advisory only,
    /// for button curation. Swift's button wiring keys off the client-known
    /// template (D2), never off this field.
    pub doc_kind: String,
    /// `session.summary`; `"(empty session)"` for a silent walk.
    pub summary: String,
    /// The authoritative+manual board post-swap, with batched photo_count
    /// (reuses `BoardItem` — no new item record).
    pub items: Vec<BoardItem>,
    /// Plan 14: the comprehensive, bucketed coordination entries captured at
    /// summary time (D1-14). Empty for pre-14 sessions, an empty/offline
    /// finish, or a `write_notes` response with no notes (D6-14 table).
    pub notes: Vec<NotesEntry>,
    /// `true` when `finish()` degraded offline (D9) — the session did NOT
    /// reach `Processed`; the client disables build-document buttons.
    pub queued: bool,
}

/// D3: builds a `NotesPayload` from a session's items — shared by the happy
/// path and every degrade branch (empty transcript, offline, double-finish).
pub(crate) fn notes_payload(
    session_id: &str,
    doc_kind: &str,
    summary: &str,
    items: &[CapturedItem],
    photo_counts: &std::collections::HashMap<String, u32>,
    notes: &[murmur_core::NotesEntry],
    queued: bool,
) -> NotesPayload {
    NotesPayload {
        session_id: session_id.to_string(),
        doc_kind: doc_kind.to_string(),
        summary: summary.to_string(),
        items: items.iter().map(|item| convert::board_item(item, photo_counts)).collect(),
        notes: convert::notes_entries(notes),
        queued,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bucket_from_wire_maps_the_three_known_strings() {
        assert_eq!(NotesBucket::from_wire("scope_of_work"), Some(NotesBucket::ScopeOfWork));
        assert_eq!(NotesBucket::from_wire("constraints"), Some(NotesBucket::Constraints));
        assert_eq!(
            NotesBucket::from_wire("conditions_and_issues"),
            Some(NotesBucket::ConditionsAndIssues)
        );
        assert_eq!(NotesBucket::from_wire("logistics"), None, "unknown bucket -> None, dropped");
    }
}
