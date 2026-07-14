# Murmur Rust Core — Plan 16: editable items (the item CRUD seam)

> **For agentic workers:** REQUIRED SUB-SKILL: use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. The Rust tasks (1–4) are **hermetic**: in-memory `Store`, `MockProvider`, `MurmurEngine::with_providers`, a `SpyStore` for memory persistence — **no model, no `whisper` feature, no network, no mic**. `cargo test --workspace` must NEVER require the `whisper` feature or a model file (the load-bearing CI invariant). The Swift task (5) is **not CI-gated for logic** (the iOS **demo** build IS CI-gated; real-core is dam-manual) and the **edit UI — tap-to-edit interaction, inline field editors, add/remove affordances — is explicitly sac's** (`// sac:` markers). This plan provides the FFI + engine seam and a `// sac:` contract, NOT the edit UI. Run `cargo`/`xcodegen` **inside** the Nix dev shell; run `xcodebuild` **outside** it (Nix linker env breaks Xcode `ld`). Never read `.env` or `project.local.yml`.
>
> **⚠ SHIPPABILITY — merging this plan auto-publishes the TestFlight internal lane on real-engine** (CANON 2026-07-10). main must build the **real-core archive** at every merge. Plan 16 is **additive** (a new `right_text` item column behind a migration + a new FFI CRUD surface + a Swift protocol seam), so it is **ONE PR** — but the real-core compile is a **MANDATORY manual gate** (Task 6; CI cannot build real-core). See **§Staging**.
>
> **Design source (AGREED — do not relitigate):** `docs/design/2026-07-13-editable-notes.md` (merged, PR #215). The design's six open questions (§4) are **closed** by the keeper's approving review on #215 (carried below as binding decisions). This plan **implements** that agreed design; it does not reopen it.
>
> **Plan review pending.** The adversarial reviewer must hand-recompute **WE-A…WE-E** below against the real code (`Store::update_item`, `render_structure_document`, `list_open_todos`, `ReflectionPolicy::should_reflect`) and confirm every count and ordering.

**Goal.** Let the operator correct the AI's output at review and have the fix **reach the document they send** — not just repaint one screen. A mis-heard word ("Power edger" → "Mower"), a wrong quantity, a mis-filed line, a line that should be added or removed. The design's thesis (going into CANON when this ships): **a correction that doesn't reach the PDF is worse than none — it looks fixed and isn't.** Today the only editable surface is the document's amounts (`beginEdit`/`commitEdit` mutating the built `DocumentModel` **app-side** — core never hears it); an item edit done the same way would die on screen because `build_document(kind)` rebuilds from the core's stored items. So the edit has to live **where the item lives: the core.** Plan 16 is that seam: `update_item` / `add_item` / `remove_item` over FFI, mirroring `set_item_done`, so every later `build_document` (and every notes rebuild) reflects the edit for free.

**What lands (all in ONE PR):**

1. **murmur-core (`Store`) — the `right_text` column + `update_item`.** A migration adds `items.right_text` (the quantity/unit string, e.g. "3 CU YD"), `CapturedItem` gains `right: String`, and a new `Store::update_item(id, text?, kind?, right?)` mirrors `set_item_done` (partial update, tombstone-guarded, bumps `updated_at`). Ungated at the store layer, exactly like `set_item_done`/`delete_item`. (Task 1.)
2. **murmur-core — shared kind allowlist + quantity propagates to the document.** `VALID_ITEM_KINDS` promoted to one `pub const` (the agent's `AddItemTool` and the edit seam share it — no fork), and `render_structure_document` emits `qty: item.right` (was always `""`), so a quantity edit reaches every rebuilt document. (Task 2.)
3. **ffi — the CRUD surface: `update_item` / `add_item` / `remove_item`.** Engine-keyed (not `WalkSession`-scoped — the walk is over at review), `Processed`-gated (the `build_document` precedent), returning the fresh `BoardItem`; `board_item` now projects `item.right`. `kind` validated against `VALID_ITEM_KINDS` (reject unknown, R6); a **text** change fires `record_correction` (R7). New `EngineError::Item`. (Task 3.)
4. **ffi/core — the propagation invariant, pinned end-to-end.** `update_item` then `build_document` reflects the edit (title/qty); `remove_item` drops the line **and** its open-todo (cascade); `add_item` **appends** (last line). (Task 4.)
5. **apps/ios — the sac seam.** `WalkEngine.updateItem/addItem/removeItem` on both engines; `DemoWalkEngine` parity; a `// sac:` contract for the tap-to-edit UI (**NOT built here**), including the app-side one-source-of-truth rule (re-read from the engine after a mutation, never patch local state). (Task 5.)
6. **Real-core compile + bindings drift (dam-manual) + merge.** (Task 6, MANDATORY gate.)

**What Plan 16 is NOT (see Non-goals for the full list).** No edit UI. No vocab **suggest-card** (v1 records the correction signal only; the suggest-into-vocab card is a fast-follow). No **narrative bucket** editing (items-only v1). No **pricing / price-book** in core (items stay price-free; amounts remain a document-build concern, app-editable as today). No mid-walk editing (edit-at-review, post-`finish()`, is the whole v1 surface).

---

## Binding decisions from the keeper's #215 approval (do not relitigate)

Carried verbatim in intent from the approving review; **dam had veto and exercised it in two places, noted inline**:

1. **Mutable fields: `text` + `right` + `kind`.** A mis-filed line is as trust-breaking as a mis-heard word. `kind` validated against the enum, unknown rejected (R6: drop/reject unknowns, never store them).
2. **Pricing: document-only for v1.** Items stay **price-free** in core; the "LAST 3: $110·$120·$125" hint is app-side memory. A per-item price-book arrives with the `DocumentSchema` seam (#207 §7.2) as one coherent v2, not piecemeal. **`right` is quantity, NOT price** — see D2.
3. **Corrections → learning: record the signal, don't auto-add.** An item-**text** edit calls `record_correction` (R7 — it snaps reflection cadence, correct: corrections are the strongest signal we have). The corrected term becomes a **vocabulary suggestion, not a silent insert** — the 100-term cap is curated space the user owns. **v1 records the signal only; the suggest-into-vocab card is a fast-follow, not this plan.**
4. **Delete: tombstone, and remove ≠ done.** Everything in this store tombstones (single sync discipline); a hard delete would be the odd one out. `done` is completion, `remove` is retraction — an operator hiding a mistaken line is not completing work. Both kept, distinct.
5. **Items-only v1.** The narrative buckets are a derived artifact of `write_notes`; editing them means versioning the `NotesPayload` artifact — a different problem, deliberately later.
6. **Item ids are stable post-`finish()`.** Single-writer store, `Processed` is terminal, extraction only appends during a live walk — after finish the item set is fixed and id-keyed edits are safe. The one hazard is live-walk re-extraction, which v1 (edit at review, post-finish) never touches. → **D3: mutations are `Processed`-gated.**
7. **App-side rule.** After a mutation the notes/edit screen **re-reads from the engine**, never patches local state — the same one-source-of-truth rule that motivates the whole design, applied to the UI layer.

---

## Hard dependencies (all DONE, on `main`)

- **Item store (Plans 03/06a/11 — LANDED):** `Store::add_item`/`add_item_with_source`/`add_item_if_status`, `set_item_done`, `get_item`, `list_items_for_session` (`ORDER BY id ASC`), `list_open_todos` (`kind='todo' AND done=0 AND deleted_at IS NULL`), `delete_item` (tombstone + photo demote to session-level, Plan 11 D3). All in `crates/murmur-core/src/store/items.rs`. `CapturedItem` (`crates/murmur-core/src/domain.rs`): `id, session_id, kind, text, source, done, created_at, updated_at, device_id` — **no `right`, no price** today.
- **`ItemSource` (Plan 06a — LANDED):** `Live | Authoritative | Manual`. **`Manual` is never swept** by processing (`finish_session_processed`); `Live` and prior-run `Authoritative` are swept when a new authoritative pass lands. `add_item` defaults to `Manual`.
- **The document builder (Plan 13 — LANDED):** `render_structure_document(doc_kind, items, GapPolicy::PerPricingKind)` (`crates/murmur-core/src/pipeline/document.rs`) emits **one line per item, in item order**, `title = item.text`, `qty = ""` (today), `is_gap = is_pricing_kind(doc_kind)`, fresh `new_id()` line id, `item_id = item.id`. `is_pricing_kind` is `estimate|invoice` only. Gap classification depends on **`doc_kind`, not `item.kind`.** Pricing is a separate LLM pass keyed by `item_id` that only moves amounts; it reads `item.kind` and `item.text` in its prompt (`format_pricing_items`), never the transcript (R6). `DocumentBuilder::build` **requires `session.status == Processed`** (else `CoreError::InvalidState`) — the precedent D3 mirrors.
- **FFI board projection (Plan 07/11 — LANDED):** `convert::board_item(item, photo_counts) -> BoardItem { id, kind, text, right, photo_count }` (`crates/ffi/src/convert.rs`). **`right` is hard-coded `String::new()`** today ("board-chrome the Swift layer owns"). `BoardItem` is the FFI item record (`crates/ffi/src/events.rs`).
- **Engine-keyed CRUD precedents (LANDED):** `crates/ffi/src/photos.rs` (`add_photo`/`list_photos`/`remove_photo`) and `crates/ffi/src/vocabulary.rs` — the exact lock-then-map, `EngineError`-per-domain, `SpyStore`+literal-`Providers` test shape this plan copies. `build_document` (`crates/ffi/src/document_build.rs`) is the engine-keyed, `Processed`-gated, post-`finish()` precedent.
- **Reflection signal (Plan 02/04 — LANDED):** `Store::record_correction()` (`crates/murmur-core/src/reflection.rs:75`) bumps `ReflectionSignals::corrections_since_reflection` by 1 and persists. `ReflectionPolicy::should_reflect` (`crates/harness/src/reflection/policy.rs:79`) returns `true` as soon as `sessions_since_reflection > 0 && corrections_since_reflection > 0` — a correction **snaps cadence** to the next session end regardless of backoff.
- **Migrations (LANDED):** `crates/murmur-core/src/store/migrations.rs` — `MIGRATIONS: &[&str]`, applied by index, each all-or-nothing in a transaction with a `user_version` bump. **5 migrations today (v1–v5, indices 0–4).** SQLite `ADD COLUMN` with `NOT NULL` requires a `DEFAULT` (v2 `items.source` is the precedent). NEVER edit a shipped entry — append.

**Verified API facts (checked against source, not guessed):**
- `VALID_KINDS: [&str; 6] = ["todo","decision","note","safety","part","price"]` lives **only** in `crates/murmur-core/src/pipeline/tools.rs:46`; the agent `AddItemTool` rejects anything else (`:126`). Its JSON-schema `enum` mirrors the same six. This is the "enum" the keeper means (item `kind` is a **free `String`** at the domain/DB layer by design — `domain.rs:151` — so there is no Rust enum; the allowlist is the validation boundary). Task 2 promotes it to one shared `pub const` so the edit seam and the agent tool can't fork.
- `list_items_for_session` sorts `ORDER BY id ASC`; UUIDv7 string order **follows creation order** (pinned by `ids.rs::uuid_v7_string_order_follows_creation`). So `add_item` mints an id that sorts **after** every existing item → **append**, and the rebuilt document lists it **last** (D4/WE-D).
- `delete_item` is `WHERE ... deleted_at IS NULL`; a second delete (or update) of a tombstoned id returns `CoreError::NotFound{entity:"item"}` (pinned by `delete_item_is_a_tombstone`). `set_item_done` has the identical `changed == 0 → NotFound` shape.
- `render_structure_document` currently emits `"qty": ""`; changing it to `item.right` is **behavior-preserving for all existing data** because pre-migration and un-edited items have `right == ""` (the column `DEFAULT ''`).

**Spec basis:** R6 (validate/reject unknown `kind`; never fabricate a field — `right` defaults `""`, not a guess); R7 (inspectable & undoable — every edit is a visible row mutation, a text edit is a recorded correction, remove is a reversible tombstone, no silent state); R9 (spend — `update`/`add`/`remove` add **zero** LLM calls; only the user's later `build_document` tap spends, unchanged). Design: `2026-07-13-editable-notes.md`; keeper decisions above; `meta/CANON.md`.

---

## Architecture — decisions, justified (reviewers read these first)

### D1-16. The seam mirrors `set_item_done` — ungated store method, gated FFI

`Store::update_item(id, text?, kind?, right?)` is a thin, **ungated** store mutation exactly like `set_item_done` and `delete_item`: it updates only the provided fields, bumps `updated_at`, is `deleted_at IS NULL`-guarded (tombstoned → `NotFound`), and preserves `id`/`created_at`/`source`/`done`. The **session-status gate lives in the FFI layer** (`MurmurEngine::update_item`), exactly as `DocumentBuilder::build` gates `build_document` while the raw store stays gate-free. Rationale: the store is the single-writer mechanism; policy (which session states accept edits) is a boundary concern. This keeps the store method trivially reusable (e.g. a future sync-merge path) and the policy in one obvious place.

### D2-16. `right` is **quantity**, gets a core column, and propagates — it is **not** price

The design (§4.1) makes `text + right` cover Isaac's examples ("a wrong quantity"). `right` is the quantity/unit string ("3 CU YD", "× 4") — **distinct from price**, which the keeper kept document-only (D-#2). So honoring "pricing stays document-only" does **not** bar a `right` column: quantity is item data, price is build-time data. And the design's whole thesis is **propagation** — an edit that can't reach the document is the anti-pattern. Today `right` has **no core storage** (`board_item` hard-codes `String::new()`) and the document renders `qty: ""` always, so a quantity edit could not propagate. Plan 16 fixes that end-to-end:
- **Store:** a migration adds `items.right_text` (`TEXT NOT NULL DEFAULT ''`), `CapturedItem` gains `right: String`.
- **Projection:** `board_item` reads `item.right` (drops the `String::new()` stub).
- **Document:** `render_structure_document` emits `qty: item.right` (was `""`).

**This is the one place Plan 16 goes beyond "mirror `set_item_done`"** — deliberately, because the design's value proposition (correction reaches the PDF) requires quantity to live in core. Everything downstream is behavior-preserving for un-edited items (`right == ""` → `qty == ""`, exactly today's output). **Reviewer:** confirm no existing document test that asserts `qty == ""` breaks (they all use items with no `right`, so they don't — pinned in Task 2). **Column name is `right_text`, not `right`** — `RIGHT` is a SQL keyword (SQLite ≥3.39 `RIGHT JOIN`); the plain identifier is a reserved-word footgun in a bare `SELECT` column list. The domain field stays `right` (matches `BoardItem.right`); only the DB column is renamed to sidestep the keyword.

### D3-16. Mutations are **`Processed`-gated** (the `build_document` precedent)

`update_item` / `add_item` / `remove_item` (FFI) require `session.status == Processed`; any other status → `EngineError::Item` (validation, thrown, never a panic). Rationale, per keeper D-#6:
- **`Recording`** — the live extraction pass owns the board; re-extraction mints **new ids** and sweeps `Live` items on the next `process()`. An edit here races the sweep and could be clobbered. Forbidden.
- **`AwaitingProcessing`** — the authoritative pass is queued and will sweep `Live` + supersede prior `Authoritative` items. An edit in this window can be clobbered. Forbidden.
- **`Processed`** — terminal, ids stable (keeper-confirmed), **no pending pass will sweep**. This is the review surface the design targets ("edit at review"). Allowed.
- **`Failed`** — retryable; a `retry_failed_sessions` re-runs `process()`, which sweeps. Editing then retrying could clobber. **Forbidden** in v1 (a failed session has no notes/estimate to review yet anyway). If a "salvage a failed session" surface is ever wanted, that's a new design round.

This is exactly `DocumentBuilder::build`'s gate (`status != Processed → InvalidState`), so a session you can build a document for is precisely a session you can edit — one coherent rule. The gate is a **read of the current status under the same store lock as the mutation** (no await between check and write), so no TOCTOU window (the `add_item_if_status` discipline).

### D4-16. `add_item` **appends**; `remove_item` **tombstones** (remove ≠ done); a **text** edit records a correction

- **Ordering:** `add_item` mints a fresh UUIDv7 (via the existing `Store::add_item`, `source = Manual`), which sorts **after** all existing items → the new line is **last** in `list_items_for_session` and therefore the **last line** of any rebuilt document (WE-D). No explicit sort key is introduced; item order is creation order, as everywhere else. `Manual` source means the added line **survives any future reprocess** (never swept).
- **Remove is a tombstone, distinct from done** (keeper D-#4): `remove_item` calls the existing `Store::delete_item` — sets `deleted_at`, and (Plan 11 D3 cascade) demotes any photos on that item to session-level (`item_id → NULL`) so a real photo is not destroyed with a wrongly-extracted line. A tombstoned item leaves **every** list (`list_items_for_session`, `list_open_todos`, the rebuilt document). Contrast `set_item_done(true)`: the item **stays** in `list_items_for_session` (and the document) but drops out of `list_open_todos`. Both semantics coexist; the UI chooses (WE-C pins the contrast).
- **Correction signal:** `update_item` fires `Store::record_correction()` **iff the call changes `text`** to a different, non-empty value (a mis-hear was fixed — the strongest STT/vocab signal, keeper D-#3). A **kind-only** or **right-only** edit does **not** (re-filing / quantity is not a mis-hear). `add_item` and `remove_item` do **not** (adding/retracting a line is not correcting a mis-hear). v1 **only** bumps the counter (which snaps reflection cadence, WE-E); it does **not** auto-add or emit a vocabulary suggestion — the suggest-card is a fast-follow (keeper D-#3, Non-goals).

### D5-16. Validation & error surface (R6/R7)

Enforced in the FFI method, before the store write:
- **`text`** (when provided): rejected if empty after trim → `EngineError::Item("item text is empty")`. `None` = leave unchanged.
- **`kind`** (when provided): rejected if not in `VALID_ITEM_KINDS` → `EngineError::Item("invalid kind '{k}'; must be one of: …")` (the agent tool's exact message shape). `None` = leave unchanged.
- **`right`** (when provided): **any** string accepted, including `""` (empty = "no quantity", the default). `None` = leave unchanged. No format validation — quantity strings are free-form display text ("3 CU YD", "× 4", "2 hrs"); coercing them would be R6-fabrication in reverse.
- **All-`None` update:** a no-op that still bumps `updated_at` and returns the current row (harmless; the UI won't call it, but it must not error).
- **Missing/tombstoned `item_id`** → `EngineError::Item` (from the store's `NotFound`). **Missing session / wrong status** → `EngineError::Item`.
- **`add_item`:** `text` non-empty (trim) + `kind` ∈ allowlist, else `EngineError::Item`. **`right`** is a parameter too (a line can be added with a quantity in one call).
- New `EngineError::Item(String)` variant (`flat_error`, store/validation strings only — no api key, Plan 07 CANON). Panic-free across FFI: a poisoned lock → `EngineError::Item("store lock poisoned")`.

### D6-16. Sync bookkeeping: item-row `updated_at`, **not** session `updated_at`

Every mutation bumps the **item row's** `updated_at` (and `remove` sets `deleted_at`); the item row + `device_id` is the sync unit (spec §9). The **session's** `updated_at` is **not** bumped — consistent with `set_item_done`/`delete_item` today (item mutations are item-row sync events, not session events). A future sync-merge resolves per-row by `updated_at`/`device_id`; a session-level bump would create false session conflicts. Pinned so a reviewer doesn't "helpfully" add a session touch that pollutes the sync log.

---

## Worked examples (reviewers: hand-recompute against the real code)

Conventions: `list_items_for_session` = `deleted_at IS NULL ORDER BY id ASC` (UUIDv7 = creation order). `render_structure_document(doc_kind, items, PerPricingKind)` = one line per item **in item order**, `title=item.text`, `qty=item.right`, `is_gap = is_pricing_kind(doc_kind)`, `item_id=item.id`, fresh line id. `is_pricing_kind`: `estimate|invoice` → true; `work_order|report|inspection|condition|move_out` → false. `record_correction` bumps `corrections_since_reflection += 1`.

**Shared fixture F1 (landscape, Processed).** Three `Authoritative` items, inserted in this order (so ids sort A1 < A2 < A3):

| id | kind | text | right | done |
|----|------|------|-------|------|
| A1 | `todo` | `Power edger` | `""` | false |
| A2 | `safety` | `loose railing` | `""` | false |
| A3 | `part` | `bark mulch` | `""` | false |

---

**WE-A — `update_item` changes text **and** kind on one item; does the re-tag change the document? (Trace it.)**
`update_item(sid, A1, text=Some("Mower"), kind=Some("part"), right=None)`.
- **Validation (D5):** session `Processed` ✓; `"part" ∈ VALID_ITEM_KINDS` ✓; `"Mower"` non-empty ✓.
- **Store write:** A1 becomes `(kind="part", text="Mower", right="")`; `done` stays `false`; `id`/`created_at`/`source` unchanged; `updated_at` bumped. Session `updated_at` **not** bumped (D6).
- **Correction (D4):** `text` changed `"Power edger" → "Mower"` ⇒ `record_correction` fires → `corrections_since_reflection: 0 → 1`. (The kind change contributes nothing.)
- **Rebuild `estimate`** (`is_pricing_kind=true`): 3 lines, order **[A1, A2, A3]**, every `is_gap=true`, every `qty=""`, amounts null (mock/placeholder pricing):

| line | title | qty | is_gap | item_id |
|------|-------|-----|--------|---------|
| L1 | `Mower` | `""` | true | A1 |
| L2 | `loose railing` | `""` | true | A2 |
| L3 | `bark mulch` | `""` | true | A3 |

- **The re-tag (`todo → part`) does NOT change the document structure.** Gap classification depends on **`doc_kind` (estimate → all gap), never `item.kind`**. The only place the new `kind` surfaces is the **pricing-pass prompt text**: `- [part] Mower (item_id: A1)` (was `- [todo] Power edger …`). Line count, order, gap flags, qty are identical to pre-edit; only **L1.title** changed `"Power edger" → "Mower"`. **The correction reached the document; the re-tag is invisible to the deterministic structure and visible only to the pricing LLM's context.** ✓

---

**WE-B — `right` edit propagates as `qty` (the propagation thesis).**
Continue from WE-A. `update_item(sid, A3, text=None, kind=None, right=Some("3 CU YD"))`.
- **Validation:** any `right` accepted; `text`/`kind` unchanged.
- **Correction:** `text` **not** changed ⇒ `record_correction` does **NOT** fire → `corrections_since_reflection` stays **1**.
- **Store:** A3 becomes `right="3 CU YD"`, `updated_at` bumped.
- **Rebuild `estimate`:** L3 now `qty="3 CU YD"` (render emits `qty=item.right`); L1/L2 `qty=""`. The quantity edit **reached the document's qty column** — the exact propagation that dies app-side today. ✓

---

**WE-C — `remove_item`: tombstone, `list_items`, rebuilt document, `list_open_todos` cascade; remove ≠ done.**
Fixture F2 (landscape, Processed), items in order (ids B1<B2<B3):

| id | kind | text | done |
|----|------|------|------|
| B1 | `todo` | `call supplier` | false |
| B2 | `todo` | `order sod` | false |
| B3 | `part` | `bark mulch` | false |

Pre-state: `list_open_todos()` = **[B1, B2]** (both `todo`, `done=0`, `deleted_at IS NULL`). `remove_item(sid, B2)` → `Store::delete_item(B2)`: sets `B2.deleted_at`, demotes B2's photos to session-level (none here). Then:
- `list_items_for_session(sid)` = **[B1, B3]** (B2 excluded).
- `list_open_todos()` = **[B1]** — the tombstoned todo **drops out of the morning glance** (cascade: `deleted_at IS NULL`). ✓
- **Rebuild `work_order`** (non-pricing → `is_gap=false`): **2 lines, order [B1, B3]**, titles `["call supplier","bark mulch"]`, both `is_gap=false`, `qty=""`; B2 **absent**. ✓
- `remove_item` fires **no** `record_correction`.
- **remove ≠ done (contrast, pinned):** had we called `set_item_done(B2, true)` instead — `list_items_for_session` = **[B1, B2, B3]** (B2 stays, `done=true`), rebuilt document = **3 lines** (B2's line present), `list_open_todos` = **[B1]** (B2 drops for `done=1`). So *done* keeps the line in the document; *remove* deletes it. Distinct semantics, both retained. ✓
- A second `remove_item(sid, B2)` → `EngineError::Item` (store `NotFound` on the tombstoned id).

---

**WE-D — `add_item` appends; position in the rebuilt document.**
Continue from WE-C (`list_items` = [B1, B3], B2 tombstoned). `add_item(sid, kind="safety", text="cracked walkway", right="")`.
- **Validation:** `"safety" ∈ VALID_ITEM_KINDS` ✓; text non-empty ✓; session `Processed` ✓.
- **Store:** mints B4 with a fresh UUIDv7 at `now()` → sorts **after** B1 and B3; `source = Manual`.
- `list_items_for_session(sid)` = **[B1, B3, B4]** — appended at the **end**.
- **Rebuild `work_order`:** **3 lines, order [B1, B3, B4]**; B4 is the **last** line, `title="cracked walkway"`, `is_gap=false`, `qty=""`, `item_id=B4`.
- `add_item` fires **no** `record_correction`. `Manual` source ⇒ B4 **survives** any future reprocess of this session. ✓

---

**WE-E — a single text edit snaps reflection cadence (exact counters).**
Fresh store. `reflection_signals()` = default (all 0). Simulate a mature, backed-off user: after prior reflections, `completed_reflections = 20`, `recent_churn = [0.0, 0.0, 0.0]` (flat), and one session has since completed → `sessions_since_reflection = 1`, `corrections_since_reflection = 0`.
- **Before the edit:** `required_interval(20, [0,0,0])` = `completed(20) ≥ warmup(5)` → `trailing_low = 3` → `1 << 3 = 8` (≤ max 16) → **8**. `should_reflect`: `sessions_since(1) == 0`? no; `corrections_since(0) > 0`? no; `sessions_since(1) ≥ interval(8)`? **no** → **`false`** (backed off, no reflection yet).
- **User makes ONE item-text edit** (`update_item` with a `text` change) → `record_correction` → `corrections_since_reflection: 0 → 1`.
- **After the edit:** `should_reflect`: `sessions_since(1) == 0`? no; `corrections_since(1) > 0`? **yes** → **`true`**. The single text edit **flipped `should_reflect` false → true**, snapping cadence to the next session end regardless of the 8-session backoff. ✓
- **Counter arithmetic pinned:** each **text-changing** `update_item` adds exactly **+1** to `corrections_since_reflection`; a right-only or kind-only `update_item`, an `add_item`, or a `remove_item` adds **+0**. Two text edits → `2`, but `should_reflect` is already `true` at `1` (the trigger is `> 0`, idempotent). The counter resets to `0` on the next completed reflection (`ReflectionSignals::record_reflection`).

---

## Staging (main stays shippable)

**ONE PR** (`pr/dam/plan-16-item-crud` → main). All-additive: one new column behind a migration (v6), one new domain field, one new store method, one shared const promotion, a one-line document-render change, a new FFI CRUD module + `EngineError` variant, a Swift protocol seam + demo parity. Gated by `cargo test --workspace` + `clippy --workspace --all-targets -- -D warnings` + iOS **demo** build + **the mandatory dam-manual real-core compile + bindings-drift check (Task 6)**. Rust tasks (1–4) are independently `cargo`-testable before the Swift task (5). A split buys nothing (the FFI growth is additive; existing Swift ignores the new methods until sac wires the edit UI) — one atomic PR keeps main from holding a half-wired edit contract.

---

## Tasks

### Task 1 — `right_text` column + `CapturedItem.right` + `Store::update_item` (murmur-core; D1-16/D2-16/D6-16)
- [ ] **RED — migration + domain (`store/migrations.rs`, `domain.rs`, `store/items.rs` tests):** (a) a fresh store has an `items.right_text` column defaulting `""` — a legacy raw insert without it reads back `right == ""` (extend the existing `existing_rows_backfill_as_authoritative` style pin); (b) `add_item` yields `right == ""`; (c) `CapturedItem` round-trips `right` through the DB read.
- [ ] **RED — `update_item` (`store/items.rs` tests):** (a) `update_item(id, Some("Mower"), Some("part"), None)` sets text+kind, **preserves** `done`/`id`/`created_at`/`source`, bumps `updated_at` (use `.with_clock`); (b) `update_item(id, None, None, Some("3 CU YD"))` sets only `right`; (c) an all-`None` update bumps `updated_at` and changes nothing else; (d) `update_item` on a tombstoned id → `CoreError::NotFound{entity:"item"}` (mirror `delete_item_is_a_tombstone`); (e) the returned `CapturedItem` reflects the new fields. **`update_item` is ungated — no status check here** (that's Task 3).
- [ ] **GREEN:** append migration **v6** to `MIGRATIONS`: `ALTER TABLE items ADD COLUMN right_text TEXT NOT NULL DEFAULT '';` (comment: quantity/unit string, Plan 16; `right_text` not `right` — `RIGHT` is a SQL keyword). Add `pub right: String` to `CapturedItem` (place after `text` for readability). Thread it through `ITEM_COLS` (add `right_text`), `item_from_row` (`row.get("right_text")` → `right`), and `insert_item` (INSERT `right_text` column + `item.right` param; `add_item`/`add_item_with_source` set `right: String::new()`). Add:
  ```rust
  /// Partial update of an item's editable fields (Plan 16). Mirrors
  /// set_item_done: tombstone-guarded, bumps updated_at, preserves
  /// id/created_at/source/done. A None field is left unchanged.
  pub fn update_item(&self, id: &str, text: Option<&str>, kind: Option<&str>, right: Option<&str>)
      -> Result<CapturedItem, CoreError>
  ```
  Implement as a single `UPDATE items SET text = COALESCE(?,text), kind = COALESCE(?,kind), right_text = COALESCE(?,right_text), updated_at = ? WHERE id = ? AND deleted_at IS NULL`; `changed == 0 → NotFound`; then `get_item(id)`. (COALESCE keeps `None` fields untouched in one statement, no read-modify-write.)
- [ ] **Gate:** `nix develop -c cargo test -p murmur-core` + `nix develop -c cargo clippy -p murmur-core --all-targets -- -D warnings`. All pre-existing item/domain/document tests stay green (proof the `right` field is behavior-preserving where `right == ""`).

### Task 2 — shared `VALID_ITEM_KINDS` + quantity propagates to the document (murmur-core; D2-16/D5-16)
- [ ] **RED — shared const (`pipeline/tools.rs` tests):** the agent `AddItemTool` still rejects an unknown kind and still accepts all six, now sourced from the shared const (existing tool tests must stay green after the refactor).
- [ ] **RED — qty propagation (`pipeline/document.rs` tests):** an item with `right == "3 CU YD"` renders a line with `qty == "3 CU YD"` under `PerPricingKind`; an item with `right == ""` renders `qty == ""` (the existing `all_gap_matches_the_offline_fallback_contract_except_id` and `per_pricing_kind_flags_gaps_only_for_pricing_kinds` must stay green — they use `right == ""` items).
- [ ] **GREEN:** add `pub const VALID_ITEM_KINDS: [&str; 6] = ["todo","decision","note","safety","part","price"];` to `crates/murmur-core/src/domain.rs` (exported via `lib.rs`); replace the private `VALID_KINDS` in `pipeline/tools.rs` with a reference to it (single source of truth — the edit seam and the agent tool can't fork; the Plan 15 SEED_MAX "don't fork the constant" discipline). In `render_structure_document`, change `"qty": ""` → `"qty": item.right` (update the N2 parity doc-comment: `qty = item.right`, which for the removed offline fallback's un-`right` items was `""`).
- [ ] **Gate:** `nix develop -c cargo test -p murmur-core` + `clippy`. Confirm no document test asserting `qty == ""` broke.

### Task 3 — FFI CRUD: `update_item` / `add_item` / `remove_item` (ffi; D1-16/D3-16/D4-16/D5-16)
- [ ] **RED** (new module `crates/ffi/src/items.rs`, reusing the `SpyStore` + literal-`Providers` harness from `photos.rs`/`vocabulary.rs`; add `mod items;` to `lib.rs`):
  - **Status gate (D3):** `update_item`/`add_item`/`remove_item` on a `Recording` session → `EngineError::Item`; on `AwaitingProcessing` → `EngineError::Item`; on a `Processed` session → `Ok`. (Build the `Processed` fixture via `begin_walk → append_transcript → finish()` like `document_build.rs::processed_landscape_session`.)
  - **Validation (D5):** empty/whitespace `text` → `Item`; unknown `kind` ("bogus") → `Item`; a tombstoned/missing `item_id` → `Item`; a valid update returns the fresh `BoardItem` with the new `text`/`kind`/`right`.
  - **`right` projection:** after `update_item(right="3 CU YD")`, the returned `BoardItem.right == "3 CU YD"` (proves `board_item` now reads `item.right`).
  - **Correction wiring (D4):** a **text**-changing `update_item` increments `corrections_since_reflection` by 1 (read via `store.reflection_signals()`); a **right-only** and a **kind-only** `update_item`, an `add_item`, and a `remove_item` each leave it **unchanged**. (WE-A/WE-B/WE-E counters.)
  - **`add_item` append + `remove_item` tombstone** at the FFI layer (returned `BoardItem`; a follow-up list reflects it — see Task 4 for the document-level asserts).
- [ ] **GREEN:** add `EngineError::Item(String)` to `crates/ffi/src/engine.rs` (doc: item CRUD validation/store errors — missing/tombstoned item, unknown kind, empty text, wrong session status, poisoned lock; never an api key). In `convert::board_item`, replace `right: String::new()` with `right: item.right.clone()`. In `items.rs`:
  ```rust
  #[uniffi::export]
  impl MurmurEngine {
      pub fn update_item(&self, session_id: String, item_id: String,
                         text: Option<String>, kind: Option<String>, right: Option<String>)
          -> Result<BoardItem, EngineError>
      pub fn add_item(&self, session_id: String, kind: String, text: String, right: String)
          -> Result<BoardItem, EngineError>
      pub fn remove_item(&self, session_id: String, item_id: String)
          -> Result<(), EngineError>
  }
  ```
  Each: lock the store once; read `get_session(session_id)` and reject `status != Processed` with `EngineError::Item` (D3, same-lock check, no await); validate (`text` trim-non-empty when `Some`; `kind ∈ murmur_core::VALID_ITEM_KINDS` when `Some`; `right` any). `update_item`: read the current row (for the text-changed comparison), call `store.update_item(...)`, and **if** `text` was `Some(new)` and `new != old.text`, call `store.record_correction()` (best-effort: a correction-log failure must not fail the edit — log and continue, or fold into the same `?` if you prefer strict). Return `board_item(&updated, &empty_counts)` (photo counts not needed for a single-item echo — pass an empty map, mirroring `convert`'s default-0). `add_item` → `store.add_item(...)` (Manual) then set `right` via `store.update_item(&item.id, None, None, Some(&right))` **in the same locked scope** (or add a `right` param to a private insert — but reusing `update_item` keeps one write path; note it bumps `updated_at` once more, harmless). `remove_item` → `store.delete_item(&item_id)`. Panic-free: poisoned lock → `EngineError::Item("store lock poisoned")`.
- [ ] **Gate:** `nix develop -c cargo test -p ffi` + `clippy -p ffi --all-targets -- -D warnings`.

### Task 4 — propagation pinned end-to-end (ffi; D2-16/D4-16, WE-A…WE-D)
- [ ] **RED** (`crates/ffi/src/items.rs` tests, driving the real `build_document`):
  - **WE-A:** `Processed` landscape session, items [A1 todo "Power edger", A2 safety "loose railing", A3 part "bark mulch"]; `update_item(A1, "Mower", "part", None)`; `build_document("work_order")` (non-pricing, no LLM) → 3 lines in order [A1,A2,A3], `lines[0].title == "Mower"`, all other titles unchanged. (Use `work_order` so the assert needs no scripted pricing response.)
  - **WE-B:** then `update_item(A3, None, None, Some("3 CU YD"))`; rebuild → `lines[2].qty == "3 CU YD"`, `lines[0].qty == "" == lines[1].qty`.
  - **WE-C:** F2 items [B1,B2,B3 todos/part]; assert `store.list_open_todos()` = [B1,B2]; `remove_item(B2)`; rebuild `work_order` → 2 lines [B1,B3]; `list_open_todos()` = [B1]; a second `remove_item(B2)` → `EngineError::Item`.
  - **WE-D:** continue; `add_item("safety","cracked walkway","")`; rebuild → 3 lines, `lines[2].title == "cracked walkway"` (appended last).
- [ ] **Gate:** `nix develop -c cargo test -p ffi` + `nix develop -c cargo test --workspace` (whole-workspace green; no `whisper` feature, no model).

### Task 5 — Swift seam: `updateItem`/`addItem`/`removeItem` + demo parity (apps/ios; `// sac:` edit UI deferred)
- [ ] **Protocol** (`WalkEngine.swift`): add `func updateItem(sessionId: String, itemId: String, text: String?, kind: String?, right: String?) throws -> BoardItem`, `func addItem(sessionId: String, kind: String, text: String, right: String) throws -> BoardItem`, `func removeItem(sessionId: String, itemId: String) throws`. **`// sac:` contract:** the edit UI (tap-to-edit inline field editors for text/qty, a kind re-file control, an "＋ add line" affordance, swipe/✕ to remove) is **yours** — this seam only guarantees the data path. **One-source-of-truth rule (keeper D-#7):** after any mutation returns, the notes/edit screen **re-reads from the engine** (rebuild the board/notes from the returned `BoardItem` or a fresh read) — **never patch local state**, the same rule that motivates the whole design.
- [ ] **`MurmurEngine`** (real, `#if canImport(MurmurCoreFFI)`): forward each to the generated `engine.updateItem(...)`/`addItem(...)`/`removeItem(...)`.
- [ ] **`DemoWalkEngine`** parity: an in-memory implementation mirroring the Rust semantics loosely — a per-session item list with `id/kind/text/right/done`; `update` partial-applies + validates `kind` against the same six-kind allowlist (a `// sac:` copy of `VALID_ITEM_KINDS`, drift-noted) + rejects empty text + only mutates a `.processed` demo session; `add` appends; `remove` drops. Enough to exercise the edit UI with no backend. Keep existing demo board fixtures unchanged.
- [ ] **Gate:** iOS **demo** build (xcodebuild OUTSIDE nix): `xcodebuild -project SitewalkGallery.xcodeproj -scheme SitewalkGallery -destination 'platform=iOS Simulator,name=iPhone 17' build`.

### Task 6 — real-core compile + bindings drift (dam-manual) + merge  **[MANDATORY GATE]**
- [ ] dam runs `cd apps/ios && ./build-ffi.sh && ./generate.sh && xcodebuild -project SitewalkGallery.xcodeproj -scheme SitewalkGallery -destination 'platform=iOS Simulator,name=iPhone 17' build` — confirm the real-core archive compiles against the new `update_item`/`add_item`/`remove_item` + `EngineError::Item` + `BoardItem.right` bindings (CI cannot do this — Plan 13 lesson).
- [ ] Bindings-drift check: regenerate the Swift bindings from `crates/ffi`; confirm the three new methods resolve, `EngineError.item` is present, and no unrelated record drifted.
- [ ] **Merge the PR** — TestFlight internal lane publishes the item-edit seam on real-engine. (sac's edit-UI PR follows independently.)

---

## Gates (every task)
- `nix develop -c cargo test --workspace` — exit code 0 (never grep counts; run under the Nix shell).
- `nix develop -c cargo clippy --workspace --all-targets -- -D warnings`.
- **All pre-existing item / document / reflection tests stay green** (Task 1's `right` field and Task 2's `qty=item.right` must not change any behavior where `right == ""`; the `VALID_ITEM_KINDS` promotion must not change the agent tool's validation).
- iOS **demo** build (CI-gated) — **outside** the Nix shell.
- **MANDATORY:** real-core compile + bindings-drift (dam-manual, Task 6) — before merge.

## Acceptance criteria
1. `Store::update_item(id, text?, kind?, right?)` partial-updates the item, preserves `done`/`id`/`created_at`/`source`, bumps `updated_at`, and returns `NotFound` on a tombstoned id — mirroring `set_item_done` (Task 1, WE-A/WE-B).
2. `items.right_text` (migration v6) backs a new `CapturedItem.right`; `board_item` projects it and `render_structure_document` emits `qty = item.right`, so a **quantity edit reaches every rebuilt document** — behavior-preserving where `right == ""` (Task 1/2, WE-B).
3. `MurmurEngine::update_item`/`add_item`/`remove_item` are engine-keyed and **`Processed`-gated** (`build_document`'s rule); `Recording`/`AwaitingProcessing`/`Failed` → `EngineError::Item` (Task 3, D3).
4. `kind` is validated against the single shared `VALID_ITEM_KINDS` (unknown rejected, R6); empty `text` rejected; `right` free-form; the agent `AddItemTool` and the edit seam share **one** const (Task 2/3, D5).
5. A **text**-changing `update_item` fires exactly one `record_correction` (snaps cadence, WE-E); kind-only/right-only edits and `add`/`remove` fire none; **no vocab auto-add or suggestion in v1** (Task 3/4, D4).
6. `remove_item` tombstones (photos demoted to session-level, Plan 11 D3), drops the item from `list_items_for_session` **and** `list_open_todos` (cascade), and is **distinct from `done`** (Task 4, WE-C); `add_item` **appends** (last document line, `Manual` source, survives reprocess) (Task 4, WE-D).
7. Every `build_document` after an edit reflects it (title/qty/removal/addition) — the propagation thesis (Task 4); the Swift seam exists on both engines with a `// sac:` edit-UI contract and the re-read-from-engine rule; the real-core archive builds (Task 6).

## Non-goals (explicit)
- The **edit UI** — tap-to-edit interaction, inline editors, add/remove affordances, kind re-file control (sac's follow-up; this plan supplies the data path + demo parity).
- The **vocab suggest-card** — v1 records the correction signal (`record_correction`) only; auto-suggesting the corrected term into `vocabulary` is a fast-follow (keeper D-#3).
- **Pricing / a per-item price-book in core** — items stay price-free; amounts remain a `build_document` concern, app-editable as today. Arrives with the `DocumentSchema` seam (#207 §7.2) as v2 (keeper D-#2).
- **Narrative bucket editing** — the Scope/Constraints/Conditions buckets are a derived `write_notes` artifact; editing them means versioning the `NotesPayload` artifact, a different seam (keeper D-#5).
- **Mid-walk editing** — `Recording`/`AwaitingProcessing`/`Failed` mutations are forbidden (D3); edit-at-review (post-`finish()`, `Processed`) is the whole v1 surface. Allowing mid-walk edits (racing re-extraction's new ids) is a new design round (keeper D-#6).
- **`right` format validation / unit parsing** — quantity is free-form display text; coercing it would fabricate (R6).
- A **session `updated_at` bump** on an item edit (D6 — item-row sync events only).

## Risks & rollback
- **Risk — `right` column / `qty` render changes an existing document.** Mitigation: `right` defaults `""`, so `qty` stays `""` for every un-edited item — Task 2 pins the existing `qty == ""` document tests green. Rollback: revert the `render_structure_document` one-liner (documents lose quantity propagation; the column is inert).
- **Risk — the `Processed` gate blocks a legitimate edit surface (e.g. a Failed session the user wants to salvage).** Bounded/deliberate: matches `build_document`'s gate, so "editable" ≡ "buildable". A salvage surface is a future design round (D3). Rollback: none needed; loosening the gate is a one-line status-set change.
- **Risk — `record_correction` fires on a non-text edit (false cadence snap) or fails to fire on a real one.** Mitigation: fired **only** when `text` is `Some(new) && new != old.text` — WE-A (fires), WE-B (right-only: does not), WE-E (counter arithmetic) pin it. A `record_correction` write failure is best-effort (must not fail the edit). Rollback: drop the `record_correction` call (edits still work; cadence just doesn't snap on corrections).
- **Risk — `kind` allowlist forks between the agent tool and the edit seam.** Mitigation: one `pub const VALID_ITEM_KINDS` in `domain.rs`, referenced by both; the Swift demo copy is drift-noted (`// sac: keep in sync with VALID_ITEM_KINDS`). Rollback: the const promotion is behavior-preserving; revert to the private const if needed.
- **Risk — a `right`-reserved-word SQL error.** Mitigation: the DB column is `right_text`, never the bare `right` keyword. Pinned by Task 1's migration test (a fresh store opens and reads the column).
- **Rollback of the whole plan:** delete `crates/ffi/src/items.rs` + `EngineError::Item` + the `board_item` right-projection (ffi), the `update_item` store method + `CapturedItem.right` + the `render_structure_document` qty line + the `VALID_ITEM_KINDS` promotion (murmur-core), and the Swift protocol methods + demo parity. The migration (v6) is inert if unused (an added column with a default); a full down-migration is unnecessary (single-writer, no data depends on `right_text` if the read path is reverted). All additive → clean revert; the pre-existing item store + document builder + reflection paths are untouched.

## Open questions
1. **Editing a `done` item (dam).** Allowed today (D4 — `done` is orthogonal to text/kind/right, preserved across `update_item`). Should a `done` item be edit-locked in the UI to avoid "why did my completed line change"? — **recommend: allow at the core seam; let sac decide the UI affordance.**
2. **`add_item` during `Processed` re-numbers nothing but grows the estimate — should a manually-added line be visually flagged (`source == Manual`) in the document?** The `source` is on the item but **not** projected to `BoardItem`/`DocLine` today. — **recommend: out of scope for v1; add a `source` projection only if the UI needs the badge (a one-field additive change).**
3. **Correction → vocab suggestion (dam + sac, the fast-follow).** v1 records the signal; the suggest-card diffs old→new text and offers the corrected term as a `vocabulary` suggestion (not an auto-add, keeper D-#3). Needs a diff heuristic (which token changed?) and a card surface — its own small plan. — **recommend: Plan 17 candidate.**
4. **Batch edits (dam).** The UI may commit several field edits at once; v1 exposes one `update_item` per call (each its own `updated_at`/correction). Is a batch `update_items([...])` worth it before sync? — **recommend: per-item is fine at review scale; revisit if a bulk-edit surface appears.**
