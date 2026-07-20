//! `document_schemas` storage (Plan 19): document structure as data. Seeded
//! built-ins + CRUD + resolution, mirroring `store/items.rs`'s sync-ready row
//! discipline (created_at/updated_at/device_id, tombstones, guarded reads).
//!
//! Seeding runs on EVERY `Store::open` (from `from_connection`, after
//! migrate) — the resurrection guard is LIVE on every launch: a new built-in
//! added to `domain::builtin_schemas()` seeds naturally on the next open, and
//! a deleted (tombstoned) built-in stays deleted forever (WE-A). The v7
//! migration creates the TABLE only.

use rusqlite::{Connection, Row};
use serde::{Deserialize, Serialize};

use crate::domain::{builtin_schemas, DocumentSchema, SchemaSection};
use crate::error::CoreError;
use crate::store::Store;

const SCHEMA_COLS: &str = "id, kind, label, number_prefix, trade_key, sections, schema_version, \
                           created_at, updated_at, device_id";

/// The persisted JSON shape of the `sections` column (Plan 19 §3): the
/// envelope carries the total shape alongside the ordered sections so the
/// flexible structural part stays ONE column (the `artifacts.body` precedent).
#[derive(Serialize, Deserialize)]
struct SectionsEnvelope {
    total_kind: String,
    total_label_key: String,
    sections: Vec<SchemaSection>,
}

fn envelope_json(schema: &DocumentSchema) -> Result<String, CoreError> {
    Ok(serde_json::to_string(&SectionsEnvelope {
        total_kind: schema.total_kind.clone(),
        total_label_key: schema.total_label_key.clone(),
        sections: schema.sections.clone(),
    })?)
}

fn schema_from_row(row: &Row) -> Result<DocumentSchema, CoreError> {
    let envelope_raw: String = row.get("sections").map_err(CoreError::Sqlite)?;
    let envelope: SectionsEnvelope = serde_json::from_str(&envelope_raw)
        .map_err(|e| CoreError::Corrupt(format!("bad document_schemas.sections JSON: {e}")))?;
    Ok(DocumentSchema {
        id: row.get("id").map_err(CoreError::Sqlite)?,
        kind: row.get("kind").map_err(CoreError::Sqlite)?,
        label: row.get("label").map_err(CoreError::Sqlite)?,
        number_prefix: row.get("number_prefix").map_err(CoreError::Sqlite)?,
        trade_key: row.get("trade_key").map_err(CoreError::Sqlite)?,
        total_kind: envelope.total_kind,
        total_label_key: envelope.total_label_key,
        sections: envelope.sections,
        schema_version: row.get::<_, i64>("schema_version").map_err(CoreError::Sqlite)? as u32,
        created_at: row.get::<_, i64>("created_at").map_err(CoreError::Sqlite)? as u64,
        updated_at: row.get::<_, i64>("updated_at").map_err(CoreError::Sqlite)? as u64,
        device_id: row.get("device_id").map_err(CoreError::Sqlite)?,
    })
}

/// Seeds the built-in schemas (Plan 19 Stage 1). Runs on EVERY store open,
/// iterating the ONE source `builtin_schemas()`; each row is a parameterized,
/// tombstone-respecting insert — the `WHERE NOT EXISTS` checks EVERY row
/// including tombstoned ones, so a soft-deleted built-in blocks its own
/// re-seed forever (the resurrection guard, WE-A). Seeded rows carry the
/// sentinel `device_id` ("builtin") and fixed timestamps (0) so they are
/// byte-identical on every device (the stable sync merge key).
pub(crate) fn seed_builtin_schemas(conn: &Connection) -> Result<(), CoreError> {
    for schema in builtin_schemas() {
        let sections = envelope_json(&schema)?;
        conn.execute(
            "INSERT INTO document_schemas
                 (id, kind, label, number_prefix, trade_key, sections, schema_version,
                  created_at, updated_at, device_id, deleted_at)
             SELECT ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, NULL
             WHERE NOT EXISTS (SELECT 1 FROM document_schemas WHERE id = ?1)",
            rusqlite::params![
                schema.id,
                schema.kind,
                schema.label,
                schema.number_prefix,
                schema.trade_key,
                sections,
                schema.schema_version as i64,
                schema.created_at as i64,
                schema.updated_at as i64,
                schema.device_id,
            ],
        )?;
    }
    Ok(())
}

impl Store {
    /// One live schema by id; `NotFound` for missing or tombstoned rows
    /// (the `get_item` discipline).
    pub fn get_document_schema(&self, id: &str) -> Result<DocumentSchema, CoreError> {
        let mut stmt = self.conn.prepare(&format!(
            "SELECT {SCHEMA_COLS} FROM document_schemas WHERE id = ?1 AND deleted_at IS NULL"
        ))?;
        let mut rows = stmt.query([id])?;
        match rows.next()? {
            Some(row) => schema_from_row(row),
            None => Err(CoreError::NotFound { entity: "document_schema", id: id.to_string() }),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::BUILTIN_SCHEMA_ID_ESTIMATE;
    use crate::pipeline::{is_pricing_kind, total_shape};
    use crate::store::Store;

    #[test]
    fn fresh_store_is_at_schema_v7() {
        let s = Store::open_in_memory("device-a").unwrap();
        let v: i64 =
            s.conn.pragma_query_value(None, "user_version", |r| r.get(0)).unwrap();
        assert_eq!(v, 7, "v7 added document_schemas (Plan 19)");
    }

    #[test]
    fn v7_seeds_exactly_the_seven_builtins() {
        let s = Store::open_in_memory("device-a").unwrap();
        let rows: Vec<(String, String, Option<String>, String)> = {
            let mut stmt = s
                .conn
                .prepare(
                    "SELECT id, kind, trade_key, number_prefix FROM document_schemas ORDER BY id",
                )
                .unwrap();
            let got = stmt
                .query_map([], |r| {
                    Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?))
                })
                .unwrap()
                .map(Result::unwrap)
                .collect();
            got
        };
        let expected: Vec<(String, String, Option<String>, String)> = builtin_schemas()
            .into_iter()
            .map(|b| (b.id, b.kind, b.trade_key, b.number_prefix))
            .collect();
        assert_eq!(rows, expected, "exactly the seven built-ins, ids/kinds/trades/prefixes");
        assert_eq!(rows.len(), 7);
    }

    /// The guard that the parameterized INSERT and the `Vec` source never
    /// drift (an inline-SQL duplicate would have risked exactly that).
    #[test]
    fn seeded_rows_deep_equal_builtin_schemas() {
        let s = Store::open_in_memory("device-a").unwrap();
        for builtin in builtin_schemas() {
            let read = s.get_document_schema(&builtin.id).unwrap();
            assert_eq!(read, builtin, "seeded row deep-equals its builtin_schemas() source");
        }
    }

    /// The parity net between the old hardcoded functions and the seeds.
    #[test]
    fn builtin_schemas_reproduce_todays_pricing_and_total_shape() {
        for b in builtin_schemas() {
            let line_items: Vec<_> =
                b.sections.iter().filter(|s| s.kind == "line_items").collect();
            assert_eq!(line_items.len(), 1, "{}: exactly one line_items section", b.kind);
            assert_eq!(
                line_items[0].priced,
                is_pricing_kind(&b.kind),
                "{}: priced mirrors is_pricing_kind",
                b.kind
            );
            let (total_kind, total_label_key) = total_shape(&b.kind);
            assert_eq!(b.total_kind, total_kind, "{}: total_kind mirrors total_shape", b.kind);
            assert_eq!(
                b.total_label_key, total_label_key,
                "{}: total_label_key mirrors total_shape",
                b.kind
            );
            assert!(
                line_items[0].fields.is_empty()
                    && b.sections.iter().all(|s| s.fields.is_empty()),
                "{}: built-ins carry ZERO fields (launch-safety: zero fill calls)",
                b.kind
            );
        }
    }

    /// WE-A core — the guard exercised the way every real launch exercises it.
    #[test]
    fn tombstoned_builtin_survives_a_fresh_seed_call() {
        let s = Store::open_in_memory("device-a").unwrap();
        s.conn
            .execute(
                "UPDATE document_schemas SET deleted_at = 500, updated_at = 500 WHERE id = ?1",
                [BUILTIN_SCHEMA_ID_ESTIMATE],
            )
            .unwrap();
        seed_builtin_schemas(&s.conn).unwrap();
        let deleted_at: Option<i64> = s
            .conn
            .query_row(
                "SELECT deleted_at FROM document_schemas WHERE id = ?1",
                [BUILTIN_SCHEMA_ID_ESTIMATE],
                |r| r.get(0),
            )
            .unwrap();
        assert_eq!(deleted_at, Some(500), "stays tombstoned — never resurrected");
        let count: i64 = s
            .conn
            .query_row("SELECT COUNT(*) FROM document_schemas", [], |r| r.get(0))
            .unwrap();
        assert_eq!(count, 7, "no duplicate row was inserted either");
    }
}
