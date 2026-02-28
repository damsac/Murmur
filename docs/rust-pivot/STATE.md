# Murmur Rust Pivot — State

## Current Phase

**Phase 1: Rust Core + CLI** — Not started

## Milestones

### Phase 1 Milestones

- [ ] Cargo workspace scaffolded (`rust/Cargo.toml`, `murmur-core`, `murmur-cli`)
- [ ] Entry domain model (`entry.rs`) — create, update, complete, archive, snooze
- [ ] AppState + AppAction + handle_message() — TEA core loop
- [ ] Actor thread with flume channels
- [ ] SQLite persistence (`db.rs`) — entries table, CRUD operations
- [ ] LLM service (`llm.rs`) — reqwest client, PPQ.ai integration, tool-call parsing
- [ ] Agent types (`agent.rs`) — AgentAction, AgentContextEntry, prompts
- [ ] Credit system (`credits.rs`) — authorize, charge, balance, SQLite-backed
- [ ] CLI binary — interactive text input → agent processing → display results
- [ ] End-to-end test: type text → LLM creates/updates entries → persisted to SQLite

## Active Work

None — genesis complete, ready to begin Phase 1.

## Blockers

None.

## Key Files

| File | Status | Purpose |
|------|--------|---------|
| `rust/Cargo.toml` | Not created | Workspace manifest |
| `rust/crates/murmur-core/` | Not created | Domain logic |
| `rust/crates/murmur-cli/` | Not created | Interactive CLI |
| `docs/rust-pivot/PROCESS.md` | Created | Process constitution |
| `docs/rust-pivot/STATE.md` | This file | Living dashboard |

## Notes

- PPQ_API_KEY needed for LLM integration (already available in project.local.yml)
- Current Swift app remains functional on main branch during Rust development
- RMP architecture bible: https://github.com/justinmoon/rmp-example/blob/master/rmp-architecture-bible.md
