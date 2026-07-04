//! Per-`doc_kind` document-number minting (Plan 07 D5). Core mints the
//! integer; the Swift bridge renders the prefix (`EST-`, `MO-`, `IR-`).
//! Local bookkeeping — same posture as `reflection_state` (no
//! tombstone/sync fields; a counter is device-local in v1).

use crate::error::CoreError;
use crate::store::Store;

impl Store {
    /// Returns the next document number for `doc_kind`, starting at 1 and
    /// incrementing monotonically per kind (independent sequences).
    /// Transactional read-or-insert-then-increment.
    pub fn mint_document_number(&self, doc_kind: &str) -> Result<u64, CoreError> {
        let tx = self.conn.unchecked_transaction()?;
        let current: Option<i64> = tx
            .query_row(
                "SELECT next FROM document_sequences WHERE doc_kind = ?1",
                [doc_kind],
                |r| r.get(0),
            )
            .map(Some)
            .or_else(|e| match e {
                rusqlite::Error::QueryReturnedNoRows => Ok(None),
                other => Err(other),
            })?;
        let minted = current.unwrap_or(0) + 1;
        tx.execute(
            "INSERT INTO document_sequences (doc_kind, next, device_id) VALUES (?1, ?2, ?3)
             ON CONFLICT(doc_kind) DO UPDATE SET next = ?2",
            rusqlite::params![doc_kind, minted, self.device_id],
        )?;
        tx.commit()?;
        Ok(minted as u64)
    }
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use crate::store::Store;

    fn store() -> Store {
        Store::open_in_memory("device-a").unwrap().with_clock(Arc::new(|| 1000))
    }

    #[test]
    fn mint_is_monotonic_per_kind() {
        let s = store();
        assert_eq!(s.mint_document_number("estimate").unwrap(), 1);
        assert_eq!(s.mint_document_number("estimate").unwrap(), 2);
        assert_eq!(s.mint_document_number("report").unwrap(), 1); // independent sequence
        assert_eq!(s.mint_document_number("estimate").unwrap(), 3);
    }
}
