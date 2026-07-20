# Murmur Rust Core — Plan 20: field fixes (walk-reopen read seam + whisper warm-up)

Two independent field-feedback fixes from **TestFlight 2.0.0(44)** (2026-07-15), bundled
because both are dam-lane (ffi / stt / engine / iOS wiring) and both are small, verified
gaps rather than redesigns. The halves share **no files** and can be built/reviewed
independently; they are one plan only to keep one PR, one bindings regen, one real-core gate.

- **Half A — walk-reopen read seam (#223).** "After creating a walk I should be able to
  click it from the home screen, but I can't." The data is durable (Plan 13/14 — notes are
  session artifacts in SQLite); the **read seam is missing**. Add `list_sessions()` +
  `load_notes(session_id)` to the FFI, make the board row tappable, reopen into the
  **existing** `NotesView`. Also closes the **#232-review F2 gap** (the Plan 16 edit
  contract wanted a post-mutation fresh read; there was no method to do it — `load_notes`
  is it).
- **Half B — whisper warm-up (#228).** "First time clicking start walk it took a long time
  for the next page to open." `build_stt_stream` rebuilds a fresh `WhisperContext` (model
  load + Metal init) **every walk**, synchronously, on the main actor inside the tap. Warm
  the context at app-open, **reuse** it across walks, and **decouple** the tap→screen
  transition from the model bring-up.

---

## Rev 2 (adversarial review, 2026-07-19)

Seven fixes from an adversarial review, folded into the sections they touch (voice
preserved). No new scope — each tightens a decision the review found under-pinned:

- **F1 — no `whisper_rs` type crosses the stt→ffi boundary (D6/Stage 3).** The ffi
  crate has *zero* whisper-rs coupling today (it depends only on `stt`, and `stt`
  re-exports `WhisperDecoder` but never `WhisperContext`). The Rev 1 warm holder
  (`WarmStt { ctx: Arc<WhisperContext> }` in ffi) would have introduced that coupling.
  Reworked to an **stt-OWNED opaque handle** `stt::WarmModel` — ffi holds
  `Mutex<Option<stt::WarmModel>>` keyed by path and never names `whisper_rs`.
- **F2 — `hydrateWalkLog` must not clobber on empty-success (D5/Stage 4/5).** A `?? `
  fallback never fires when `listSessions` returns `[]` *successfully* — the demo
  engine's exact case — wiping the walk log if the app-open sweep re-fires. Gated.
- **F3 — the session-id snapshot ordering is a numbered invariant (D9/Stage 5).**
  Nothing session-dependent moves into the paint-first block.
- **F4 — `reopenWalk`'s Task gets a catch (D5/Stage 4).** A NotFound/tombstoned race
  surfaces as a breadcrumb, never a silent dead tap.
- **F5 — a reopened stale-Failed session must not show "unlocks when you reconnect"
  (D3/D5/Stage 4).** Distinct banner string key for reopened-Failed.
- **F6 — begin-throw cosmetic accepted-as-designed (D9/Stage 5).** Named explicitly.
- **F7 — `WalkRecord.init(WalkSummary)` mapping pinned (D5/Stage 4).** The re-hydrate
  fidelity loss (empty `docNo`) is documented as accepted v1.

---

## Ground truth (verified against the real code on `main`)

### Half A — the read seam is genuinely absent, reconstruction already exists internally

- **Board rows are inert.** `WalkLogRow` (`apps/ios/Sources/Flow/BoardView.swift:214–243`)
  is a plain `HStack`; `ForEach(model.sessionWalks) { WalkLogRow(walk:) }`
  (`BoardView.swift:167–169`) has no tap.
- **`WalkRecord` carries no sessionId.** `AppModel.WalkRecord`
  (`AppModel.swift:53–59`) holds only `time/docNo/docKind/sent`. `completeSend()` /
  `discardDocument()` append a record then nil `notes`/`document`
  (`AppModel.swift:744–774`). It is an in-memory *this-session* log, not durable history.
- **No FFI read method.** The `WalkEngine` seam
  (`apps/ios/Sources/Engine/WalkEngine.swift`) has `begin/append/finish/buildDocument/…`
  but **no `listSessions` / `loadNotes`**. The FFI `MurmurEngine` exposes engine-keyed
  `build_document` (`crates/ffi/src/document_build.rs:20–48`) but nothing to *list* or
  *re-read notes*.
- **The reconstruction already lives inside `WalkSession`.** `finish()`'s happy path
  returns `self.partial_notes(&summary, false)` (`crates/ffi/src/session.rs:706–707`).
  `partial_notes` (`session.rs:453–458`) builds a `NotesPayload` from **stored data only**:
  `doc_kind_for_template(template)`, `board_items_and_photo_counts()` (→
  `store.list_items_for_session` + `store.count_live_photos_by_item_for_session`,
  `session.rs:417–423`), and `session_notes()` (→ `store.list_artifacts_for_session`,
  newest `kind=="notes"`, `parse_notes_artifact`, `session.rs:432–446`), all funnelled
  through `notes::notes_payload` (`crates/ffi/src/notes.rs:76–95`). **`load_notes` is that
  same funnel, re-keyed to run without a live `WalkSession`.**
- **Core already has a lightweight projection.** `Store::list_session_summaries()`
  (`crates/murmur-core/src/store/sessions.rs:353–365`) selects `SUMMARY_COLS` — **no
  transcript** (`SUMMARY_COLS`, `sessions.rs:11–12`) — honoring the Plan 04 lesson. It
  lacks `template`, item-count and doc-built, which this plan adds via a purpose-built
  sibling query (below).

### Half B — the model reloads every walk, synchronously, on the tap's main actor

- `AppModel.startWalk()` gates mic permission then `beginWalk()` calls
  `try engine.begin(trade:)` **synchronously on the main actor**, and only then
  `phase = .walking` (`AppModel.swift:234–300`).
- `MurmurEngine.begin` calls `engine.beginWalk(jobId:template:)`
  (`MurmurEngine.swift:141`) → FFI `begin_walk` → `build_stt_stream`
  (`crates/ffi/src/engine.rs:227–247`) → `stt::SttStream::with_model`
  (`crates/stt/src/lib.rs:157–162`) → `WhisperDecoder::open` →
  `WhisperContext::new_with_params` (`crates/stt/src/whisper.rs:37–43`): **model file read +
  Metal context init, every walk.**
- **The context is reusable; only per-decode state is per-call.** `WhisperDecoder::decode`
  creates a fresh state each call via `self.ctx.create_state()`
  (`whisper.rs:82`, `&self`), and bias goes in per-run via `initial_prompt`
  (`whisper.rs:94–96`). So one loaded `WhisperContext` is shareable across sessions; the
  every-walk `new_with_params` is pure waste. (`whisper-rs = "=0.16.0"`,
  `crates/stt/Cargo.toml:14`.)
- **The app-open invariant (#185) is real and load-bearing.** `runAppOpenSweeps()`
  (`AppModel+Photos.swift:runAppOpenSweeps`) MUST stay fully synchronous with **no `await`
  before it** in `GalleryApp`'s `.task` (`GalleryApp.swift:146–150`) or a walk could start
  and get Failed. `retryFailedSessionsInBackground()` is the sanctioned pattern for
  "expensive, fire-and-forget, AFTER the synchronous sweeps" (`AppModel+Photos.swift`,
  a separate not-awaited `Task`). **Warm-up must copy that pattern exactly.**

---

## Binding decisions (reviewers read these first)

### Half A

**D1 — `load_notes` returns the SAME `NotesPayload` `finish()` returns, reconstructed from
the store.** New engine-keyed export `MurmurEngine::load_notes(session_id) ->
Result<NotesPayload, EngineError>`. It reads the store directly (no `WalkSession`): a
free reconstruction that mirrors `partial_notes` exactly —
`doc_kind_for_template(session.template.as_deref())`, `list_items_for_session`,
`count_live_photos_by_item_for_session`, the newest `kind=="notes"` artifact →
`parse_notes_artifact`, funnelled through `notes::notes_payload`. The summary is
`session.summary.unwrap_or_default()`. **`queued = session.status != Processed`** — the one
field `finish()` knows inline and `load_notes` reads back from the terminal status. **The
equality (WE-A/WE-B) is the correctness contract: for any session `finish()` has returned
for, `load_notes` returns a field-by-field identical payload**, because both read the same
committed rows through the same funnel. Extract the shared reconstruction so there is ONE
implementation (a `notes_payload_from_store(store, session_id)` helper that `partial_notes`
and `load_notes` both call — no second funnel to drift).

**D2 — `list_sessions()` is a lightweight projection (Plan 04 lesson), NEVER transcripts.**
New engine-keyed export `MurmurEngine::list_sessions() -> Result<Vec<WalkSummary>,
EngineError>` over a NEW core query `Store::list_walk_summaries()` — a purpose-built
sibling of `list_session_summaries` that adds `template`, `item_count` (correlated
`COUNT` over live items), and `has_document` (`EXISTS` a live `kind='document'` artifact),
all in **one SQL statement, still no `transcript` column**. It is a *separate* method (not
extra columns on `SessionSummary`) so the hot processing-poll path
(`list_session_summaries_by_status`) never pays for the counts. Filters: `deleted_at IS
NULL` **and** `status != 'recording'` (see D3). Reverse-chronological.

**D3 — state-machine rules for what is listable / reopenable (pinned):**
- **Processed** → listed, `queued=false`; reopen gives full edit + document buttons.
- **Failed / AwaitingProcessing** → listed, `queued=true`; reopen renders items with edit
  affordances and build buttons **gated** (the exact `!notes.queued` predicate Plan 16
  clause (a) already uses), and a banner says so. `load_notes` still returns the items —
  capture is never hidden. (A retry sweep, `retryFailedSessions`, is the path to Processed.)
  - **F5 — banner-copy semantics for a REOPENED stale-Failed session.** The fresh-finish
    banner is `"SAVED OFFLINE — DOCUMENTS UNLOCK WHEN YOU RECONNECT"`
    (`NotesView.swift:188`, gated purely on `notes.queued`). For a walk **reopened from the
    board** that is *still* `queued=true`, that copy is a lie: the app-open retry sweep may
    have already run and **exhausted** (the session stayed Failed for a real reason —
    permanent LLM error, not transient offline), so "unlocks when you reconnect" promises a
    recovery that reconnecting won't deliver. Pin a **distinct string key** for the
    reopened-Failed banner (e.g. a `notesBannerReason` the reopen path sets, vs the live
    finish path) so the two states render different copy. **The exact wording is sac's**
    (something truthful like "couldn't finish — retrying automatically"); this plan only
    pins that reopened-Failed MUST NOT reuse the reconnect-promise string.
- **Recording** → **excluded** from `list_sessions` entirely. Either it is the *live* walk
  (reopening the walk you're in is nonsense) or an un-swept crash zombie (the app-open
  sweep flips it to Failed on the next launch anyway, `sweep_zombie_sessions`). Excluding it
  needs no new machinery — the `status != 'recording'` filter in D2.
- **Deleted (tombstoned)** → excluded by `deleted_at IS NULL` (already in every query;
  `delete_session` cascades to items/artifacts/photos, `sessions.rs:324–351`). Pinned, not
  assumed. *(No delete UI ships here — Non-Goals.)*

**D4 — this ALSO closes the #232-review F2 gap; `load_notes` is the Plan 16 fresh read.**
Plan 16's item-CRUD contract (`WalkEngine.swift`, the `// sac:` clause (b)) mandates
"after an edit, re-read from the engine … the ONLY sanctioned post-edit path" — but **no
read method existed**, which the #232 review flagged (F2). `load_notes(session_id)` is
exactly that method. This plan **updates the clause-(b) contract text** to name
`loadNotes(sessionId)` as the sanctioned fresh-read, and (functional-plain) has the notes
screen re-read via `loadNotes` after a successful edit instead of patching `notes.items` in
place (`AppModel.swift:501–537` currently mutate local state — the echo-as-truth anti-pattern
clause (b) warns against). *(The visual edit UX stays sac's; this wires the data path the
contract already demanded.)*

**D5 — iOS: `WalkRecord` gains `sessionId`; the row taps into the EXISTING `NotesView`.**
`WalkRecord` gains `sessionId: String` and a `queued: Bool` (for the reopened-notes gating
banner). `WalkLogRow` becomes a `Button` → `model.reopenWalk(sessionId:)`, which
`await engine.loadNotes(sessionId:)`, sets `notes`, sets `currentSessionId = sessionId` (so
`buildDocument`/edit are engine-keyed correctly — `AppModel.swift:466,501,519` read
`currentSessionId`), and navigates `phase = .notes; path = [.notes]`. Because the path is
`[.notes]` (no `.walking` beneath it), **back returns to the board root, never to a live
walk** — pinned. Reopen is read-only re-entry: it does NOT start a pump, does NOT touch
`.walking`, does NOT resurrect a session.

**F4 — `reopenWalk`'s Task gets a catch (no silent dead tap).** `loadNotes` can throw: a
`NotFound`/tombstoned-session race (the board list was hydrated a moment ago; a concurrent
delete/sweep could tombstone the row between hydrate and tap) surfaces as an `Err` from the
FFI `load_notes` (`get_session` returns `NotFound` for a `deleted_at`-set row). `reopenWalk`'s
`Task` **mirrors `buildDocument`'s error handling** (`AppModel.swift:483–487`): on throw, log
the breadcrumb and set a new `reopenError: String?` ("Couldn't reopen that walk — it may have
been removed.") — the board stays put, no navigation. A tap must NEVER fail silently.
`// sac:` owns the `reopenError` chrome; the floor is the log + the breadcrumb string.

**F7 — `WalkRecord.init(_ summary: WalkSummary)` mapping (pinned).** Board hydration maps each
FFI `WalkSummary` → `WalkRecord`: `sessionId := summary.id`; `time :=` formatted from
`summary.started_at` (the epoch-ms the summary carries — the same clock `walkStart` uses);
`queued := summary.queued`; `sent := summary.has_document` (a built-and-kept walk reads as
"sent"); `docKind := DocKinds.label(for: summary.doc_kind)`; **`docNo := ""` (synthesized
empty).** The document *number* is minted per-build and is not in the lightweight projection
(D2 carries `has_document`, not the number) — so a **re-hydrated** record loses the visible
doc number. **This fidelity loss is accepted for v1** and documented: local *in-session*
`WalkRecord`s (appended by `completeSend`/`discardDocument`) keep full fidelity including
`docNo` until the next hydrate overwrites the log. (Carrying the doc number through
`list_walk_summaries` is a possible follow-up; not scoped here.)

**F2 — `hydrateWalkLog` must not clobber a good log on empty-success (guarded).** The board's
walk log is **hydrated from `engine.listSessions()` at app-open** so history survives
relaunch. Rev 1 wrote `sessionWalks = (try? listSessions())?.map(WalkRecord.init) ??
sessionWalks` — but `DemoWalkEngine.listSessions` returns `[]` **successfully**, so the `??`
never fires and the demo's in-memory walk log is **wiped** if `runAppOpenSweeps` re-fires
(the exact re-fire the #206 guard exists for). Two guards:
  1. **Once-per-process guard** `isHydratingWalkLog` (mirror `isRetryingFailedSessions`,
     `AppModel.swift:102` / `AppModel+Photos.swift:150–151`) so a `.task` re-fire can't
     re-hydrate.
  2. **Overwrite only on non-empty OR real-core.** `hydrateWalkLog` overwrites `sessionWalks`
     **only when the fetched list is non-empty, OR the engine is real-core** (real-core's
     `[]` is a legitimate "no sessions yet" and should clear a stale log; the demo's `[]` is
     a no-op stub that must not clobber). An empty result from the demo leaves the in-memory
     log untouched.

  **Demo posture (explicit):** the demo keeps its in-memory walk log (records appended by
  `completeSend`/`discardDocument`); `DemoWalkEngine.listSessions` stays a `[]` no-op and
  `loadNotes` returns the last demo notes or `emptyNotes`. Reopen on the demo compiles and is
  a harmless no-op path — it never wipes the demo log.

`// sac:` owns row visuals, empty state, ordering polish.

### Half B

**D6 — reuse a single warmed model across walks, via an stt-OWNED opaque handle
(pool-of-one; NO `whisper_rs` type crosses the stt→ffi boundary — F1).** The ffi crate has
**zero** whisper-rs coupling today: it depends only on `stt`, and `stt` re-exports
`WhisperDecoder` but **never** `WhisperContext` (`crates/stt/src/lib.rs:16–17` gates the
`whisper` module private; `WhisperContext` never leaves the crate). A warm holder that named
`Arc<WhisperContext>` in ffi (Rev 1) would have *introduced* that coupling — wrong layer.
Instead the warm model is an **opaque, stt-owned handle**:

- **stt:** internally `WhisperDecoder` holds `Arc<WhisperContext>` (was owned
  `WhisperContext`); `decode` is unchanged (`self.ctx.create_state()` already takes `&self`,
  `whisper.rs:82`). New public opaque type **`stt::WarmModel`** (feature-gated with `whisper`
  exactly like `WhisperDecoder` — non-whisper builds don't see it) that wraps the loaded
  `Arc<WhisperContext>` **and does not expose it**. New
  **`stt::load_warm_model(path: &Path, use_gpu: bool) -> Result<WarmModel, SttError>`**
  (opens the `WhisperContext` once — the same `WhisperContext::new_with_params` `with_model`
  runs, `whisper.rs:37–43`). New consumer
  **`SttStream::with_warm(model: &WarmModel, cfg, vocab) -> Self`** (internally
  `Arc::clone`s the context into a `WhisperDecoder::from_context` — **no model load**).
  Keep `with_model` (cold path) unchanged. **Compile-assert `WarmModel: Send + Sync`**
  behind `#[cfg(feature="whisper")]` (`const _: fn() = || { fn a<T: Send + Sync>() {}
  a::<WarmModel>(); }`) — verified true in vendored whisper-rs 0.16.0 (`WhisperInnerContext`
  is `unsafe impl Send`/`Sync`; the model is read-only after load, states are per-decode).
- **ffi:** the engine holds `stt_warm: Mutex<Option<stt::WarmModel>>` **keyed by path** — ffi
  **never names `whisper_rs`** (F1 is the correctness contract for this decision). Because the
  handle is opaque, ffi cannot reach inside it; it only holds, matches, and hands it back to
  `SttStream::with_warm`. (Path keying lives alongside the handle — see D8 for exactly how.)
  `build_stt_stream` (`engine.rs:227–247`): if a warm handle exists for the current
  `stt_model_path`, `SttStream::with_warm(&model, cfg, bias)` (**no model load**); else
  cold-load via `with_model` AND populate the warm holder (warm-on-first-use).

One walk at a time ⇒ pool-of-one is sufficient.

**D7 — `warm_stt()`: app-open background warm, silent-degrade.** New engine export
`MurmurEngine::warm_stt() -> Result<(), EngineError>` that loads the context into the warm
holder if absent (idempotent; a second call with a warm-and-matching holder is a no-op).
Swift `warmStt()` on `WalkEngine` fires it fire-and-forget from the **tail** of
`runAppOpenSweeps()` — AFTER `retryFailedSessionsInBackground()`, as its OWN not-awaited
`Task`, **never before the synchronous sweeps** (#185 invariant). **Failure is
silent-degrade:** a warm failure is logged and swallowed — the next `begin` cold-loads on
demand (today's exact behavior). Warm-up must NEVER block or crash the app.

**D8 — staleness: the warm handle is keyed by model path.** The warm holder stores the
`model_path` that produced the handle **next to the opaque `WarmModel`** — ffi's own
bookkeeping (a `struct { model_path: String, model: stt::WarmModel }`, or a
`Mutex<Option<(String, stt::WarmModel)>>`), NOT a field ffi reaches inside the handle for
(F1: ffi never inspects `WarmModel`). `build_stt_stream` reuses the warm handle **only if
`stored_path == self.stt_model_path`**; a mismatch (a `STT_MODEL` launch-arg swap
across a relaunch that somehow reuses a holder, or any future multi-path caller) discards
and reloads. Within one process `stt_model_path` is fixed at construction, so this is a
guard, not a hot path — but it makes the reuse provably correct against a model swap.

**D9 — UI decouple: paint `.walking` before the (now-cheap) `begin`.** `AppModel.beginWalk`
is reordered so `phase = .walking` + a new `micStarting = true` flag are set FIRST (screen
paints), and `try engine.begin(trade:)` + pump/event wiring run inside a `Task { }` that
yields to let SwiftUI render before the begin work runs on the next main-actor turn. On
success `micStarting = false`; on throw, log + `phase = .board` (the existing "stay on the
board" posture, `AppModel.swift:283–299`, preserved — a dead session must not enter the
walking flow). `WalkView` shows a brief **"MIC STARTING…"** meta state while `micStarting`
(functional-plain string swap in the existing `MetaStrip`; `// sac:` owns styling).
Combined with D6/D7 the common path is instant (warm ⇒ `begin` is an `Arc` clone); the
"MIC STARTING…" state masks the residual first-ever-tap cold-load.

**D9-invariant — the session-id snapshot stays strictly AFTER `begin` succeeds, inside the
Task (F3).** Only two things move into the paint-first block: `phase = .walking` and
`micStarting = true`. **Nothing session-dependent** moves with them. Pinned ordering inside
the `Task { }`:

1. `try engine.begin(trade:)` — if it throws, jump straight to the throw arm (log +
   `phase = .board` + `micStarting = false`); do NOT run steps 2–4.
2. `currentSessionId = engine.currentSessionId` — the snapshot, **strictly after** begin
   returns Ok, while the live session still owns an id (Plan 11 D7). It must not precede
   step 1, and it must not sit in the paint-first block.
3. reset walk state (`transcript`/`previewTail`/`items`/`isPaused`/`walkStart`/`photos`) +
   wire the pump/event/audio tasks.
4. `micStarting = false`.

Rationale (Plan 07 dead-walk): STT/audio must never wire onto a session that `begin` didn't
successfully open — a dead session would run the pump and silently drop every append
(capture loss). The snapshot and all wiring are session-dependent, so they live *after* the
begin gate, never in the paint-first block.

**F6 — accepted cosmetic (as-designed).** On a begin-throw, the screen briefly painted
`.walking`/"MIC STARTING…" and then reverts to `.board` with the error breadcrumb (a visible
flash-to-walking-then-back). This is accepted: begin-throw is the rare offline/permission
edge, the revert is immediate, and the alternative (gate the paint on begin success) throws
away the entire perceived-latency win of D9 for the common case. Stated so a future reviewer
doesn't "fix" the flash by re-serializing the paint behind `begin`.

**D10 — memory pressure: holding `base.en` resident is intended, documented.** The whole
app is on-device STT; keeping the ~140 MB `base.en` context resident after warm is the
app's purpose, not a leak. Decision recorded here so a future reviewer doesn't "fix" it by
dropping the warm ctx between walks (which would re-introduce #228). The context is dropped
only on engine teardown (process exit).

---

## Worked examples (reviewers: hand-recompute against the real code)

### WE-A — `load_notes` == `finish()` for a Processed session (the D1 equality)

Session `S` (`status = Processed`, `template = "estimate"`, `summary = Some("Estimate for
the front yard.")`). Live items `[I1, I2]`; one live `kind="notes"` artifact with a single
`scope_of_work` entry; `count_live_photos_by_item_for_session(S) = { I1: 2 }`.

`finish()` Ok-arm (`session.rs:704–707`) returns `partial_notes("Estimate for the front
yard.", false)`:

| field | value |
|-------|-------|
| `session_id` | `"S"` |
| `doc_kind` | `doc_kind_for_template(Some("estimate"))` = `"estimate"` |
| `summary` | `"Estimate for the front yard."` |
| `items` | `[board_item(I1,{I1:2}), board_item(I2,{})]` — `I1.photo_count = 2`, `I2.photo_count = 0` |
| `notes` | `[NotesEntry{ ScopeOfWork, label, detail }]` |
| `queued` | `false` |

`load_notes("S")` reconstruction: `get_session("S")` → `status=Processed`,
`template="estimate"`, `summary=Some("Estimate for the front yard.")`. Then the **same**
`doc_kind_for_template("estimate")="estimate"`, the **same** `list_items_for_session` →
`[I1,I2]`, the **same** `count_live_photos_by_item_for_session` → `{I1:2}`, the **same**
newest-notes-artifact parse → 1 entry, funnelled through the **same** `notes_payload`.
`queued = (Processed != Processed) = false`.

⇒ **field-by-field identical.** (Because `process()` already committed summary + notes
artifact + swapped board *before* `finish()` returned, `load_notes` reads the exact same
rows.) The Task asserts equality by building a session to Processed, capturing the
`finish()` payload, then asserting `load_notes(id) == captured`.

### WE-B — reopening a Failed (offline-degraded) session

Session `F` finished offline: `process()` erred, `finish()` Err-arm returned
`partial_notes("", true)` (`session.rs:709–710`), leaving `F` **not** Processed
(`status ∈ {Failed, AwaitingProcessing}`), `summary = None`, items intact `[I3, I4, I5]`,
no notes artifact.

`finish()` returned: `summary=""`, `items=[I3,I4,I5]`, `notes=[]`, `queued=true`.

`load_notes("F")`: `get_session` → `status=Failed`, `summary=None`→`""`. Items
`[I3,I4,I5]` (survived). No `kind="notes"` artifact → `notes=[]`. `queued = (Failed !=
Processed) = true`.

⇒ identical: `{summary:"", items:[I3,I4,I5], notes:[], queued:true}`. In the reopened
`NotesView`, `queued==true` gates edits + build buttons (Plan 16 clause (a)) and shows the
"SAVED OFFLINE" banner — capture visible, actions gated, exactly as a fresh offline finish.

### WE-C — `list_sessions` projection + filters (D2/D3)

Store rows: `P`(Processed, 2 live items, 1 live document artifact),
`F`(Failed, 3 items, 0 documents), `R`(Recording — live walk), `D`(Processed but
tombstoned). `started_at`: `P=300, F=200, R=400, D=100`.

`list_walk_summaries()` SQL (`WHERE deleted_at IS NULL AND status != 'recording' ORDER BY
started_at DESC, id DESC`) returns `[P, F]` — `R` excluded (Recording), `D` excluded
(tombstoned). Note `R` has the newest `started_at` yet never appears.

| id | doc_kind | status | item_count | has_document | queued |
|----|----------|--------|-----------:|:------------:|:------:|
| `P` | from `template` | Processed | 2 | true | false |
| `F` | from `template` | Failed | 3 | false | true |

`queued = status != Processed`; `doc_kind = doc_kind_for_template(template)`. The Swift
`WalkStatus` enum maps `AwaitingProcessing → .processing`, `Failed → .failed`,
`Processed → .processed`.

### WE-D — the `begin` call path, before vs after (thread sequence)

**Before (every walk pays the full cost, on main):**
```
[main] tap → startWalk → (perm granted) → beginWalk
[main]   try engine.begin(trade:)                       ← @MainActor, synchronous
[main]     engine.beginWalk(FFI)  → build_stt_stream
[main]       SttStream::with_model → WhisperContext::new_with_params
[main]         >>> model file read + Metal init: BLOCKS main for T_load <<<
[main]     returns stream → wire pump/event tasks
[main]   phase = .walking
[main] SwiftUI finally renders the walk screen           ← perceived latency = T_load
```
`T_load` = the whole #228 complaint (worst on first run: cold read + Metal shader compile).

**After (warm at app-open; paint before begin; reuse the ctx):**
```
App-open, GalleryApp .task:
[main] runAppOpenSweeps()  (sweepPhotoBytes, sweepZombieSessions — SYNC, #185)  ← unchanged, first
[main]   retryFailedSessionsInBackground()   → Task (not awaited)
[main]   warmSttInBackground()               → Task (not awaited)         ← NEW, AFTER the sync sweeps
[bg-ish]   engine.warmStt() → load_warm_model → stt::WarmModel into warm holder (once)  ← T_load paid here, off the tap

Tap:
[main] tap → startWalk → (perm) → beginWalk
[main]   phase = .walking; micStarting = true            ← screen PAINTS now
[main]   SwiftUI renders "MIC STARTING…"                 ← perceived latency = 0
[main]   Task { }  (yields first)
[main]     try engine.begin(trade:) → build_stt_stream
[main]       warm holder present & path matches → SttStream::with_warm(&WarmModel)  ← O(1), no model load
[main]         (WarmModel internally Arc::clones its ctx — opaque to ffi, F1)
[main]     currentSessionId = engine.currentSessionId  (AFTER begin Ok — D9-invariant)
[main]     wire pump/event tasks; micStarting = false
```
Common path: main-actor block ≈ `Arc::clone` ≈ 0. First-ever tap before warm finishes:
`begin` still cold-loads, but the screen already painted (D9), so perceived latency is 0
and the "MIC STARTING…" state covers the wait. Warm failure ⇒ cold-load on demand
(silent-degrade, D7).

---

## Non-goals (explicit)

- **Recover-walk UI polish (sac's).** Row visuals, the reopened-notes banner styling, empty
  states, history ordering/grouping, the "revisit a walk means…" UX (`meta/ROADMAP.md`
  "Up Next" item 4) are sac's. This plan ships functional-plain affordances +
  `// sac:` markers only.
- **No session delete / no delete UI.** Tombstone *filtering* is pinned (D3); a delete
  affordance is out of scope.
- **No session search.** `Store::search_sessions` exists (`sessions.rs:257`) but no search
  surface ships here.
- **No jobs/projects container model.** The "walks evolve over a project's life" idea
  (#223) is a `meta/` design discussion, not scoped here.
- **No on-device latency benchmark rework.** The Plan 06 spike harness exists; we don't
  re-measure — the reuse+warm design removes the reload regardless of the absolute number.
- **No correction-learning / reflection changes.** Half A's fresh-read is a pure re-read;
  it does not touch `record_correction` (still Plan 17's).

---

## Hard dependencies (all DONE, on `main`)

- Plan 13/14 notes-first: `NotesPayload` / `notes::notes_payload` (`crates/ffi/src/notes.rs`),
  `partial_notes` / `session_notes` / `board_items_and_photo_counts`
  (`crates/ffi/src/session.rs:417–458`), `parse_notes_artifact` + `doc_kind_for_template`
  (`murmur_core`).
- Plan 16 item CRUD: the `// sac:` clause-(b) fresh-read contract this plan fulfills
  (`WalkEngine.swift`), the `!notes.queued` gating predicate (clause (a)).
- Store projections: `list_session_summaries` + `SUMMARY_COLS` (no transcript) as the
  template for `list_walk_summaries` (`sessions.rs:353–365`, `11–12`).
- Engine-keyed export precedent: `build_document` (`document_build.rs:20–48`).
- App-open sweep pattern: `runAppOpenSweeps` + `retryFailedSessionsInBackground`
  (`AppModel+Photos.swift`), #185 invariant, `GalleryApp.swift:146–150`.
- whisper reuse surface: `WhisperDecoder`/`SttStream` (`crates/stt/src/whisper.rs`,
  `crates/stt/src/lib.rs`), `create_state` per decode (`whisper.rs:82`).

---

## Staging (main stays shippable after every stage)

Each stage is independently green (`cargo test --workspace`, `cargo clippy --workspace
--all-targets -- -D warnings`; iOS demo build for Swift stages). Half A = Stages 1,2,4;
Half B = Stages 3,5; Stage 6 gates both.

### Stage 1 — core: `list_walk_summaries()` + `WalkSummary` (murmur-core; D2/D3)

- **Add** `crate::domain::WalkSummary { id, job_id: Option<String>, template:
  Option<String>, status: SessionStatus, summary: Option<String>, started_at: u64,
  ended_at: Option<u64>, item_count: u64, has_document: bool }`.
- **Add** `Store::list_walk_summaries() -> Result<Vec<WalkSummary>, CoreError>` — ONE SQL:
  select `id, job_id, template, status, summary, started_at, ended_at`, a correlated
  `(SELECT COUNT(*) FROM items i WHERE i.session_id = s.id AND i.deleted_at IS NULL)` for
  `item_count`, and `EXISTS(SELECT 1 FROM artifacts a WHERE a.session_id = s.id AND a.kind =
  'document' AND a.deleted_at IS NULL)` for `has_document`. `WHERE s.deleted_at IS NULL AND
  s.status != 'recording' ORDER BY s.started_at DESC, s.id DESC`. **No `transcript`
  column** (Plan 04 lesson).
- **Tests** (`store/sessions.rs` test mod): `list_walk_summaries_excludes_recording_and_deleted`
  (WE-C: seed P/F/R/D, assert `[P,F]` order + fields); `list_walk_summaries_counts_live_items_only`
  (add + tombstone an item, assert count reflects only live); `list_walk_summaries_flags_has_document`
  (add a live document artifact → true; tombstone it → false); `..._no_transcript_in_projection`
  (a giant transcript doesn't change timing/columns — assert the struct has no transcript
  field, compile-enforced).

### Stage 2 — ffi Half A: `WalkSummary`/`WalkStatus` records + `list_sessions` + `load_notes` (ffi; D1/D2/D3)

- **New file `crates/ffi/src/sessions_read.rs`** (disjoint from Plan 19's document surfaces —
  see Conflict Note): `#[derive(uniffi::Enum)] WalkStatus { Processing, Processed, Failed }`
  (map `AwaitingProcessing→Processing`); `#[derive(uniffi::Record)] WalkSummary { id, doc_kind:
  String, status: WalkStatus, summary: String, started_at: u64, item_count: u32, has_document:
  bool, queued: bool }`. `#[uniffi::export] impl MurmurEngine { pub fn list_sessions(&self) ->
  Result<Vec<WalkSummary>, EngineError> }` mapping core `WalkSummary` → FFI (`doc_kind =
  doc_kind_for_template(template.as_deref())`, `summary = summary.unwrap_or_default()`,
  `queued = status != Processed`).
- **`load_notes` in `crates/ffi/src/notes.rs` or `session.rs`:** extract
  `notes_payload_from_store(store, session_id) -> Result<NotesPayload, CoreError>` (the
  shared reconstruction: `get_session` for template+summary+status, `list_items_for_session`,
  `count_live_photos_by_item_for_session`, newest `kind=="notes"` artifact →
  `parse_notes_artifact`, `queued = status != Processed`, funnel `notes_payload`).
  **Refactor `WalkSession::partial_notes` to delegate** to it (ONE funnel — no drift).
  `#[uniffi::export] impl MurmurEngine { pub fn load_notes(&self, session_id: String) ->
  Result<NotesPayload, EngineError> }`. A missing/tombstoned session → `Err`
  (`get_session` already filters `deleted_at IS NULL` and returns `NotFound`).
- **Tests** (`sessions_read.rs` / `session.rs` test mods, mock providers via
  `with_providers`): `load_notes_equals_finish_for_processed_session` (WE-A: run a session
  to Processed, capture `finish()`, assert `load_notes(id) == captured`);
  `load_notes_failed_session_is_queued_with_items` (WE-B); `load_notes_unknown_session_errs`;
  `list_sessions_projects_and_gates` (WE-C fields + `queued`/`has_document`);
  `list_sessions_carries_no_transcript` (projection shape).

### Stage 3 — stt + ffi Half B core: context reuse + `warm_stt` (stt, ffi; D6/D7/D8/D10)

- **stt (owns the opaque handle — F1):** `WhisperDecoder.ctx: Arc<WhisperContext>` (internal);
  add `WhisperDecoder::from_context(Arc<WhisperContext>, language, use_gpu?, word_timestamps)`
  (internal). Add the public opaque **`stt::WarmModel`** (feature-gated with `whisper`; wraps
  the `Arc<WhisperContext>` and does **not** expose it), **`stt::load_warm_model(path: &Path,
  use_gpu: bool) -> Result<WarmModel, SttError>`**, and **`SttStream::with_warm(model:
  &WarmModel, cfg, vocab) -> Self`** (internally `Arc::clone`s into `from_context` — no model
  load). Keep `with_model` (cold path). **Compile-assert `WarmModel: Send + Sync`** behind
  `#[cfg(feature="whisper")]` — `const _: fn() = || { fn a<T: Send + Sync>() {} a::<WarmModel>();
  }` (true in vendored 0.16.0: `WhisperInnerContext` is `unsafe impl Send`/`Sync`). **No
  `whisper_rs` type is public** — `WhisperContext` stays crate-private.
- **ffi (never names `whisper_rs` — F1):** engine holds `stt_warm: Mutex<Option<(String,
  stt::WarmModel)>>` (or an equivalent `struct { model_path: String, model: stt::WarmModel }`),
  feature-gated on `whisper`; the `String` is ffi's own path bookkeeping (D8), **not** a field
  read out of the opaque handle. `build_stt_stream` (`engine.rs`): if warm && stored
  `model_path == stt_model_path` → `SttStream::with_warm(&model, cfg, bias)`; else `with_model`
  then store `(stt_model_path.clone(), load_warm_model(...)?)` into `stt_warm`
  (warm-on-first-use). New `#[uniffi::export] MurmurEngine::warm_stt() -> Result<(),
  EngineError>` — loads into the holder if absent/stale (idempotent); `None` model path →
  `Ok(())` no-op (text-only). Non-whisper build → `warm_stt` = `Ok(())`, holder absent.
  **Compile-check the F1 contract:** a `grep -R "whisper_rs\|WhisperContext" crates/ffi/src`
  must return **nothing** after this stage.
- **Tests:** `warm_stt_is_idempotent` (two calls, holder loaded once — assert via a load
  counter or path-match no-op); `build_stt_stream_reuses_warm_ctx` (feature-gated,
  `#[ignore]` needing a real model like the existing `real_model_decodes_silence`, or a
  seam test asserting `with_warm` is taken when warm present); `warm_stt_none_model_is_ok`;
  `warm_ctx_invalidated_on_model_path_change` (D8 — swap the holder's `model_path`, assert
  reload). Where a real model is unavailable in CI, gate on the seam (which constructor was
  called) via a test double, not on decoding.

### Stage 4 — ios Half A: reopen wiring + fresh-read contract (apps/ios; D4/D5)

- **`WalkEngine.swift`:** add `func listSessions() throws -> [WalkSummary]` and `func
  loadNotes(sessionId: String) async throws -> NotesModel`; app-side `WalkSummary` struct
  (mirror) + `WalkStatus` enum. **Update Plan 16 clause (b)** contract text to name
  `loadNotes(sessionId:)` as the sanctioned post-edit fresh read (replace "re-read from the
  engine" prose with the concrete method). `DemoWalkEngine` conforms: `listSessions` → `[]`,
  `loadNotes` → the last demo notes or `emptyNotes` (no-op history).
- **`MurmurEngine.swift`:** map FFI `list_sessions`/`load_notes` → app types (reuse
  `Self.notes(payload)` for `loadNotes`; new `Self.walkSummary(_:)` in
  `MurmurEngineFormatting.swift`).
- **`AppModel.swift`:** `WalkRecord` gains `sessionId: String` + `queued: Bool`; populate
  at `completeSend`/`discardDocument` from `currentSessionId` and the notes' `queued`. Add
  **`WalkRecord.init(_ summary: WalkSummary)`** (F7 mapping: `sessionId := summary.id`,
  `time` from `summary.started_at`, `queued := summary.queued`, `sent := summary.has_document`,
  `docKind := DocKinds.label(for: summary.doc_kind)`, **`docNo := ""`** — the doc number isn't
  in the projection; re-hydrate fidelity loss accepted v1, in-session records keep full
  fidelity until the next hydrate).
  Add `func hydrateWalkLog()` (called from the app-open path) — **guarded (F2):** a
  once-per-process `isHydratingWalkLog` flag (mirror `isRetryingFailedSessions`), and it
  overwrites `sessionWalks` **only when the fetched list is non-empty OR the engine is
  real-core** (never let the demo's successful `[]` clobber the in-memory log — the `??`
  fallback doesn't catch empty-success). Add `func reopenWalk(sessionId:)` →
  `Task { do { notes = try await engine.loadNotes(sessionId:); currentSessionId = sessionId;
  phase = .notes; path = [.notes] } catch { log + reopenError = "Couldn't reopen that walk…" } }`
  (F4: mirror `buildDocument`'s catch, `AppModel.swift:483–487` — a NotFound/tombstoned race is
  a breadcrumb, never a silent dead tap; guard against a live walk: only from `.board`). Add
  `var reopenError: String?`. Change the post-edit paths (`AppModel.swift:501–537`) to
  **re-read via `loadNotes` after a successful mutation** instead of patching `notes.items`
  in place (D4).
- **`BoardView.swift`:** `WalkLogRow` → `Button { model.reopenWalk(sessionId: walk.sessionId) }
  label: { … existing row … }.buttonStyle(.plain)`. `// sac:` marker for the reopen
  affordance visuals + the reopened banner.
- **`NotesView.swift`:** the offline banner (`NotesView.swift:188`, gated on `notes.queued`)
  must render **distinct copy for a REOPENED stale-Failed session** vs a fresh offline finish
  (F5): a reopened `queued=true` walk must NOT show "DOCUMENTS UNLOCK WHEN YOU RECONNECT" (a
  lie post-retry-exhaustion). Wire a distinct string key (e.g. a `notesBannerReason` the
  `reopenWalk` path sets) so the two states diverge; **copy wording is sac's**. `// sac:`
  marker on the reopened-Failed banner string.
- **Tests / build:** iOS demo build green (`xcodegen generate` + simulator build); demo
  engine reopen is a no-op path (compiles, doesn't crash). *(Real reopen is exercised at the
  Stage 6 gate.)*

### Stage 5 — ios Half B: app-open warm + tap decouple (apps/ios; D7/D9)

- **`WalkEngine.swift`:** add `func warmStt()` (throwing or fire-and-forget-safe);
  `DemoWalkEngine` no-ops. `MurmurEngine.warmStt()` → `try engine.warmStt()`.
- **`AppModel+Photos.swift`:** add `warmSttInBackground()` (mirror
  `retryFailedSessionsInBackground` exactly — a guarded, not-awaited `Task`, logs + swallows
  failure); call it at the **tail** of `runAppOpenSweeps()`, AFTER
  `retryFailedSessionsInBackground()`. Document the #185 invariant in its doc comment
  ("never before the synchronous sweeps"). Also call `hydrateWalkLog()` here (safe: read-only
  list, no session mutation).
- **`AppModel.swift`:** add `var micStarting = false`. Reorder `beginWalk`: set
  **only** `phase = .walking; micStarting = true` FIRST (the paint-first block — nothing
  session-dependent here), then a `Task { }` (yields) that runs the D9-invariant ordering
  **strictly**: (1) `try engine.begin`; (2) `currentSessionId = engine.currentSessionId`
  **after** begin returns Ok; (3) reset walk state (`transcript`/`previewTail`/`items`/
  `isPaused`/`walkStart`/`photos`) + wire pump/event/audio tasks; (4) `micStarting = false`.
  On throw → log + `phase = .board` (preserve the stay-on-board posture) + `micStarting =
  false`, and do NOT run steps 2–4 (no STT/audio wiring on a dead session — Plan 07). **The
  session-id snapshot and all wiring MUST NOT move into the paint-first block** (F3). **F6
  accepted cosmetic:** on begin-throw the screen briefly painted `.walking`/"MIC STARTING…"
  then reverts to `.board` with the error — accepted as-designed (do not re-serialize the
  paint behind `begin`, which would forfeit the D9 win).
- **`WalkView.swift`:** the `MetaStrip` `right` shows `"MIC STARTING…"` while
  `model.micStarting`, else the existing "REC — ON-DEVICE STT". `// sac:` marker for the
  starting-state styling.
- **Build:** iOS demo build green.

### Stage 6 — real-core compile, bindings regen, device smoke (dam-manual) **[MANDATORY GATE]**

- `cd apps/ios && ./build-ffi.sh` (regen the `MurmurCoreFFI` xcframework with the new
  `list_sessions`/`load_notes`/`warm_stt` exports + `WalkSummary`/`WalkStatus` records),
  `./generate.sh`, build for **iPhone 17** OUTSIDE the nix shell. Wipe DerivedData if a
  stale SwiftPM graph errors (CLAUDE.md demo↔real gotcha).
- **Half A smoke:** finish a walk → tap it on the board → notes reopen with the same
  summary/items; build a document from the reopened notes; edit a line and confirm the
  screen re-reads (fresh-read, D4); back returns to the board (not a live walk); relaunch →
  the walk is still on the board and still reopens.
- **Half B smoke:** cold-launch, wait a beat, tap START WALK → screen appears immediately
  ("MIC STARTING…" then live); confirm subsequent walks start instantly; airplane-mode /
  warm-failure path still starts a walk (silent-degrade, cold-load).
- Record the device outcome in the PR **Thinking** section.

---

## Conflict note for the builder (Plan 19 in parallel)

Plan 19 (document-schema) is being planned concurrently and also touches `crates/ffi` +
regenerates uniffi bindings. **The Rust source is disjoint:** Plan 20's FFI additions live
in `sessions_read.rs` (new), `notes.rs`/`session.rs` (session surfaces), `engine.rs` +
`crates/stt` — Plan 19 is in document/schema surfaces. **The bindings regen conflicts
textually** (both regenerate the same generated Swift). **Whoever merges second rebases and
re-runs `./build-ffi.sh` — the regen is deterministic**, so the conflict resolves by
regenerating, not by hand-merging generated files.

---

## Gates (every stage)

- `cargo test --workspace` green.
- `cargo clippy --workspace --all-targets -- -D warnings` clean.
- Swift stages: `cd apps/ios && xcodegen generate` + simulator build (iPhone 17) green.
- Stage 6: real-core build + device smoke (dam-manual), outcome in the PR Thinking section.

## Acceptance criteria

1. `load_notes(session_id)` returns a `NotesPayload` **field-by-field identical** to what
   `finish()` returned for the same session (WE-A test), and returns queued-with-items for a
   Failed session (WE-B test). ONE reconstruction funnel (`partial_notes` delegates to it).
2. `list_sessions()` is a transcript-free projection excluding Recording + tombstoned rows,
   carrying `item_count`/`has_document`/`queued`/`doc_kind` (WE-C test).
3. Tapping a board walk row reopens it in the **existing** `NotesView` with correct gating
   (edits/build disabled iff `queued`), a working document button, and back-to-board nav;
   the log survives relaunch (Stage 6 smoke).
4. The Plan 16 clause-(b) contract text names `loadNotes(sessionId:)` as the sanctioned
   post-edit fresh read, and the notes screen re-reads via it after an edit (D4).
5. One warmed model is reused across walks (no per-walk `new_with_params` when warm) via the
   stt-owned opaque `stt::WarmModel` — `grep -R "whisper_rs\|WhisperContext" crates/ffi/src`
   returns nothing (F1); `warm_stt()` fires app-open, fire-and-forget, AFTER the synchronous
   sweeps (#185 preserved); warm failure silent-degrades to cold-load.
6. The START WALK tap paints the walk screen before `begin` completes ("MIC STARTING…"),
   and the common (warm) path starts instantly (WE-D; Stage 6 smoke).

## Risks & rollback

- **R1 — `load_notes`/`partial_notes` funnel drift.** Mitigated by extracting ONE shared
  `notes_payload_from_store` that both call; WE-A equality test is the regression guard.
- **R2 — `stt::WarmModel` (wrapping `WhisperContext`) not `Send + Sync` / unsafe to share
  across the pump thread.** Mitigated by the `WarmModel: Send + Sync` compile-assert (Stage 3,
  verified true in vendored 0.16.0 — `WhisperInnerContext` is `unsafe impl Send`/`Sync`) and
  the pool-of-one (one walk at a time). If it fails to compile, fall back to
  warm-only-of-the-model-*bytes* (mmap cache) — but 0.16 `create_state(&self)` strongly
  implies shareable. Rollback: drop D6 reuse, keep D7 warm + D9 decouple (still fixes the
  perceived latency; loses the per-walk-reload win). The opaque-handle boundary (F1) is
  independent of this risk: even the byte-cache fallback stays inside `stt` and keeps ffi
  free of `whisper_rs`.
- **R3 — warm ctx staleness on model swap.** Mitigated by the path-keyed holder (D8).
- **R4 — `hydrateWalkLog()` at app-open racing a live walk.** It is read-only
  (`list_sessions` mutates nothing) and runs at the same quiescent app-open point as the
  sweeps; excluded-Recording means it never surfaces a live/zombie walk. Safe by
  construction, but keep it in the `runAppOpenSweeps` tail (not a scenePhase re-trigger).
- **R5 — bindings regen collision with Plan 19.** See Conflict Note — deterministic regen,
  second-merger rebases + `./build-ffi.sh`.
- **Rollback granularity:** Half A and Half B share no files; either can be reverted
  independently (revert its stages) without touching the other.

## Open questions (non-blocking)

1. Should the board log show a distinct affordance for `has_document` (a built vs
   notes-only walk)? Data is carried (`WalkSummary.has_document`); the visual is sac's.
2. Should reopening a Failed walk offer an inline "retry now" (vs waiting for the app-open
   retry sweep)? Out of scope here (recover-walk UI is sac's/`meta/`); the data path
   (`retryFailedSessions`) already exists.
