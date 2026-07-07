# Murmur Rust Core — Plan 12: document-row item identity

> **For agentic workers:** REQUIRED SUB-SKILL: use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. The Rust tasks (1–2) are **hermetic**: in-memory `Store`, `MockProvider`, `with_providers`/`SessionProcessor` — **no model, no `whisper` feature, no network, no camera, no filesystem-of-real-photos**. `cargo test --workspace` must NEVER require the `whisper` feature or a model file (the load-bearing CI invariant). The Swift task (3) is **not CI-gated** (real-core-only, needs the gitignored `MurmurCoreFFI` xcframework) and its **grouping/visual design is explicitly sac's** — `// sac:` markers throughout. Run `cargo`/`xcodegen` **inside** the Nix dev shell; run `xcodebuild` **outside** it (Nix linker env breaks Xcode `ld`). Never read `.env` or `project.local.yml`.

> **Plan review (2026-07-07) — APPROVE WITH CONDITIONS (applied).** Reviewed against real code: dangle-safety recomputed exactly (the validation set == the finish-swap's `run_item_ids`, so a validated row id survives the swap by construction); all three worked examples (A echo/validate matrix, B dangle-across-swap, C join) recompute clean and hold; the **no-migration** claim confirmed (the document lives in `artifacts.body` as JSON parsed by a hand-rolled tolerant field-by-field parser, `convert.rs:36–68` — nothing schema-bound); evals unaffected (only live-prompt pins exist, no transcript→doc score moves). Two conditions applied: (C1) validation threads the **`created_ids` Arc** the finish-swap already uses into `run_build_document` — NOT a fresh store query (the query is equivalent only by the accident that no tool deletes authoritative items between extraction and build today; threading the Arc ties validation to the exact set the sweep uses); (C2) Task 1 Step 6 captures the authoritative item's **real id** in setup and hardcodes it into the mocked `build_document` response, pinning validate-then-sweep end-to-end.

**Goal.** Give every generated **document row a durable, optional core item id**, so the review document can group photos per item (Plan 11 photos already carry an optional `item_id`) and — later — a tapped doc row can jump to its item. Today document lines cross the FFI as flat text (`DocLine`) with a throwaway per-line UUID and **no item identity**: the `build_document` phase re-derives lines straight from the transcript and never even sees the extracted items (`run_build_document`, `pipeline/mod.rs:287–361`). This was queued as sac's "Not in this PR" item (`docs/superpowers/plans/2026-07-06-sac-photo-vocab-design-pass.md:47`, *"per-item photo grouping … needs core item ids on `DocRowFixture` rows — seam question for dam"*) and named in Plan 11 as the missing *live↔authoritative identity* (`Plan 11 §Non-goals`: "the model re-extracts fresh UUIDs").

**What lands:**
1. **murmur-core (pipeline)** — the `build_document` tool gains an **optional `item_id` per line**; the forced `build_document` call is **fed this run's authoritative items (id + kind + text)** so the model has ids to echo; and the tool **validates every echoed id against the run's authoritative item-id set** at write time — a hallucinated / missing / cross-session / duplicate id **degrades that row to `item_id = None`, never failing the build** (R7: the document always lands). By construction the validation set == the set finish keeps, so **a validated row id can never dangle on a tombstoned item** (the Plan 11 D3 invariant, earned here for free).
2. **murmur-core (fallback)** — the offline `partial_document_from_items` path already builds rows *directly from items*, so it carries `item_id` trivially (it already puts the item id in `DocLine.id`).
3. **ffi** — `DocLine` gains an additive optional `item_id`; `convert::document_payload` reads it from the artifact JSON; `partial_document_from_items` stamps it. UniFFI record grows one optional field (additive), bindings regen.
4. **apps/ios** — `DocRowFixture` gains `itemId: String?`; `MurmurEngine` maps `DocLine.item_id → DocRowFixture.itemId`; `DemoWalkEngine` parity; a **functional-plain client-side join** in `ReviewView` grouping `model.photos` under the row whose `itemId` matches, session-level leftovers at the end — every visual/gesture decision behind `// sac:`.

**What this plan is NOT (see Non-goals for the full list).** No new SQLite migration (the document artifact body is additive JSON — the `artifacts` table is untouched). No tap-to-navigate UX (sac's later). No photos-in-PDF, no vision analysis. No change to *which* lines the model builds or to document prose quality — `item_id` is metadata attached to lines the model already builds. No re-linking of demoted photos.

---

## Hard dependencies (all DONE, on `main`)

- **Plan 07** (`crates/ffi`, `crates/murmur-core`): the structured document is an `Artifact` with `kind="document"` and a **JSON body** (`store/documents.rs`, `mint_document_number_and_add_artifact`) — *no domain type, no migration* for the document itself. `DocLine`/`DocumentPayload` uniffi records + `convert::document_payload` parse the body **defensively, field-by-field** (`convert.rs:36–68`, every field `.and_then(...).unwrap_or_default()`), and the offline `partial_document_from_items` fallback (`convert.rs:78–114`). The forced-`build_document` phase-B pattern (`pipeline/mod.rs:287–361`) and `BuildDocumentTool` (`pipeline/tools.rs:246–393`).
- **Plan 06a** (`items.source`): `ItemSource { Live, Authoritative, Manual }`; the extraction pass writes **authoritative** items via `AddItemTool::authoritative`, recording each new id into a `created_ids` sink (`tools.rs:88–100`, `pipeline/mod.rs:172,190–194`); the finish swap tombstones `source IN ('live','authoritative')` **not in `run_item_ids`** (== `created_ids`) — `sessions.rs` `finish_session_processed`. Phase 0 clears prior authoritative outputs before extraction (`pipeline/mod.rs:126`), so **at build time the only `Authoritative` items in the session are this run's.**
- **Plan 11** (`photos`): `PhotoRef.item_id: Option<String>` already crosses the FFI (`ffi/src/photos.rs`); `Store::list_photos_for_session` + `count_live_photos_by_item_for_session`; the **demote-on-swap** rule guarantees a live photo never references a tombstoned item. The iOS review gallery (`ReviewView.photoGallery`, `AppModel+Photos.swift`) lists `model.photos` flat, with a `link` glyph already shown when `photo.itemId != nil` (`ReviewView.swift:229`).

**Verified API facts (checked against source, not guessed):**
- **No document domain type / no migration.** The document lives entirely in `artifacts.body` as JSON; `document_payload` tolerates any missing field (`convert.rs:45–56`). Adding `"item_id"` to each line object and a new `DocLine.item_id` field is **purely additive** — `MIGRATIONS.len()` is unchanged, no `user_version` bump.
- **`build_document` does NOT see items today.** `run_build_document` sends `system: build_document_prompt(...)` + one user message `"Build the document…\n\n{assembled_transcript}"` (`pipeline/mod.rs:305–316`) — transcript only. The model re-derives lines; `BuildDocumentTool::execute` mints a **fresh `new_id()` per line** into `DocLine.id` (`tools.rs:357`) with no relation to any item. **This is the design problem.**
- **The run's authoritative item set is the `created_ids` Arc.** `created_ids` (the `Arc<Mutex<Vec<String>>>` sink populated by `AddItemTool::authoritative`) is fully populated by the time `run_build_document` runs, and this **same vector** is passed to `finish_session_processed(..., &ids)` as `run_item_ids` (`pipeline/mod.rs:190–194`). Validation threads this Arc (C1) — **the validation set and the survives-the-swap set are literally the same object**, invariant by construction. (A store re-query filtered to `source == Authoritative` would return the same ids *today*, but only because no tool deletes authoritative items between extraction and build; that is an accident of the current tool set, not an invariant — do not rely on it.)
- `CapturedItem` fields: `id`, `kind`, `text`, `source` (`domain.rs:155–160`). `list_items_for_session` returns live (non-tombstoned) items (`items.rs:121`).
- Swift: `DocRowFixture` (`Fixtures.swift:47–57`) has an auto `id = UUID()` and no item link; `MurmurEngine.row` (`MurmurEngine.swift:360–371`) ignores `line.id`; `PhotoModel.itemId: String?` exists (`WalkEngine.swift:37`).

**Spec basis:** Rev 2 §1 (the document is a **seam** — structured data, display-copy-free); R6 (under-extraction bias — echoing ids must not turn the document into an item-checklist); R7 (real outcomes / never lose the artifact — a bad id degrades, never fails); R9 (spend meter — the schema/prompt change is a few tokens, budgeted). Plan 11 D3 (a reference to an item must never dangle on a tombstoned item) is the invariant this plan must also honor for rows.

---

## Architecture — decisions, justified (reviewers read these first)

### D1. Row→item identity is **model-echoed, then validated** (argued, then chosen)

The document is authored by the LLM in the forced `build_document` call. Three ways a row could learn its item id:

| approach | verdict |
|---|---|
| **(a) Model echoes `item_id` per line; core validates against the run's item set** | **CHOSEN** |
| (b) Post-hoc fuzzy-match row `title` → item `text` after the fact | rejected — brittle, silent mis-joins, no ground truth |
| (c) Skip the LLM path; only `partial_document` (offline) carries ids | rejected — the LLM path is the *normal* path; offline is the fallback |

The build must **give the model ids to echo**: today it sees only the transcript. So Task 1 feeds the run's **authoritative** items (`id`, `kind`, `text`) into the `build_document` user message as a reference block, and the prompt says *copy the matching `item_id` onto a line you build from that item; it is a reference, not a checklist — do not invent a line per item, do not drop lines that have no item.* This keeps R6 intact: the id is metadata on lines the model already builds, not a pressure to build more.

**Validation is the load-bearing safety.** A model can hallucinate an id, echo one from another session, duplicate one, or omit it. `BuildDocumentTool` is handed the run's valid id set (a `HashSet<String>` built from the authoritative items) and, per line, applies **degrade-to-None** rules in order:

1. no `item_id` present → `None` (normal: totals, synthesized/rollup lines, or the model chose not to echo).
2. `item_id` present but **not in the valid set** (hallucinated / cross-session / a live-or-manual id) → `None`.
3. `item_id` in the valid set but **already claimed by an earlier line** → `None` (first-wins dedup — see D2).
4. otherwise → `Some(id)`, and mark it claimed.

**No branch fails the build** — the document always lands (R7). A stored row therefore carries either a valid, surviving item id or `None`; never a garbage or dangling id.

### D2. The mapping is **injective** (each item attaches to at most one row) — first-wins dedup

Photos are the driver: the review screen groups photos *per item*. If two rows claimed the same `item_id`, a photo for that item would render under **both** rows (duplicated, confusing). So the row→item map is injective: the first row to claim an id keeps it; a later row echoing the same id degrades to `None` (rule 3). A photo for item `A` then appears under **exactly one** row. (A single item that legitimately spawned two lines — "parts" + "labor" — loses the link on the second line only; its photos still group under the first, which is the right home. Losing a *link* is lossless for prose and lossless for photos.)

### D3. The dangle invariant is **earned by construction** (Plan 11 D3, for rows)

Plan 11's hard-won rule: *a reference to an item must never point at a tombstoned item.* For photos that needed an explicit demotion at every item-sweep site. For **doc rows we get it for free**, because:

- The valid set fed to `BuildDocumentTool` = the run's **authoritative** item ids = the `created_ids` vector.
- That **same vector** is passed to `finish_session_processed(..., run_item_ids = created_ids)` immediately after (`pipeline/mod.rs:194`), and the finish swap tombstones only items **not** in `run_item_ids`.
- Therefore every id that survives validation is in `run_item_ids` and **survives the swap**. A validated `DocLine.item_id` can never reference a tombstoned item.

Ordering pins this: `build_document` (validate against `created_ids`) runs **before** `finish_session_processed` (sweep by the same `created_ids`) — both inside the same `process()` call, `created_ids` frozen between them (the extraction agent pass that populates it has already returned). No live-item id can leak into a row, because live items are **not** in the authoritative set and are **not** fed to the model.

### D4. **No migration; no schema version.** The artifact body is additive JSON

The document is `artifacts.body` = a JSON object parsed defensively field-by-field (`convert.rs`). Adding `"item_id"` to each line object and `DocLine.item_id: Option<String>`:

- **needs no SQLite migration** — the `artifacts` table is unchanged; `MIGRATIONS.len()` and `user_version` are untouched.
- **needs no schema version field.** Parsing is already tolerant: a body written before Plan 12 has no `"item_id"` on its lines, so `line.get("item_id")` is `None` → the row renders exactly as today (no grouping). A body written after carries ids. Old and new coexist with zero branching. Adding a `doc_schema: 2` marker would be pure churn against a parser that never needed a version — **rejected**; the defensive-parse posture (already the house pattern) *is* the compat mechanism.

Old **stored** documents that are never reprocessed keep `item_id`-free bodies and render unchanged; a reprocess regenerates the body with fresh authoritative ids and fresh row ids (consistent — a reprocess already re-extracts, Plan 06a).

### D5. The review-time **join contract** (rows reference items; photos reference items)

Both `DocLine.item_id` and `PhotoRef.item_id` are `Option<String>`. The shell joins **client-side** at review:

- For each doc row with `itemId == Some(X)`: its photo group = `{ p ∈ photos : p.itemId == X }`.
- **Session-level group** (rendered after the rows) = photos whose `itemId` is `None` **or** whose `itemId` matches **no** row's `itemId`. This is the catch-all: demoted photos (item swept → `item_id = NULL`, Plan 11 D3), photos on manual items (manual items aren't fed to `build_document`, so no row echoes them), and photos attached to items the model didn't turn into a row.

Injectivity (D2) makes each photo land in exactly one place. Worked example C pins a 3-row / 4-photo case with one demoted photo.

### D6. FFI surface — one additive optional field, Swift parity, `// sac:` join hook

`DocLine` gains `item_id: Option<String>` (additive UniFFI record field — old callers ignore it, new bindings expose it). `convert::document_payload` reads `line.get("item_id")`; `partial_document_from_items` stamps `Some(item.id)`. Swift `DocRowFixture` gains `itemId: String?`; `MurmurEngine.row` maps it; `DemoWalkEngine` sets it (nil is acceptable parity — the demo has no real item ids, but the field must exist so the grouping code compiles and the demo gallery still renders). The client-side join in `ReviewView` sits behind a `// sac:` marker — **grouping layout, per-row photo strips, the session-level section header, empty states are sac's.**

---

## File Structure

```
crates/
  murmur-core/src/pipeline/
    tools.rs      # MODIFY: build_document line schema gains optional item_id;
                  #   BuildDocumentTool::new takes valid_item_ids; execute() validates
                  #   (degrade-to-None + first-wins dedup) and stamps line item_id
    prompts.rs    # MODIFY: build_document_prompt echo instruction + format_document_items()
    mod.rs        # MODIFY: run_build_document loads this-run authoritative items,
                  #   formats the reference block into the user message, and passes
                  #   the valid id set into BuildDocumentTool (threaded through run_llm_phases)
  ffi/src/
    document.rs   # MODIFY: DocLine gains item_id: Option<String>
    convert.rs    # MODIFY: document_payload reads "item_id"; partial_document stamps Some(item.id)
apps/ios/Sources/
  Fixtures/Fixtures.swift        # MODIFY: DocRowFixture gains itemId: String?
  Engine/MurmurEngine.swift      # MODIFY: row(_:) maps line.itemId → DocRowFixture.itemId
  Engine/DemoWalkEngine.swift    # MODIFY: demo document rows set itemId (parity)
  Flow/ReviewView.swift          # MODIFY: client-side join (photos grouped per row) — // sac:
docs/
  superpowers/plans/2026-07-07-rust-core-12-docrow-item-ids.md   # THIS FILE
meta/ROADMAP.md                  # MODIFY (Task 4): note doc-row item ids landed
```

---

## Part A — Core: echo-and-validate item ids on document rows

### Task 1: `build_document` echoes + validates `item_id`; the forced call is fed the run's items

**Files:** modify `pipeline/tools.rs`, `pipeline/prompts.rs`, `pipeline/mod.rs`.

- [ ] **Step 1 — failing tests** (`pipeline/tools.rs` `mod tests`, extending the existing `BuildDocumentTool` tests; use `shared_store_with_session`). The valid-set is passed explicitly so these are hermetic and decoupled from the pipeline.

```rust
// helper: BuildDocumentTool::new now takes the run's valid authoritative id set.
// Signature: new(store, session_id, doc_kind, existing_doc_number, valid_item_ids: Vec<String>)

#[tokio::test]
async fn build_document_echoes_and_validates_item_ids() {
    let (store, sid) = shared_store_with_session();
    // Two authoritative items exist this run: A1, A2 (the valid set).
    let a1 = store.lock().unwrap().add_item(&sid, "todo", "mulch").unwrap().id;
    let a2 = store.lock().unwrap().add_item(&sid, "todo", "edging").unwrap().id;
    let tool = super::BuildDocumentTool::new(
        store.clone(), &sid, "estimate", Some(7), vec![a1.clone(), a2.clone()],
    );
    tool.execute(serde_json::json!({
        "total_kind":"sum","total_label_key":"total",
        "lines":[
            {"title":"Mulch",   "amount_cents":28500, "item_id": a1},           // valid  -> kept
            {"title":"Edging",  "amount_cents":31000, "item_id": a2},           // valid  -> kept
            {"title":"Extra",   "amount_cents":31000, "item_id": a2},           // dup a2 -> None (first-wins)
            {"title":"Ghost",   "amount_cents":100,   "item_id": "not-a-real-id"}, // bad -> None
            {"title":"Subtotal","amount_cents":90600}                          // omitted -> None
        ]
    })).await.unwrap();
    let store = store.lock().unwrap();
    let v: serde_json::Value =
        serde_json::from_str(&store.latest_document_artifact(&sid).unwrap().unwrap().body).unwrap();
    assert_eq!(v["lines"][0]["item_id"], a1, "row 0 keeps the valid id it echoed");
    assert_eq!(v["lines"][1]["item_id"], a2, "row 1 keeps the valid id it echoed");
    assert_eq!(v["lines"][2]["item_id"], serde_json::Value::Null, "duplicate a2 degrades (first-wins)");
    assert_eq!(v["lines"][3]["item_id"], serde_json::Value::Null, "hallucinated id degrades");
    assert_eq!(v["lines"][4]["item_id"], serde_json::Value::Null, "omitted id stays null");
    // Every stored row id is either in the valid set or null — never garbage.
    for line in v["lines"].as_array().unwrap() {
        if let Some(id) = line["item_id"].as_str() {
            assert!([a1.as_str(), a2.as_str()].contains(&id));
        }
    }
    // The per-line display id (line.id) is still a fresh new_id, distinct from item_id.
    assert_ne!(v["lines"][0]["id"], v["lines"][0]["item_id"]);
}

#[tokio::test]
async fn build_document_with_empty_valid_set_nulls_all_item_ids() {
    // Belt-and-suspenders: if the run extracted nothing authoritative, every
    // echoed id is invalid and every row degrades to None — build still lands.
    let (store, sid) = shared_store_with_session();
    let tool = super::BuildDocumentTool::new(store.clone(), &sid, "report", None, vec![]);
    tool.execute(serde_json::json!({
        "total_kind":"sum","total_label_key":"total",
        "lines":[{"title":"X","item_id":"anything"}]
    })).await.unwrap();
    let store = store.lock().unwrap();
    let v: serde_json::Value =
        serde_json::from_str(&store.latest_document_artifact(&sid).unwrap().unwrap().body).unwrap();
    assert_eq!(v["lines"][0]["item_id"], serde_json::Value::Null);
}
```

- [ ] **Step 2 — line schema** (`tools.rs`, `BuildDocumentTool::input_schema_json`): add `"item_id": { "type": "string", "description": "the exact id of the captured item this line was built from, copied from the item list; omit for total/rollup lines or lines with no item" }` to the `lines[].properties`. **Not** added to `required`.

- [ ] **Step 3 — constructor + validation** (`tools.rs`):
  - `BuildDocumentTool::new(store, session_id, doc_kind, existing_doc_number, valid_item_ids: Vec<String>)`; store the set as a `HashSet<String>`.
  - In `execute`, per line: read `line.get("item_id").and_then(|v| v.as_str())`; apply the D1 degrade-to-None rules (present-and-in-set-and-unclaimed → keep + insert into a `claimed: HashSet` local; else `None`). Stamp the result as `"item_id"` in the pushed line JSON (alongside the existing fresh `"id": new_id()`). Never return an error for a bad id.

- [ ] **Step 4 — feed the model the items** (`prompts.rs`):
  - Add `pub(crate) fn format_document_items(items: &[CapturedItem]) -> String` — one line per authoritative item: `format!("- [{}] {} (item_id: {})", i.kind, i.text, i.id)`; empty string for no items (the assembler elides empty sections / the caller omits the block).
  - Extend `build_document_prompt` with an instruction: *"You will be given the items already captured for this session, each with an `item_id`. When a document line corresponds to one of those items, copy its `item_id` exactly onto that line. The item list is a REFERENCE, not a checklist — do not invent a line for every item, and do not drop a line just because it has no item. Total or rollup lines have no `item_id`."* Keep it short (R9).

- [ ] **Step 5 — wire the pipeline, threading the `created_ids` Arc (C1)** (`pipeline/mod.rs`):
  - **Thread `created_ids` into `run_build_document`.** `run_llm_phases` already owns the `Arc<Mutex<Vec<String>>>` (`mod.rs:216`); pass it (a clone of the Arc, or a snapshot `Vec<String>` taken at the top of `run_build_document`) as the `run_build_document` argument that becomes the tool's `valid_item_ids`. **Do NOT re-query the store for the valid set** — the validation set MUST be the same object the finish-swap uses (`finish_session_processed(..., &ids)` at `mod.rs:194`), so it stays invariant even if a future tool were to delete authoritative items between extraction and build. This is the whole point of C1: the dangle-safety is by construction, not by an accident of the current tool set.
  - **The reference block's *display text* (kind + text) is looked up for exactly those ids.** The `created_ids` Arc carries ids only, but the prompt block needs `kind`/`text`. Build the block from the store *filtered to the `created_ids` set* — the set membership still comes from the Arc, the store is consulted only to fetch display strings for those exact ids: `let ids: HashSet<String> = created_ids.lock()?.iter().cloned().collect(); let items: Vec<CapturedItem> = self.store.lock()?.list_items_for_session(session_id)?.into_iter().filter(|i| ids.contains(&i.id)).collect();`. (Block content is display-only and does not affect the dangle invariant — only `valid_item_ids = ids` does.)
  - Append the reference block to the user message: `format!("Build the document for this session.\n\n{assembled_transcript}\n\nItems already captured (copy the matching item_id onto each line built from an item):\n{}", prompts::format_document_items(&items))` — omit the trailing block when `items` is empty.
  - Pass `valid_item_ids = ids` (from the Arc) into `BuildDocumentTool::new(...)` at `mod.rs:332`.
  - **The D3 identity is now literal, not incidental:** the `Vec`/set passed here and the `&ids` swept at `finish_session_processed` (`mod.rs:194`) are the same `created_ids` object; Step 6 pins that a validated row id survives the swap end-to-end.

- [ ] **Step 6 — pipeline e2e test, pinning the REAL id (C2)** (`pipeline/mod.rs` `mod tests`). The positive *"a valid id is kept"* case is already pinned at the tool level in Step 1 with a hardcoded real id (explicit `valid_item_ids`). This pipeline test pins the **wiring + the validate-then-sweep invariant end-to-end** with the run's real minted id. Because a pre-scripted `MockProvider` response cannot contain an id minted mid-`process()`, capture the real id by **read-back after the run**, not by pre-hardcoding:
  - **Setup/script:** extraction phase scripts `add_item(todo,"order lumber")` (mints the run's one authoritative item into the store **and** the `created_ids` Arc), then `summary_response(...)`, then a `document_response` whose lines are `[{"title":"Lumber","item_id":"__REPLACED_BELOW__"}, {"title":"Ghost","item_id":"bogus-id"}, {"title":"Subtotal"}]`.
  - **Feed pinned (C2, positive):** the real id the run created can't be known before scripting, so pin that it was **fed** — after `process()`, read `provider.requests()` and assert the `build_document` request's user message **contains the real minted id** (`list_items_for_session(&sid)`'s surviving authoritative item id) in its "Items already captured" block. This proves `created_ids` → the reference block wiring with the actual id.
  - **Degrade pinned:** read the stored document body; assert the `"bogus-id"` line and the no-`item_id` line both stored `item_id == null` (validation degrades a hallucinated / omitted id without failing the build).
  - **Survives-swap invariant pinned (D3):** assert that **every** stored row with a non-null `item_id` is present in `list_items_for_session(&sid)` **after** `process()` (post-swap) — i.e. no row references a tombstoned item. Since the only ids that can survive validation are in `created_ids == run_item_ids`, and those are exactly what the swap keeps, this holds by construction.
  - (To *positively* assert a real id is **kept** on a row through the full pipeline — not just fed — a second focused test can rebind: run `process()` once so the id exists and is stable, capture it, then `clear` + re-`process()` is overkill; the tool-level Step 1 test already owns the positive-kept assertion with a hardcoded id. Keep this pipeline test to feed+degrade+survives-swap.) See Worked Example B for the arithmetic.

- [ ] **Step 7 — verify:** `nix develop -c cargo test -p murmur-core` green (tools + pipeline). No `whisper` feature, no network.

- [ ] **Step 8 — commit:** `feat(core): build_document echoes + validates item_id per row (degrade-to-None, first-wins)`

---

### Task 2: FFI `DocLine.item_id` + convert + offline fallback

**Files:** modify `crates/ffi/src/document.rs`, `crates/ffi/src/convert.rs`.

- [ ] **Step 1 — failing tests** (`convert.rs` `mod tests`, extending the existing document tests):

```rust
#[test]
fn document_line_carries_item_id_when_present_and_none_when_absent() {
    let store = Store::open_in_memory("device-a").unwrap();
    let session = store.start_session(None).unwrap();
    let body = serde_json::json!({
        "doc_kind":"estimate","doc_number":47,"job_date_unix":1000,
        "total_kind":"sum","total_label_key":"total","static_total_cents":null,
        "lines":[
            {"id":"l1","title":"Mulch","detail":"","qty":"","amount_cents":28500,"section":null,"is_gap":false,"item_id":"item-A1"},
            {"id":"l2","title":"Subtotal","detail":"","qty":"","amount_cents":90600,"section":null,"is_gap":false}
        ],
        "queued":false
    });
    let art = store.add_artifact(&session.id, "document", "estimate #47", &body.to_string()).unwrap();
    let payload = document_payload(&art).unwrap();
    assert_eq!(payload.lines[0].item_id.as_deref(), Some("item-A1"));
    assert_eq!(payload.lines[1].item_id, None, "a line with no item_id parses to None");
}

#[test]
fn pre_plan12_document_body_parses_all_item_ids_as_none() {
    // A body written before Plan 12 (no item_id on any line) renders unchanged.
    let store = Store::open_in_memory("device-a").unwrap();
    let session = store.start_session(None).unwrap();
    let body = serde_json::json!({
        "doc_kind":"estimate","doc_number":1,"job_date_unix":0,
        "total_kind":"sum","total_label_key":"total","static_total_cents":null,
        "lines":[{"id":"l1","title":"Mulch","detail":"","qty":"","amount_cents":100,"section":null,"is_gap":false}],
        "queued":false
    });
    let art = store.add_artifact(&session.id, "document", "estimate #1", &body.to_string()).unwrap();
    assert_eq!(document_payload(&art).unwrap().lines[0].item_id, None);
}

#[test]
fn offline_partial_document_carries_the_item_id() {
    use murmur_core::{ItemSource, Store};
    let store = Store::open_in_memory("device-a").unwrap();
    let session = store.start_session(None).unwrap();
    let item = store.add_item_with_source(&session.id, "todo", "haul debris", ItemSource::Live).unwrap();
    let doc = partial_document_from_items("estimate", &[item.clone()], true);
    assert_eq!(doc.lines[0].item_id.as_deref(), Some(item.id.as_str()),
        "the offline fallback builds rows from items — item_id is trivially the item's id");
    assert_eq!(doc.lines[0].id, item.id, "line id also equals the item id in the fallback path");
}
```

- [ ] **Step 2 — `DocLine.item_id`** (`document.rs`): add `pub item_id: Option<String>` to the `DocLine` uniffi record (below `is_gap`, doc-commented: *"the core item this row was built from (Plan 12). `None` for total/rollup lines, or an old document body written before Plan 12. Additive; never derived by the FFI layer."*).

- [ ] **Step 3 — read + stamp** (`convert.rs`):
  - `document_payload`: add `item_id: line.get("item_id").and_then(|x| x.as_str()).map(str::to_string)` to the `DocLine { .. }` construction.
  - `partial_document_from_items`: add `item_id: Some(item.id.clone())` to the `DocLine { .. }` construction (the fallback row *is* the item).

- [ ] **Step 4 — verify:** `nix develop -c cargo test -p ffi` green. Note the binding delta: `DocLine` gains one optional field — additive; no method signatures change.

- [ ] **Step 5 — commit:** `feat(ffi): DocLine.item_id (additive) + carried through convert + offline fallback`

---

## Part B — Swift: map the id + client-side photo/row join (sac owns visuals)

### Task 3: `DocRowFixture.itemId` + `MurmurEngine`/`DemoWalkEngine` parity + review-time grouping

> **⚠️ GROUPING LAYOUT & VISUALS ARE SAC'S** (`meta/CANON.md`, division of labor). This task delivers the *field* on the fixture, the *mapping* through the engines, and a *functional* client-side join so photos render under their row. Every visual decision — per-row photo strip layout, the session-level section header/label, empty states, whether tapping a row scrolls to its photos — gets a `// sac:` comment.

**Files:** modify `Fixtures/Fixtures.swift`, `Engine/MurmurEngine.swift`, `Engine/DemoWalkEngine.swift`, `Flow/ReviewView.swift`.

- [ ] **Step 1 — regenerate bindings** (needs Tasks 1–2 present): from the dev shell, `cd apps/ios && ./build-ffi.sh && ./generate.sh`. Confirm `FFIDocLine` exposes an optional `itemId`.

- [ ] **Step 2 — `DocRowFixture.itemId`** (`Fixtures.swift`): add `var itemId: String? = nil` to `DocRowFixture` (keep the auto `id = UUID()` as the SwiftUI identity — `itemId` is the *core* linkage, distinct from the row's view id).

- [ ] **Step 3 — map it** (`MurmurEngine.swift`, `row(_:)`): add `itemId: line.itemId` to the `DocRowFixture(...)` construction.

- [ ] **Step 4 — demo parity** (`DemoWalkEngine.swift`): where the demo builds its `DocRowFixture` document rows, set `itemId` (nil is acceptable — the demo has no core ids; the field must exist so the join compiles and the demo gallery still renders session-level). `// sac:` note that a demo could wire a stub id to preview grouping.

- [ ] **Step 5 — client-side join** (`ReviewView.swift`, behind `// sac:`): a functional grouping helper:
```swift
// sac: layout/labels/empty-states/tap-to-scroll are yours. This is the join only.
// Photos group under the row whose itemId matches; everything else (nil itemId,
// demoted photos, photos on items with no row) falls to a session-level group.
private func photos(for row: DocRowFixture) -> [PhotoModel] {
    guard let itemId = row.itemId else { return [] }
    return model.photos.filter { $0.itemId == itemId }
}
private var sessionLevelPhotos: [PhotoModel] {
    let rowItemIds = Set(document.rows.compactMap { $0.itemId })
    return model.photos.filter { p in p.itemId == nil || !rowItemIds.contains(p.itemId!) }
}
```
Render per-row photo strips (functional-plain — reuse the existing `photoThumbnail`) and a session-level section for `sessionLevelPhotos`. The existing flat `photoGallery` can stay as the session-level section, or be folded in — sac's call.

- [ ] **Step 6 — verify (dam, manual, OUTSIDE the Nix shell):**
  - Demo build (clean-checkout, no FFI dep): `cd apps/ios && xcodegen generate` then `xcodebuild -project SitewalkGallery.xcodeproj -scheme SitewalkGallery -destination 'platform=iOS Simulator,name=iPhone 17' build` — the review screen renders with `itemId = nil` rows (all photos session-level).
  - Real-core: after `build-ffi.sh` + `generate.sh`, run a walk, attach a photo to a spoken item, process → confirm the doc row for that item shows its photo grouped, and a session-level photo shows in the leftover group. Not a CI gate.

- [ ] **Step 7 — commit:** `feat(ios): DocRowFixture.itemId + review-time photo/row join (grouping visuals: sac handoff)`

---

## Part C — Docs & final review

### Task 4: ROADMAP note + gates + independent whole-artifact review

- [ ] **Step 1 — docs:** in `meta/ROADMAP.md`, note doc-row item ids landed: the `build_document` **echo-and-validate** mechanism (feed authoritative items → optional `item_id` per line → validate against the run set, degrade-to-None + first-wins dedup, never fails the build); the **no-migration additive-JSON** compat (old bodies parse to `None`); the **dangle invariant earned by construction** (validation set == swap-survivor set); the FFI additive `DocLine.item_id`; the functional iOS join (**grouping visuals sac's**). Name the follow-ups: **tap-a-row → jump to item/photos** (sac), **photos-in-PDF**, **vision analysis** (all still Plan 11/CORE.md future work). Cross-reference this plan.

- [ ] **Step 2 — full hermetic gate** (inside the dev shell; paste real output — exit codes, not grep counts):
  - `nix develop -c cargo test --workspace`
  - `nix develop -c cargo clippy --workspace --all-targets -- -D warnings`
  - confirm neither compiles the `whisper` feature; iOS demo build unaffected (no FFI dep in the base `project.yml`).

- [ ] **Step 3 — independent whole-artifact review** (CANON: a **separate agent** from the builder). Read the diff `tools/prompts/pipeline → ffi convert/document → Swift` as one artifact and recompute the pinned traces (A/B/C below):
  - **Echo-and-validate (D1):** recompute Worked Example A by hand — 5 lines, 2 kept, 3 degraded (dup, hallucinated, omitted); confirm the build never errors on a bad id; confirm the per-line display `id` (fresh `new_id`) stays distinct from `item_id`.
  - **Dangle invariant (D3):** confirm the valid set passed to `BuildDocumentTool` is the **`created_ids` Arc** threaded from `run_llm_phases` (C1 — NOT a fresh store query) and is literally the same object as the `run_item_ids` passed to `finish_session_processed`; recompute Worked Example B — the surviving row id is a live item post-swap; a live-item id can never be echoed (live items aren't fed to the model).
  - **Compat (D4):** confirm **no** SQLite migration was added (`MIGRATIONS.len()` unchanged); recompute the pre-Plan-12 body test — every line `item_id` parses to `None`, document renders unchanged.
  - **Join (D5):** recompute Worked Example C — 3 rows, 4 photos, one demoted → correct per-row groups + session-level leftover; injectivity (D2) holds (no photo appears twice).
  - **R6/R9:** the prompt frames the item list as a reference not a checklist; the token cost is the item block in + a short id string per echoed line out — bounded, no prose degradation.

- [ ] **Step 4 — commit:** `docs: Plan 12 doc-row item ids — ROADMAP note + independent review sign-off`

---

## Worked examples (arithmetic-pinned — reviewers recompute by hand)

**A. Echo-and-validate (the D1/D2 core).** This run's authoritative items: `A1`, `A2` (valid set = {A1, A2}). The model returns 5 lines with echoed `item_id`s. Process left-to-right, tracking `claimed`:

| line | echoed item_id | rule | stored item_id | claimed after |
|---|---|---|---|---|
| 0 Mulch | `A1` | in set, unclaimed → keep | **A1** | {A1} |
| 1 Edging | `A2` | in set, unclaimed → keep | **A2** | {A1,A2} |
| 2 Extra | `A2` | in set but **claimed** → None | **null** | {A1,A2} |
| 3 Ghost | `not-a-real-id` | not in set → None | **null** | {A1,A2} |
| 4 Subtotal | *(omitted)* | absent → None | **null** | {A1,A2} |

Result: exactly rows 0,1 carry ids; each of {A1,A2} is claimed by **one** row (injective). Build **succeeds** (no error on rows 2–4). Every stored `item_id` is `∈ {A1,A2} ∪ {null}` — never garbage. `line.id` (fresh `new_id`) ≠ `line.item_id` on every kept row.

**B. Dangle invariant across the swap (D3).** Recording session `S`. Live item `L1` (source=live). Extraction pass creates authoritative `A1` (`created_ids = [A1]`). `run_build_document` feeds the model `[A1]` (L1 is **not** authoritative → not fed), valid set = {A1}. The model echoes `A1` on one line, `L1` on another (it can only know `L1` if it hallucinates it — but `L1 ∉ {A1}`):
1. build_document: row-a `item_id = A1` (valid → kept); row-b `item_id = L1` (**not in {A1}** → **null**). Stored.
2. `finish_session_processed(S, run_item_ids = created_ids = [A1])`: sweep tombstones live/auth items **not in [A1]** → `L1.deleted_at` set; `A1` survives.
3. Post-swap `list_items_for_session(S)` = `[A1]` (live). The stored row-a `item_id = A1` references a **live** item. No row references a tombstoned item — **by construction**, because the only id that survived validation (A1) is exactly the id that survived the swap.

Contrast the bug this prevents: had we fed/validated against *all live items at build time* (including `L1`), row-b would have kept `L1`, then the swap tombstones `L1`, and row-b dangles at a `deleted_at` item — the Plan 11 photo-dangle, reborn for rows. Feeding/validating against the authoritative set closes it.

**C. Review-time join (D5).** Document rows: `R1(itemId=A1)`, `R2(itemId=A2)`, `R3(itemId=None)` (a subtotal). Photos (Plan 11): `P1(item=A1)`, `P2(item=A2)`, `P3(item=A2)`, `P4(item=NULL — demoted at swap from a swept live item)`. `rowItemIds = {A1, A2}`.

| render slot | contents | why |
|---|---|---|
| under R1 | **[P1]** | `p.itemId == A1` |
| under R2 | **[P2, P3]** | `p.itemId == A2` |
| under R3 | **[]** | R3 has `itemId == None` → `photos(for:) == []` |
| session-level | **[P4]** | `P4.itemId == nil` → leftover group |

Every photo appears **exactly once** (injectivity, D2). If a fifth photo `P5(item=A_manual)` existed on a manual item with no row, `A_manual ∉ rowItemIds` → `P5` joins the session-level group too. Nothing is lost; nothing double-renders.

---

## Migration safety

- **No SQLite migration.** The `artifacts` table is untouched; `MIGRATIONS.len()` and `user_version` are unchanged. The change is entirely in the document **artifact body** (JSON) and in the FFI/Swift projection.
- **Forward-compat:** new bodies carry `"item_id"` on lines built from items; `document_payload` reads it. **Backward-compat:** bodies written before Plan 12 have no `"item_id"` → `line.get("item_id")` is `None` → `DocLine.item_id = None` → the row renders exactly as today (no grouping). Old documents that are never reprocessed are unaffected; a reprocess regenerates the body with fresh ids (a reprocess already re-extracts, Plan 06a).
- **No schema version field** (D4) — the defensive field-by-field parser is the compat mechanism; a version marker would be churn.

## Gates

- `nix develop -c cargo test --workspace` — green, **`whisper` feature off**.
- `nix develop -c cargo clippy --workspace --all-targets -- -D warnings` — clean.
- **iOS demo build unaffected** — base `project.yml` has no `MurmurCoreFFI` dep, so all real-core code is behind `#if canImport(MurmurCoreFFI)` (false on a clean checkout) and compiles out; `DocRowFixture.itemId` defaults to `nil`, so the demo review screen renders (all photos session-level). `xcodegen generate` + demo `xcodebuild` succeed with zero setup.
- Swift real-core build is a **manual dam check** (not CI), post `build-ffi.sh` + `generate.sh`.

## Evals

**None.** The `crates/evals` suite grades transcript-in → extracted-items/document F0.5. `item_id` is a linkage on lines the model already builds — it does not change which lines exist or their prose, so no extraction/document score moves. Correctness is fully covered by the hermetic `murmur-core`/`ffi` unit + pipeline tests (echo-and-validate matrix, dangle invariant, compat, offline fallback). No corpus/grader/runner changes.

## Non-goals

- **Tap-a-row → jump to its item / photos** — sac's later UX; this plan ships the id linkage and a static per-row grouping only.
- **Photos embedded in the exported PDF** — the doc artifact body is not extended with photo *bytes* or refs (Plan 11 D5 still holds); the grouping is a client-side read-time join.
- **Vision-model photo analysis** — unchanged from Plan 11 D5; `process()` still does not read photo bytes.
- **Re-linking a demoted photo to the authoritative successor** — impossible without item-identity matching (the model re-extracts fresh UUIDs); demoted photos land in the session-level group, as in Plan 11 D3.
- **Manual-item rows / feeding manual items to `build_document`** — only authoritative items are fed and validatable this run; a manual item's photos group session-level. (Named seam: feed manual items too, if a product need appears.)
- **A `schema_version` on the document body** — deliberately not added (D4).
- **Grouping visual design** — sac's.

## Acceptance criteria

1. `cargo test --workspace` + `cargo clippy --workspace --all-targets -- -D warnings` green with **`whisper` off**; no whisper/model/network/camera dependency; iOS demo build unaffected.
2. **No SQLite migration** — `MIGRATIONS.len()`/`user_version` unchanged; the change is additive JSON in the document artifact body + FFI/Swift projection.
3. `build_document`'s line schema gains an **optional `item_id`**; the forced call is **fed this run's authoritative items** (id+kind+text); the model is instructed to echo the matching id (reference, not checklist).
4. **Echo-and-validate (D1/D2):** `BuildDocumentTool` validates each echoed id against the run's authoritative set and **degrades to `None`** on missing / not-in-set / duplicate ids, **never failing the build**; the mapping is injective (first-wins). Worked Example A holds.
5. **Dangle invariant (D3):** the validation set == the `run_item_ids` swept by `finish_session_processed`, so a validated row `item_id` always references a surviving (live) item post-swap; a live/manual/foreign id can never be stored on a row. Worked Example B holds.
6. **Compat (D4):** old document bodies (no `item_id`) parse with every row `item_id = None` and render unchanged; new bodies carry ids. `DocLine.item_id` is additive across the FFI. The offline `partial_document_from_items` fallback carries `Some(item.id)` trivially.
7. **Join (D5):** the iOS review screen groups `model.photos` under the row whose `itemId` matches (functional-plain, `// sac:` for layout); photos with `nil` `itemId` or an `itemId` matching no row fall to a session-level group; each photo renders exactly once. Demo + real-core build (manual, dam — not CI). Worked Example C holds.
8. Independent whole-artifact review (separate agent) signs off on the Task 4 Step 3 checklist, recomputing traces A/B/C.

## Open questions (need a call)

- *(Resolved 2026-07-07 — validation source of truth: thread the `created_ids` Arc, do NOT re-query the store; C1 applied. See the review blockquote + Task 1 Step 5.)*
- **[dam] Duplicate-id policy:** v1 is **first-wins dedup** (injective row→item map, so a photo renders under one row). Confirm vs. allowing an item to link multiple rows (photos would then duplicate across rows). First-wins is the D2 recommendation.
- **[dam] Feed manual items too?** v1 feeds only authoritative items, so manual-item rows carry `item_id = None` and their photos group session-level. Is that acceptable for v1, or should manual items be fed + validatable (they survive the swap, so no dangle risk)?
- **[sac] Grouping layout & tap behavior (D5/Task 3):** per-row photo strip placement, the session-level section header/empty-state, and whether a row tap scrolls to its photos (the tap-to-navigate seam) are yours — this plan ships a functional join behind `// sac:` markers.
- **[dam+sac] Prose vs. linkage tension (R6):** feeding the item list to `build_document` could nudge the model toward one-line-per-item. The prompt frames it as a reference, not a checklist; if the eval suite (or a device check) shows line inflation, the fallback is to drop the reference block and rely only on the offline path carrying ids (document quality wins over grouping).
