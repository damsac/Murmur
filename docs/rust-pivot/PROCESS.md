# Murmur Rust Pivot — Process

## What we're building

Murmur's business logic moves from Swift to Rust, following the RMP (Rust Multi-Platform) architecture. The SwiftUI app becomes a thin rendering layer. All state, actions, entry management, LLM processing, and persistence live in Rust.

## Architecture: TEA (The Elm Architecture)

```
User input → AppAction (fire-and-forget) → Rust actor thread → handle_message() → AppState mutation → UI re-render
```

- **AppState**: Single struct containing all app data (entries, credits, recording state, navigation, toasts)
- **AppAction**: Enum of every user intent and lifecycle event
- **handle_message()**: Pure function that transforms state based on actions
- **Actor thread**: std::thread owns all mutable state, processes messages sequentially via flume channel
- **Tokio runtime**: Embedded in actor for async I/O (LLM API calls, etc.)

## Phases

### Phase 1: Rust Core + CLI (current)

Build the domain logic and prove it works via an interactive CLI.

**Scope:**
- Entry domain model (create, update, complete, archive, snooze)
- AppState / AppAction / handle_message()
- LLM service (reqwest → PPQ.ai with tool calling)
- Agent processing pipeline (transcript → LLM → actions → state mutation)
- SQLite persistence (rusqlite)
- Credit system (authorize, charge, balance)
- CLI binary for interactive testing (text input → agent → display)

**Not in scope:**
- UniFFI bindings
- iOS/Swift integration
- Voice transcription (CLI uses text input)
- Push notifications
- StoreKit purchases

### Phase 2: UniFFI + iOS Bridge (future)

- murmur-ffi crate with UniFFI exports
- AppManager (@Observable) in Swift observing Rust state
- Capability bridges: transcription, notifications, purchases
- Thin SwiftUI views replacing current Murmur/ app
- XcodeGen integration for xcframework

### Phase 3: Polish + Migration (future)

- Data migration from SwiftData → Rust SQLite
- Feature parity with current Swift app
- Remove legacy MurmurCore Swift package

## Project Structure

```
rust/
├── Cargo.toml                    # Workspace manifest
├── crates/
│   ├── murmur-core/              # Domain logic
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── state.rs          # AppState struct
│   │       ├── action.rs         # AppAction enum
│   │       ├── update.rs         # handle_message() + actor
│   │       ├── entry.rs          # Entry model + operations
│   │       ├── agent.rs          # LLM agent types (actions, context, prompts)
│   │       ├── llm.rs            # PPQ.ai HTTP client + tool-call parsing
│   │       ├── credits.rs        # Credit system
│   │       └── db.rs             # SQLite persistence
│   └── murmur-cli/               # Interactive CLI
│       ├── Cargo.toml
│       └── src/
│           └── main.rs
```

## Decisions Made

| Decision | Choice | Why |
|----------|--------|-----|
| Rust location | `rust/` at project root | Standard RMP layout, clean separation |
| Migration | Clean slate core + CLI | Prove logic works before bridging to Swift |
| Persistence | Rust-side SQLite | Rust owns all state and business logic |
| Platforms | iOS only (for now) | Get one platform right, architecture supports adding more |
| State pattern | TEA / Elm Architecture | Unidirectional, predictable, testable |
| FFI | UniFFI proc-macros (phase 2) | No .udl files, types defined in Rust |
| Async runtime | Tokio (embedded in actor) | For HTTP calls to PPQ.ai |
| Message passing | flume channels | Non-blocking dispatch, clean actor pattern |
| Error handling | Errors become state | No Result types cross FFI, toasts for user-visible errors |

## Conventions

- **Rust owns policy, Swift owns OS handles.** If it's a business decision, it's Rust. If it's an OS API call, it's a capability bridge.
- **AppState is the single source of truth.** SwiftUI views are derived from AppState, never maintain their own business state.
- **Actions are imperative and fire-and-forget.** `dispatch(action)` returns immediately. Results emerge as state changes.
- **No business logic in Swift.** If you find yourself writing an `if` that decides what the app should *do* (not how it should *look*), that belongs in Rust.
- **Monotonic rev field** on AppState for efficient change detection across FFI.
- **Errors are toasts.** Operational errors set `state.toast = Some("...")`, no panics for recoverable failures.

## Dev Environment

Rust toolchain is provided by the Nix flake (`flake.nix`). Enter with `direnv allow` or `nix develop`.

**Flake provides:** cargo, rustc, clippy, rustfmt, rust-analyzer (plus existing Swift tooling)

**Key commands:**
```bash
cd rust && cargo build          # Build all crates
cd rust && cargo test           # Run all tests
cd rust && cargo run -p murmur-cli  # Run the CLI
```

**Nix+Rust note:** The flake strips `SDKROOT`, `DEVELOPER_DIR`, etc. for Xcode compatibility. Rust builds use the system clang — no special wrapper needed for Phase 1 (no cross-compilation yet).

## Branch Strategy

- Rust development happens on a feature branch: `feat/rust-core`
- The Swift app on `main` remains functional and untouched during Phase 1
- Merge to `main` when Phase 1 is complete and the CLI works end-to-end
- Phase 2 (UniFFI + iOS) will modify the Swift side

## Tmux Lanes

Two lanes for Phase 1:

| Lane | Agent | Purpose |
|------|-------|---------|
| Main | Meta / human | Strategic decisions, code review, PROCESS/STATE updates |
| Builder | Claude Code | Writes Rust code, runs cargo build/test, iterates on compilation errors |

**Lane startup:** Builder lane reads `docs/rust-pivot/PROCESS.md` + `docs/rust-pivot/STATE.md` to orient. Checks `STATE.md` for current milestone and active work.

**Lane handoff:** Builder updates `STATE.md` when completing a milestone. Main lane reads STATE.md to decide next assignment.

**When to add lanes:** If Phase 1 work parallelizes (e.g., LLM service and persistence can be built simultaneously), spin up a second builder lane.

## Session Lifecycle

### Cold Start (new session)

1. Read `docs/rust-pivot/PROCESS.md` — architecture, decisions, conventions
2. Read `docs/rust-pivot/STATE.md` — current phase, active work, blockers
3. Read `memory/MEMORY.md` — key decisions summary
4. Check `rust/` directory — what code exists, does `cargo build` pass?
5. Resume from STATE.md's "Active Work" section

### Warm Handoff (context compacting)

1. Update `STATE.md` with current progress before compaction
2. Note any in-flight work that isn't committed
3. Next turn reads STATE.md to continue

### Session End

1. Commit working code (even if incomplete — use WIP commits on feature branch)
2. Update `STATE.md` — mark completed milestones, update "Active Work"
3. Update `memory/MEMORY.md` if any new stable patterns were discovered

## Reference Material

- **RMP Architecture Bible** (vendored): `docs/rust-pivot/rmp-architecture-bible.md` (2654 lines)
- **Current Swift app**: `Murmur/` + `Packages/MurmurCore/` (read for domain logic to port)
- **RMP example repo**: https://github.com/justinmoon/rmp-example

## Feedback Loops

- `cargo build` / `cargo test` in `rust/` — the build is the primary feedback
- `cargo run -p murmur-cli` — end-to-end flow testing
- `STATE.md` updated after each milestone completion
- `PROCESS.md` updated when decisions change
