# Murmur Rust Core — Plan 18: editable notes buckets (the notes-entry CRUD seam)

> **For agentic workers:** REQUIRED SUB-SKILL: `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans`. Steps use checkbox (`- [ ]`) syntax. The Rust tasks (1–3) are **hermetic**: in-memory `Store`, `MockProvider`, `SpyStore` — **no model, no `whisper` feature, no network, no mic**. `cargo test --workspace` must NEVER require the `whisper` feature or a model file (the load-bearing CI invariant). Run `cargo`/`xcodegen` **inside** the Nix dev shell; run `xcodebuild` **outside** it (Nix linker env breaks Xcode `ld`). Never read `.env` or `project.local.yml`.
>
> **⚠ SHIPPABILITY — merging this plan auto-publishes the TestFlight internal lane on real-engine** (CANON 2026-07-10). main must build the **real-core archive** at every merge. Plan 18 is **additive** (an `id` field on the notes artifact's `NotesEntry` + a new FFI CRUD surface that rewrites the notes artifact body + a Swift protocol seam), so it is **ONE PR** — but the real-core compile is a **MANDATORY manual gate** (Task 5; CI cannot build real-core).
>
> **Design source:** this plan implements the "narrative bucket editing" seam that **Plan 16 explicitly deferred** — keeper decision D-#5 (`2026-07-14-rust-core-16-item-crud.md`): *"the Scope/Constraints/Conditions buckets are a derived `write_notes` artifact; editing them means versioning the `NotesPayload` artifact, a different seam."* This is that seam. It carries forward Plan 16's binding decisions where they transfer (Processed-gate; re-read-from-engine; R6/R7).
>
> **The sac edit UI is landing ALONGSIDE this plan** (a sibling `pr/sac/notes-bucket-edit-ui`, already built + demo-verified against `DemoWalkEngine` parity). Unlike Plan 16 (where the UI was a later follow-up), the UI exists now; this plan supplies the real-core data path so the UI works on-device. **Sequencing:** dam's seam PR merges **first** (or together) — the UI's real-core path throws a `pending` stub until the FFI methods resolve (Task 4), so a UI-first merge would ship an always-erroring "edit note" on real-engine. Land dam first.

**Goal.** Make the **first three sections of the notes screen editable** — `SCOPE OF WORK`, `CONSTRAINTS`, `CONDITIONS & ISSUES` (the Plan-14 coordination buckets). Today only the priced items board is editable (Plan 16); the buckets render read-only (`NotesView.notesEntryRow` has no tap, and there is no CRUD seam for them anywhere). The operator's field report is a first draft — a mis-heard budget ("under $1,200" → "$2,100"), a wrong scope line, a condition that should be added or dropped — and a correction that doesn't reach the notes they **export/send** is worse than none (Plan 16's thesis, applied to buckets). Because the buckets live in a **`kind=="notes"` artifact body** (`{"buckets":[…]}` JSON), the edit lives there: read the artifact → `parse_notes_artifact` → mutate the `Vec` → `serialize_buckets` → `update_artifact_body`. Every later `session_notes()` read (the notes screen) and `exportNotes()` reflects it.

**What lands (all in ONE PR):**
1. **murmur-core — `NotesEntry` gains a stable `id`, round-tripped through the artifact.** `pipeline::notes::NotesEntry` (`{bucket,label,detail}`) gains `id: String`; `parse_notes_artifact`/`parse_notes_value` read an `"id"` when present and **mint a UUIDv7 when absent** (legacy pre-18 artifacts + fresh `write_notes` output that didn't emit one); `serialize_buckets` writes it. (Task 1.)
2. **ffi — the CRUD surface: `update_notes_entry` / `add_notes_entry` / `remove_notes_entry`.** Engine-keyed (the walk is over at review), `Processed`-gated (the `build_document`/Plan-16 precedent), operating by **artifact rewrite** over the existing `list_artifacts_for_session` + `parse_notes_artifact` + `serialize_buckets` + `update_artifact_body` (add the notes artifact if none exists yet). `bucket` validated against the three known wire strings (`NotesBucket::from_wire`, R6 — reject unknown, never coerce). FFI `NotesEntry` gains `id`; `convert::notes_entries` threads it. New `EngineError::NotesEntry`. (Task 2.)
3. **ffi — the round-trip invariant, pinned.** `update` then `session_notes()` reflects it (label/detail/bucket); `remove` drops the entry; `add` **appends**; a legacy artifact with id-less entries **backfills + persists** ids on first edit. (Task 3.)
4. **apps/ios — the sac seam + demo parity.** `WalkEngine.updateNotesEntry/addNotesEntry/removeNotesEntry` on both engines; `DemoWalkEngine` in-memory parity; `NotesEntryFixture` gains `id`. The **edit UI is sac's sibling PR** (built now). (Task 4.)
5. **Real-core compile + bindings drift (dam-manual) + merge.** (Task 5, MANDATORY gate.)

**What Plan 18 is NOT (see Non-goals).** No SUMMARY editing (the narrative summary is a separate `NotesPayload.summary`, its own seam — deferred). No **document propagation** — buckets are notes-screen + notes-export content, they do **not** render into the built document today (D5-18); when the DocumentSchema seam (#207 §7.2) lets buckets flow into documents they'll propagate for free (they already live in the artifact the builder would read). No **correction-learning signal** (Plan 17's domain — a bucket text edit does not touch `record_correction`). No mid-walk editing (edit-at-review, post-`finish()`, is the whole surface).

---

## Binding decisions (carried from Plan 16 where they transfer)

1. **Editable fields: `label` + `detail` + `bucket`.** A mis-filed bucket ("this is a constraint, not scope") is as trust-breaking as a mis-heard word. `bucket` validated against the three known variants; unknown rejected (R6). `detail` may be empty (a terse note is valid); `label` may not (an empty entry is noise).
2. **Delete: tombstone the *entry within the artifact* by rewrite** — there is no per-entry tombstone row (buckets aren't rows); "remove" means the entry is dropped from the rewritten artifact body. The artifact row itself is untouched (its `updated_at` bumps). This is the artifact analogue of Plan 16's item tombstone.
3. **Stable ids post-`finish()`.** Single-writer store; `Processed` is terminal; the notes artifact is written once at `process()` and thereafter changes **only** via these edits (which re-read after each). So an entry's `id` is stable across the review session — the same guarantee Plan 16's item ids have (keeper D-#6). → **D3-18: mutations are `Processed`-gated.**
4. **App-side rule.** After a mutation the notes screen patches the returned echo in place for optimistic feedback but treats the **engine as the source of truth** — the returned `NotesEntry` is an echo, not a re-derivation of the whole artifact (keeper D-#7). A full re-read seam for buckets (`loadNotes`) rides in with the walk-reopen work (#223); until then the echo-patch mirrors Plan 16's item edit exactly.

---

## Hard dependencies (all DONE, on `main`)

- **The notes artifact (Plan 14 — LANDED):** `pipeline::notes::NotesEntry { bucket: String, label, detail }`; `parse_notes_artifact(body) -> Vec<NotesEntry>` and `serialize_buckets(&[NotesEntry]) -> String` (`crates/murmur-core/src/pipeline/notes.rs`) — the tolerant `{"buckets":[…]}` round-trip (garbled → `[]`, R7). The buckets are persisted as a `kind=="notes"` **artifact** (not item rows, D5-14). `session_notes()` (`crates/ffi/src/session.rs:432`) reads the latest `kind=="notes"` artifact and parses it; unknown buckets dropped by `convert::notes_entries` (R6).
- **Artifact store (Plans 03/13 — LANDED):** `Store::add_artifact(session_id, kind, title, body, …)`, `Store::update_artifact_body(id, body)` (`UPDATE artifacts SET body=?, updated_at=? WHERE id=? AND deleted_at IS NULL`), `Store::list_artifacts_for_session(session_id)`, `Store::get_artifact(id)` (`crates/murmur-core/src/store/artifacts.rs`). **`update_artifact_body` is the whole rewrite mechanism — no new store method needed** (contrast Plan 16, which added `Store::update_item`; the artifact-body update path already exists).
- **Engine-keyed CRUD precedents (LANDED):** `crates/ffi/src/items.rs` (Plan 16 — the exact lock-then-mutate, `Processed`-gate-under-the-same-lock, `EngineError`-per-domain, `SpyStore`+literal-`Providers` test shape this plan copies), `crates/ffi/src/photos.rs`, `vocabulary.rs`. `build_document` (`document_build.rs`) is the `Processed`-gated post-`finish()` precedent.
- **`NotesBucket::from_wire` (Plan 14 — LANDED):** `crates/ffi/src/notes.rs:29` — maps `"scope_of_work"|"constraints"|"conditions_and_issues"` → enum, else `None` (drop). The **validation boundary** for a re-file's target bucket (Task 2 reuses it).

**Spec basis:** R6 (validate/reject unknown `bucket`; `id` minted, never fabricated content); R7 (inspectable & undoable — every edit is a visible artifact rewrite, remove is reversible by re-adding, no silent state); R9 (spend — `update`/`add`/`remove` add **zero** LLM calls). Design: Plan 16 keeper decisions; `meta/CANON.md`.

---

## Architecture — decisions, justified (reviewers read these first)

### D1-18. The seam is an **artifact rewrite**, not a new table
The buckets are a **derived `write_notes` artifact** (D5-14), not rows. So — unlike Plan 16's item CRUD (row `UPDATE`) — the seam reads the `kind=="notes"` artifact body, parses it to `Vec<NotesEntry>`, mutates the vec, re-serializes, and calls the **existing** `update_artifact_body`. Rationale: the artifact IS the storage; a parallel item-style table would duplicate the source of truth and desync from `session_notes()`. This is the "version the `NotesPayload` artifact" path Plan 16's D-#5 named. It reuses `parse_notes_artifact` ↔ `serialize_buckets` verbatim, so the parse tolerance (R7) and bucket-drop (R6) are inherited, not re-implemented.

### D2-18. Stable per-entry `id`, persisted in the artifact body
Editing needs to address a single entry across reads; entries have **no id** today (`{bucket,label,detail}`). Options: (a) address by array **index** — brittle (no cross-read identity, shifts on add/remove, no clean Swift `ForEach` key); (b) a stable **`id`**, persisted in the body. Choose (b), mirroring items: `NotesEntry` gains `id: String` (UUIDv7). Minted at the `write_notes`/serialize site going forward; for **legacy** artifacts (and any `write_notes` output without one), `parse_notes_artifact` **mints an id when `"id"` is absent**, and the **first edit persists the backfill** (the CRUD rewrites the whole body with ids — WE-E). Un-edited legacy sessions are behavior-preserving: `session_notes()` still returns the same buckets, now each carrying a stable id the app uses as a `ForEach` key. The FFI `NotesEntry` and app `NotesEntryFixture` gain the matching `id`.

### D3-18. Mutations are **`Processed`-gated** (the `build_document`/Plan-16 rule)
`update_notes_entry`/`add_notes_entry`/`remove_notes_entry` (FFI) require `session.status == Processed`; any other status → `EngineError::NotesEntry` (validation, thrown, never a panic). Same reasoning as Plan 16 D3-16: `Recording`/`AwaitingProcessing` have a pending pass that rewrites the notes artifact (a reprocess writes a fresh `kind=="notes"` artifact after sweeping the prior — `session_notes`'s own comment) and would clobber an edit; `Failed` is retryable (re-runs `process()`); `Processed` is terminal, the artifact is fixed, ids stable. "Editable" ≡ "buildable" — one coherent rule. The gate is a status read **under the same store lock** as the rewrite (no await between check and write), so no TOCTOU.

### D4-18. `add` appends; `remove` drops; `bucket` re-file is validated
- **Add:** mints a fresh entry (`id` = new UUIDv7), appends to the parsed `Vec` (last), re-serializes. The app renders buckets in the fixed `scopeOfWork → constraints → conditionsAndIssues` order regardless of vec position, so "append" is order-within-bucket; a fresh entry is the last of its bucket.
- **Remove:** drops the entry with the given `id` from the vec, re-serializes. A missing/already-removed `id` → `EngineError::NotesEntry` (mirror the item `NotFound` shape).
- **Re-file (`bucket`):** validated via `NotesBucket::from_wire`; unknown → `EngineError::NotesEntry` (R6, never coerce to a default). `None` = leave unchanged.
- **No `write_notes` re-run, no LLM (R9):** every op is a pure parse→mutate→serialize→`update_artifact_body`.

### D5-18. No document propagation in v1 (the simplification vs Plan 16)
Plan 16 had to thread `right` → `qty` into `render_structure_document` because items ARE the document. Buckets are **not** — the built document (`DocumentSheet`) renders items + totals + terms + signature, never the coordination buckets. So a bucket edit must reach exactly two readers, **both of which read the artifact**: the notes screen (`session_notes()`) and notes export (`exportNotes()`, app-side, over the same payload). Rewriting the artifact body satisfies both — **no document-builder change**. (When #207's `DocumentSchema` lets buckets flow into a document, they propagate for free: the builder would read the same artifact this seam rewrites.) Reviewer: confirm no document test depends on notes-bucket content (they don't — the builder never reads the `kind=="notes"` artifact).

### D6-18. Sync bookkeeping: the **artifact row's** `updated_at`, not the session's
`update_artifact_body` bumps the artifact row's `updated_at` (it already does). The session `updated_at` is **not** bumped — consistent with Plan 16 D6-16 (mutations are row-level sync events). The artifact row + `device_id` is the sync unit; a session bump would create false conflicts.

---

## Worked examples (reviewers: hand-recompute against the real code)

Conventions: the `kind=="notes"` artifact body is `{"buckets":[{ "id"?, "bucket", "label", "detail" }, …]}`. `parse_notes_artifact` → `Vec<NotesEntry>` in body order (mint `id` where absent). App renders grouped by fixed bucket order; within a bucket, body order.

**Shared fixture F1 (landscape, Processed).** Notes artifact, three entries (ids N1<N2<N3 by insertion):

| id | bucket | label | detail |
|----|--------|-------|--------|
| N1 | `scope_of_work` | `Mulch — front beds` | `Darker mulch than last year.` |
| N2 | `constraints` | `Budget` | `Under $1,200.` |
| N3 | `conditions_and_issues` | `Zone-2 head broken` | `Replace — parts + labor.` |

**WE-A — `update_notes_entry` fixes a mis-heard detail.** `update_notes_entry(sid, N2, label=None, detail=Some("Under $2,100."), bucket=None)`.
- Validate: `Processed` ✓; `detail` any string ✓; `label`/`bucket` unchanged.
- Read `kind=="notes"` artifact → parse → find N2 → set `detail="Under $2,100."` → `serialize_buckets` → `update_artifact_body(artifact_id, body)`. Artifact `updated_at` bumped; session's not (D6).
- `session_notes()` now returns N2 with the corrected detail; `CONSTRAINTS` on screen (and in `exportNotes`) reflects it. **No LLM, no document change (D5).** ✓

**WE-B — re-file a bucket.** `update_notes_entry(sid, N1, label=None, detail=None, bucket=Some("constraints"))`.
- `NotesBucket::from_wire("constraints")` = `Some(Constraints)` ✓. N1 moves `scope_of_work → constraints`. Re-serialize. On screen N1 leaves `SCOPE OF WORK`, joins `CONSTRAINTS` (fixed-order render). An unknown target (`from_wire("logistics") == None`) → `EngineError::NotesEntry` (R6). ✓

**WE-C — `remove_notes_entry` drops an entry.** `remove_notes_entry(sid, N3)`. Parse → drop N3 → serialize (now 2 entries) → `update_artifact_body`. `session_notes()` = [N1, N2]; `CONDITIONS & ISSUES` section disappears (empty buckets are omitted by the app's `bucketed`). A second `remove_notes_entry(sid, N3)` → `EngineError::NotesEntry` (id absent). ✓

**WE-D — `add_notes_entry` appends.** `add_notes_entry(sid, bucket="scope_of_work", label="Edge the beds", detail="")`. Mint N4; append. `session_notes()` = [N1, N2, N4] (N3 removed in WE-C); N4 is the **last** `scope_of_work` entry on screen; `detail=""` renders label-only. If **no** `kind=="notes"` artifact exists yet (a walk that captured items but no coordination notes), `add_notes_entry` **creates** one via `add_artifact(kind="notes", body=serialize_buckets(&[N4]))`. ✓

**WE-E — legacy artifact backfills ids on first edit.** A pre-18 artifact body `{"buckets":[{"bucket":"scope_of_work","label":"Mulch","detail":"…"}]}` (no `"id"`). `session_notes()` parses it, `parse_notes_artifact` **mints** an id for the entry (display-stable within the process). The first `update_notes_entry`/`add`/`remove` re-serializes **with** ids and `update_artifact_body` persists them — subsequent reads carry the same ids. Un-edited legacy sessions are unchanged on disk (the mint is display-only until an edit writes it). Reviewer: confirm the mint is deterministic-enough for one process lifetime (a fresh UUIDv7 per parse is fine — the app only needs stability between a read and the edit it triggers, and the edit persists it). ✓

---

## Staging (main stays shippable)

**ONE PR** (`pr/dam/plan-18-notes-entry-crud` → main). All-additive: an `id` field on the notes artifact's `NotesEntry` (backward-compatible parse), a new FFI CRUD module rewriting the artifact body, a new `EngineError` variant, a Swift protocol seam + demo parity. No migration (the artifact body is schemaless JSON — an added field is tolerated by the existing tolerant parser). Gated by `cargo test --workspace` + `clippy --workspace --all-targets -- -D warnings` + iOS **demo** build + **the mandatory dam-manual real-core compile + bindings-drift check (Task 5)**.

---

## Tasks

### Task 1 — `NotesEntry.id` + artifact round-trip (murmur-core; D2-18)
- [ ] **RED** (`pipeline/notes.rs` tests): (a) `parse_notes_artifact` on a body **with** `"id"` preserves it; (b) on a body **without** `"id"` mints a non-empty id per entry; (c) `serialize_buckets(parse(body))` round-trips ids (parse → serialize → parse yields identical ids); (d) the existing tolerant-parse tests (garbled → `[]`, non-array → `[]`) stay green.
- [ ] **GREEN:** add `pub id: String` to `pipeline::notes::NotesEntry` (place first). In `parse_notes_value`, read `entry["id"].as_str()`; if absent/empty, `murmur_core::new_id()` (the UUIDv7 mint used everywhere). In `serialize_buckets`, emit `"id"`. Keep the bucket-string tolerance unchanged.
- [ ] **Gate:** `nix develop -c cargo test -p murmur-core` + `clippy -p murmur-core --all-targets -- -D warnings`. All pre-existing notes/pipeline tests green.

### Task 2 — FFI CRUD: `update_notes_entry` / `add_notes_entry` / `remove_notes_entry` (ffi; D1-18/D3-18/D4-18)
- [ ] **RED** (new module `crates/ffi/src/notes_crud.rs`, reusing the `SpyStore` + literal-`Providers` harness from `items.rs`; `mod notes_crud;` in `lib.rs`):
  - **Status gate (D3):** each op on `Recording`/`AwaitingProcessing` → `EngineError::NotesEntry`; on `Processed` → `Ok`. (Build the `Processed` fixture as `items.rs`/`document_build.rs` do.)
  - **Validation (D4/R6):** empty/whitespace `label` (update-with-`Some` or add) → `NotesEntry`; an unknown `bucket` wire string → `NotesEntry`; a missing `id` (update/remove) → `NotesEntry`.
  - **Round-trip:** after `update_notes_entry(N2, detail="…")`, `session_notes()` reflects it; `remove` drops; `add` appends and, when **no** notes artifact exists, **creates** one.
  - **Backfill (WE-E):** an id-less legacy artifact → first edit persists ids (re-read shows stable ids).
- [ ] **GREEN:** add `id: String` to `crates/ffi/src/notes.rs::NotesEntry`; thread it in `convert::notes_entries` (`NotesEntry { id: e.id.clone(), bucket, label, detail }`). Add `EngineError::NotesEntry(String)` (`flat_error`, store/validation strings only — no api key). In `notes_crud.rs`:
  ```rust
  #[uniffi::export]
  impl MurmurEngine {
      pub fn update_notes_entry(&self, session_id: String, entry_id: String,
          label: Option<String>, detail: Option<String>, bucket: Option<String>)
          -> Result<NotesEntry, EngineError>
      pub fn add_notes_entry(&self, session_id: String,
          bucket: String, label: String, detail: String) -> Result<NotesEntry, EngineError>
      pub fn remove_notes_entry(&self, session_id: String, entry_id: String)
          -> Result<(), EngineError>
  }
  ```
  Each: lock the store once; `get_session` → reject `status != Processed` (D3, same-lock, no await); validate (`label` trim-non-empty when required; `bucket` via `NotesBucket::from_wire`); load the latest `kind=="notes"` artifact (`list_artifacts_for_session`, `.rev().find(|a| a.kind == "notes")` — the `session_notes` pattern); `parse_notes_artifact(&artifact.body)`; mutate the `Vec` (find-by-id / drop-by-id / append); `serialize_buckets`; `update_artifact_body(&artifact.id, &body)`. **`add` with no existing artifact:** `add_artifact(session_id, "notes", "", serialize_buckets(&[new]))`. Return the fresh FFI `NotesEntry` (with `id`). Panic-free: poisoned lock → `EngineError::NotesEntry("store lock poisoned")`.
- [ ] **Gate:** `nix develop -c cargo test -p ffi` + `clippy -p ffi --all-targets -- -D warnings`.

### Task 3 — round-trip pinned end-to-end (ffi; WE-A…WE-E)
- [ ] **RED** (`notes_crud.rs` tests, asserting through `session_notes()`): WE-A (detail edit reflected), WE-B (bucket re-file), WE-C (remove drops + second-remove errors), WE-D (add appends + create-when-absent), WE-E (legacy backfill persists). Pin the **negative**: no notes op changes `reflection_signals().corrections_since_reflection` (Plan 18 wires no correction signal — that's Plan 17's domain; guards a stray coupling).
- [ ] **Gate:** `nix develop -c cargo test -p ffi` + `nix develop -c cargo test --workspace` (whole workspace green; no `whisper`, no model).

### Task 4 — Swift seam + demo parity (apps/ios; edit UI is sac's sibling PR, ALREADY BUILT)
- [ ] **Protocol** (`WalkEngine.swift`): add `updateNotesEntry(sessionId:entryId:label:detail:bucket:) throws -> NotesEntryFixture`, `addNotesEntry(sessionId:bucket:label:detail:) throws -> NotesEntryFixture`, `removeNotesEntry(sessionId:entryId:) throws`. `NotesEntryFixture` gains `id: String` (was `let id = UUID()`). `NotesBucket` gains `wire`/`init?(wire:)`. **The `// sac:` contract mirrors Plan 16's:** edit affordances gate on `!notes.queued`; the returned entry is an optimistic echo (patch in place; engine is source of truth); `bucket` crosses the seam as a wire string.
- [ ] **`MurmurEngine`** (real, `#if canImport(MurmurCoreFFI)`): **PENDING dam's FFI (Task 2)** — the three methods `throw` a `notesEntrySeamPending` error with a `// TODO(dam, Plan 18): forward to engine.updateNotesEntry(...)` marker; `MurmurEngineFormatting.notesEntry` maps the new `entry.id` once the FFI record carries it (synthesized UUID with a TODO until then). This keeps the real-core archive compiling; dam swaps the throws for the real calls in Task 2/5.
- [ ] **`DemoWalkEngine`** parity: a per-session `notesEntries: [NotesEntryFixture]` (seeded from the sample buckets at `finish()`, stable ids); `update` partial-applies + validates `bucket` against the three wire strings + rejects empty `label` + `.processed`-gated (reuse `requireEditable`); `add` appends; `remove` drops. Enough to drive the edit UI with no backend. **(DONE in the sibling UI PR's demo changes.)**
- [ ] **Gate:** iOS **demo** build (xcodebuild OUTSIDE nix): `xcodebuild -project SitewalkGallery.xcodeproj -scheme SitewalkGallery -destination 'platform=iOS Simulator,name=iPhone 17' build`.

### Task 5 — real-core compile + bindings drift (dam-manual) + merge **[MANDATORY GATE]**
- [ ] dam runs `cd apps/ios && ./build-ffi.sh && ./generate.sh && xcodebuild … build` — confirm the real-core archive compiles against the new `update_notes_entry`/`add_notes_entry`/`remove_notes_entry` + `EngineError::NotesEntry` + `NotesEntry.id` bindings, and **swaps the `MurmurEngine` `pending` stubs for the real forwards** + wires `entry.id` in `MurmurEngineFormatting`.
- [ ] Bindings-drift check: regenerate Swift bindings; confirm the three methods resolve, `EngineError.notesEntry` is present, `NotesEntry.id` exists, no unrelated record drifted.
- [ ] **Merge** — TestFlight internal lane publishes the notes-bucket edit seam on real-engine. (sac's edit-UI PR follows/rebases on this.)

---

## Gates (every task)
- `nix develop -c cargo test --workspace` — exit 0 (run under the Nix shell; never grep counts).
- `nix develop -c cargo clippy --workspace --all-targets -- -D warnings`.
- **All pre-existing notes / artifact / document / reflection tests stay green** (the `id` field is backward-compatible parse; no builder change).
- iOS **demo** build (CI-gated) — **outside** the Nix shell.
- **MANDATORY:** real-core compile + bindings-drift (dam-manual, Task 5) — before merge.

## Acceptance criteria
1. `pipeline::notes::NotesEntry` carries a stable `id`, round-tripped through `parse_notes_artifact`/`serialize_buckets`, minted for legacy id-less entries (Task 1, WE-E).
2. `MurmurEngine::update_notes_entry`/`add_notes_entry`/`remove_notes_entry` are engine-keyed and **`Processed`-gated**; other statuses → `EngineError::NotesEntry` (Task 2, D3).
3. Edits rewrite the `kind=="notes"` artifact body via `update_artifact_body` (or create it on first add), so `session_notes()` and `exportNotes()` reflect every edit — **no document-builder change** (Task 2/3, D5).
4. `bucket` re-file is validated via `NotesBucket::from_wire` (unknown rejected, R6); empty `label` rejected; `detail` free-form (Task 2, D4).
5. `remove` drops the entry (second remove → error); `add` appends and creates the artifact when absent (Task 3, WE-C/WE-D).
6. **No correction-learning side effect** — no notes op touches `record_correction` (Task 3; that's Plan 17). 
7. The Swift seam exists on both engines with the `// sac:` echo/`!notes.queued` contract; the demo engine drives the edit UI with no backend; the real-core archive builds after dam swaps the stubs (Task 4/5).

## Non-goals (explicit)
- **The SUMMARY** (narrative `NotesPayload.summary`) — a different field/seam; deferred.
- **Document propagation** — buckets don't render into the built document today (D5); they will for free under #207's `DocumentSchema`. No `render_structure_document` change here.
- **Correction-learning** — Plan 17 owns `record_correction` + the vocab suggest-card; a bucket edit wires none of it.
- **Mid-walk editing** — `Recording`/`AwaitingProcessing`/`Failed` mutations forbidden (D3); edit-at-review (`Processed`) is the whole surface.
- **A per-entry tombstone row / a buckets table** — the buckets stay a derived artifact (D1, keeper D-#5); promoting them to rows is a larger sync-schema change, not warranted at review scale.

## Risks & rollback
- **Risk — id instability across a reprocess.** A `Failed`→retry reprocess rewrites the whole `kind=="notes"` artifact (fresh `write_notes`), minting new ids and discarding prior edits. Bounded/deliberate: editing is `Processed`-gated (D3), and a `Processed` session is not reprocessed; a salvage-a-Failed-session surface is a future design round. Rollback: none needed.
- **Risk — the artifact `add`-when-absent races an offline finish.** `add_notes_entry` on a session whose `finish()` degraded (`queued`, no `Processed`) is blocked by the D3 gate (the app also gates the affordance on `!notes.queued`), so the create path only runs on a `Processed` session that legitimately had zero coordination notes. 
- **Risk — a body without `"buckets"` or malformed JSON.** `parse_notes_artifact` already degrades to `[]` (R7); a mutate-on-`[]` for `add` yields a one-entry body (fine); `update`/`remove` on `[]` → id-not-found → `EngineError::NotesEntry` (correct — nothing to edit).
- **Rollback of the whole plan:** delete `crates/ffi/src/notes_crud.rs` + `EngineError::NotesEntry` + the `NotesEntry.id` field (ffi + core) + the Swift protocol methods/demo parity. The artifact bodies with an extra `"id"` remain valid under the pre-18 tolerant parser (the field is ignored), so no data migration is needed. All additive → clean revert.

## Open questions
1. **Full `loadNotes` re-read seam (dam).** This plan patches the echo in place (Plan 16 parity). The walk-reopen work (#223: `listSessions`/`loadNotes` over FFI) is the natural home for a full bucket re-read; until it lands, the echo-patch is the sanctioned path. — **recommend: echo-patch now; fold a `loadNotes` bucket re-read into #223.**
2. **Editing an empty-`detail` entry vs deleting it (sac UI).** A label-only entry is valid (D1). Should the UI nudge "add detail or remove"? — **recommend: allow label-only; no nudge; sac's call.**
