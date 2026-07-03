use rusqlite::Connection;

use crate::error::CoreError;

/// One entry per schema version, applied in order. NEVER edit an existing
/// entry after it has shipped — append a new one.
pub(crate) const MIGRATIONS: &[&str] = &[
    // v1: initial schema (spec §9: timestamps + device id on every row, tombstones)
    r#"
    CREATE TABLE jobs (
        id           TEXT PRIMARY KEY,
        name         TEXT NOT NULL,
        client       TEXT,
        site         TEXT,
        scheduled_at INTEGER,
        status       TEXT NOT NULL,
        created_at   INTEGER NOT NULL,
        updated_at   INTEGER NOT NULL,
        device_id    TEXT NOT NULL,
        deleted_at   INTEGER
    );

    CREATE TABLE sessions (
        id         TEXT PRIMARY KEY,
        job_id     TEXT REFERENCES jobs(id),
        status     TEXT NOT NULL,
        transcript TEXT NOT NULL DEFAULT '',
        summary    TEXT,
        started_at INTEGER NOT NULL,
        ended_at   INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        device_id  TEXT NOT NULL,
        deleted_at INTEGER
    );

    CREATE TABLE items (
        id         TEXT PRIMARY KEY,
        session_id TEXT NOT NULL REFERENCES sessions(id),
        kind       TEXT NOT NULL,
        text       TEXT NOT NULL,
        done       INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        device_id  TEXT NOT NULL,
        deleted_at INTEGER
    );

    CREATE TABLE contacts (
        id         TEXT PRIMARY KEY,
        name       TEXT NOT NULL,
        trade      TEXT,
        phone      TEXT,
        notes      TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        device_id  TEXT NOT NULL,
        deleted_at INTEGER
    );

    CREATE TABLE artifacts (
        id         TEXT PRIMARY KEY,
        session_id TEXT NOT NULL REFERENCES sessions(id),
        kind       TEXT NOT NULL,
        title      TEXT NOT NULL,
        body       TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        device_id  TEXT NOT NULL,
        deleted_at INTEGER
    );

    CREATE TABLE reflection_state (
        id                INTEGER PRIMARY KEY CHECK (id = 1),
        signals           TEXT NOT NULL,
        last_reflected_at INTEGER NOT NULL DEFAULT 0
    );

    CREATE INDEX idx_sessions_started ON sessions(started_at);
    CREATE INDEX idx_items_session ON items(session_id);
    CREATE INDEX idx_artifacts_session ON artifacts(session_id);
    "#,
];

pub(crate) fn migrate(conn: &Connection) -> Result<(), CoreError> {
    let version: i64 = conn.pragma_query_value(None, "user_version", |r| r.get(0))?;
    for (i, sql) in MIGRATIONS.iter().enumerate().skip(version as usize) {
        conn.execute_batch(sql)?;
        conn.pragma_update(None, "user_version", (i + 1) as i64)?;
    }
    Ok(())
}
