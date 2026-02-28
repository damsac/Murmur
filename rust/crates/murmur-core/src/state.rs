use crate::entry::Entry;

/// Single source of truth for the entire application.
/// Monotonic `rev` field enables efficient change detection across FFI.
#[derive(Debug)]
pub struct AppState {
    /// All entries in the system.
    pub entries: Vec<Entry>,

    /// Monotonically increasing revision counter.
    /// Incremented on every state mutation for change detection.
    pub rev: u64,

    /// User-visible toast message (errors become state, not panics).
    pub toast: Option<String>,
}

impl AppState {
    pub fn new() -> Self {
        Self {
            entries: Vec::new(),
            rev: 0,
            toast: None,
        }
    }

    /// Bump the revision counter. Call after every state mutation.
    pub fn bump_rev(&mut self) {
        self.rev += 1;
    }
}

impl Default for AppState {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn new_state_is_empty() {
        let state = AppState::new();
        assert!(state.entries.is_empty());
        assert_eq!(state.rev, 0);
        assert!(state.toast.is_none());
    }

    #[test]
    fn bump_rev_increments() {
        let mut state = AppState::new();
        state.bump_rev();
        assert_eq!(state.rev, 1);
        state.bump_rev();
        assert_eq!(state.rev, 2);
    }
}
