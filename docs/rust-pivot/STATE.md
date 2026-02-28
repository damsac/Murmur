# Murmur Rust Pivot — State

## Current Phase

**Phase 1: Rust Core + CLI** — In progress

## Milestones

### Phase 1 Milestones

- [x] Cargo workspace scaffolded (`rust/Cargo.toml`, `murmur-core`, `murmur-cli`)
- [x] Entry domain model (`entry.rs`) — create, update, complete, archive, snooze
- [ ] AppState + AppAction + handle_message() — TEA core loop
- [ ] Actor thread with flume channels
- [ ] SQLite persistence (`db.rs`) — entries table, CRUD operations
- [ ] LLM service (`llm.rs`) — reqwest client, PPQ.ai integration, tool-call parsing
- [ ] Agent types (`agent.rs`) — AgentAction, AgentContextEntry, prompts
- [ ] Credit system (`credits.rs`) — authorize, charge, balance, SQLite-backed
- [ ] CLI binary — interactive text input → agent processing → display results
- [ ] End-to-end test: type text → LLM creates/updates entries → persisted to SQLite

## Active Work

Next: implement `handle_message()` in `update.rs` — the TEA core loop that processes `AppAction` and mutates `AppState`. AppState and AppAction structs are already defined in `state.rs` and `action.rs`.

## Blockers

None.

## Key Files

| File | Status | Purpose |
|------|--------|---------|
| `rust/Cargo.toml` | Created | Workspace manifest |
| `rust/crates/murmur-core/` | Created | Domain logic |
| `rust/crates/murmur-core/src/entry.rs` | Created | Entry model + enums + operations (12 tests) |
| `rust/crates/murmur-core/src/state.rs` | Created | AppState struct |
| `rust/crates/murmur-core/src/action.rs` | Created | AppAction enum + entry/agent action types |
| `rust/crates/murmur-core/src/lib.rs` | Created | Module declarations |
| `rust/crates/murmur-cli/` | Created | Interactive CLI (stub) |
| `docs/rust-pivot/PROCESS.md` | Created | Process constitution |
| `docs/rust-pivot/STATE.md` | This file | Living dashboard |

## Notes

- PPQ_API_KEY needed for LLM integration (already available in project.local.yml)
- Current Swift app remains functional on main branch during Rust development
- RMP architecture bible: https://github.com/justinmoon/rmp-example/blob/master/rmp-architecture-bible.md
