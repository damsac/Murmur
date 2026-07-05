# Murmur Rust Core — Plan 09: STT Accuracy Hardening — word-level timestamps + live-prompt eval pins

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Rust tasks are **hermetic** (ScriptedDecoder/MockProvider — no model, no cmake, no Metal, no network). `cargo test --workspace` must NEVER require the `whisper` feature, a model file, or a native toolchain — this is the load-bearing CI invariant of the whole STT effort (Plan 06 requirement 4) and it does not bend here. Any code that touches whisper stays behind `#[cfg(feature = "whisper")]`.

**Goal:** Close the two "accuracy hardening" roadmap threads on top of the Plan 08 STT stack:

1. **Word-level timestamps** — replace the `Finalizer`'s documented *segment-coarse* fallback (`finalize.rs` merge CAVEAT, lines 79–88) with **per-word** timing. Whisper's `token_timestamps` gives per-token `t0`/`t1`; we carry them onto `RawSegment` as an **additive** `Vec<WordTiming>`, teach `words_from_segments` to prefer per-word timing when present and **degrade to today's segment-coarse behavior when absent**, and prove the coarse-seam duplicate/drop failure mode is fixed. The append-only / first-decode-wins contract and the Plan 08 `no_speech_prob` gate are **inviolable**.
2. **Live-prompt pins in the evals** — pin the `LiveExtractor` prompt behavior against the eval corpus with a deterministic grader (F0.5 / R6-weighted), so a live-prompt edit is regression-gated. Advances with the Plan 06a swap-at-finish contract. Scoped as **pin scaffolding only** (see D7) — the DSPy/GEPA optimization loop remains out of scope.

**What this plan is NOT.** It does not change the streaming window math (`chunk_secs`/`overlap_secs`), the `Chunker`, the append-only merge/finalize *algorithm* (only the timing precision fed into it), the FFI surface (`FinalizedSegment` shape, `push_audio`, `WalkEvent` cases), the Swift shell, or any product prompt text. It does not enable whisper's `max_len`/`split_on_word` single-word-segment mode (see D2, rejected). It does not build model download/management, trie/logit biasing, diarization, DTW-alignment timestamps (`t_dtw`), or the live-prompt *optimization* loop. It adds precision to existing seams and a hermetic pin harness.

**Hard dependencies (all DONE, main @ `b7d79c8`):**
- Plan 06 (`crates/stt`: `SttStream` pump, `Decoder` seam + `ScriptedDecoder`, `WhisperDecoder` behind the `whisper` feature, `Finalizer` with the text/time two-seam merge, `build_bias_prompt`).
- Plan 08 (`RawSegment.no_speech_prob` additive field + the `Finalizer` no-speech drop gate at `words_from_segments`; the SNR sweep harness `spikes/stt-whisper` `sweep` subcommand → `RESULTS.md` Table 4A/4B).
- Plan 05b (`crates/evals`: paired-fixture corpus, deterministic Dice grader, F0.5 headline scalar, `run.rs` hermetic/real runner, `MockProvider`).
- Plan 06a (`source` column + atomic swap-at-finish; the `LiveExtractor` characterization pins in `crates/evals/tests/carried_scenarios.rs`).

**Verified API facts (checked against the vendored crate source, not guessed):**
- `whisper-rs =0.16.0` (`crates/stt/Cargo.toml:14`). `FullParams::set_token_timestamps(bool)` exists (`whisper_params.rs:189`, EXPERIMENTAL, default `false`). `set_max_len(c_int)` (`:216`) and `set_split_on_word(bool)` (`:225`) also exist but are **not used** here (D2).
- Per-token access: `WhisperSegment::n_tokens() -> c_int` (`whisper_state/segment.rs:72`), `WhisperSegment::get_token(c_int) -> Option<WhisperToken>` (`:166`), `WhisperToken::token_data() -> WhisperTokenData` (`whisper_state/token.rs:42`), `WhisperToken::to_str_lossy() -> Result<Cow<str>>` (`token.rs:123`).
- `WhisperTokenData = whisper_rs_sys::whisper_token_data` (`lib.rs:45`) has fields `t0: i64`, `t1: i64`, `t_dtw: i64` (`whisper-rs-sys-0.15.0/src/bindings.rs:4935–4937`). **We read `t0`/`t1`** (the classic token-timestamp path, populated when `token_timestamps = true`) and **never `t_dtw`** (the DTW path, which requires an alignment-head model variant). So **no special model file is needed** — the bundled `ggml-base.en-q5_1.bin` works unchanged.
- Units: `whisper` segment `start_timestamp()`/`end_timestamp()` and token `t0`/`t1` are all **centiseconds** (1 cs = 10 ms), chunk-relative. `words_from_segments` already converts `cs → ms` via `window_start_ms + (cs.max(0) as u64) * 10`; per-word timing uses the **identical** formula with the token's `cs`. No new unit conversion is introduced.

**Spec:** vision spec Rev 2 §2 (append-only streaming transcript), R3 (no machinery hallucination — the Plan 08 gate must keep working), R6 (under-extraction bias — F0.5 in the eval pins), Plan 06 `RESULTS.md` "Required next step" + Table 4 (the sweep is the accuracy-delta measurement tool).

---

## Architecture — decisions, justified (reviewers read these first)

### D1. Word-precise timing needs a *word-anchored* coarse-seam drop rule, not just precise `end_ms` (design corrected after review)
Today the **coarse (time) seam** drops the prefix of `new_words` whose `end_ms ≤ pending_max_end` — exact only when the decoder isolates the overlap in its own early-ending segment; when whisper lumps the overlap into a longer phrase-level segment, a divergent overlap can (a) duplicate (covering segment ends past `pending_max_end` → nothing dropped) or (b) drop genuinely-new words that share the covered segment's `end_ms` (the CAVEAT, `finalize.rs:79–88`).

**The naïve fix ("just give each `Word` its own `end_ms`, merge unchanged") does NOT work — this was a real design gap.** Hand-trace of the lumped divergent re-decode: pending holds `work` ending at `pending_max_end = 4800 ms`; the new window re-decodes the overlap as `needs`(4000–4800), `word`(4800–**5600**), then genuinely-new `before`(5600–6600)… The two decodes don't align at the boundary — a divergent re-decode can **spread the same disputed span across longer/more words**, inflating an early disputed word's `end_ms` **past** the old boundary. `skip_while(|w| w.end_ms <= 4800)` then drops `needs` but **keeps `word`** (5600 > 4800) → the divergent second decode `word` leaks into the committed stream (duplication). Precise `end_ms` alone is insufficient because `end_ms` is exactly the field the skew corrupts.

**Chosen rule — the word-anchored coarse seam keys on `start_ms`, the segment-coarse seam keeps keying on `end_ms`.** For a *word-precise* new word, `start_ms` is the reliable signal: a word that **starts at or inside audio we've already committed** (`start_ms ≤ pending_max_end`) is a re-decode of held audio and is dropped (first-decode-wins); a word that starts strictly after (`start_ms > pending_max_end`) is genuinely-new and appended. Re-trace: `needs`(start 4000 ≤ 4800) drop, `word`(start 4800 ≤ 4800) drop, `before`(start 5600 > 4800) keep → committed `[… needs work before the pour]`, `word` gone, `work` once. The boundary-equality case (`start_ms == pending_max_end`) resolves to **drop** — R6/R3 under-commit bias: a word starting exactly where the last committed word ended, in a seam where the two decodes already *disagree* on text, is presumed a re-decode; losing one word costs less trust than a duplicate.

**Why the rule must be mode-aware (a single scalar rule cannot serve both).** No pure threshold on the new word's own `(start, end)` distinguishes the two modes: in the *segment-coarse* regression test the genuinely-new word `before` has segment-start `4800` (all words in its segment share the segment span), while in the *word-precise* case the disputed word `word` also starts at `4800` — **same value, opposite desired action** (keep `before`, drop `word`). So `Word` must carry whether its timing is word-precise. Segment-coarse words keep the legacy `end_ms ≤ pending_max_end` rule verbatim (their `end_ms` is the only semi-reliable signal, and it works because a coarse genuinely-new segment ends well past the boundary); word-precise words use `start_ms ≤ pending_max_end`.

So the change to the append-only path is **small and additive, not an algorithm rewrite**: (i) `Word` gains a `time_precise: bool`; (ii) `words_from_segments` sets it (`true` on the word-anchored branch, `false` on coarse/fallback); (iii) `merge`'s coarse-seam `skip_while` predicate branches on `w.time_precise`. `finalize_before` / `flush` / `preview` and the **text seam** are byte-for-byte untouched; the coarse seam gains one branch and behaves **identically** to today for every coarse (`time_precise=false`) word — so all existing tests pass unchanged. Append-only is still preserved by construction: the seam only ever *drops* a prefix of *new* words; no committed word is revisited.

### D2. Keep phrase-level segments; read per-token `t0`/`t1`. Reject `max_len=1` single-word segments
Two ways to get word-precise timing from whisper:
- **(chosen)** leave decoding/segmentation alone (`token_timestamps = true` only) and read each token's `t0`/`t1` from `token_data()`, grouping tokens into words.
- **(rejected)** set `max_len = 1` + `split_on_word = true` so whisper emits one **segment** per word — then `RawSegment` needs no new field and `start_cs`/`end_cs` are already word-precise.

The single-word-segment route is tempting (zero struct change) but rejected because it **moves the `no_speech_prob` gate off its measured basis**: Plan 08 tuned the R3 drop threshold (0.6) against *phrase-level* segment probabilities measured in the SNR sweep (Table 4B). One-word segments produce a different `no_speech_prob` distribution the threshold was never calibrated for — re-opening a closed R3 decision to fix a timing bug. It also discards phrase grouping that downstream (and the sweep's WER attribution) assumes. The chosen route is strictly additive: segmentation, `no_speech_prob`, and biasing are byte-for-byte unchanged; only per-word timing metadata is added. (`max_len`/`split_on_word` are verified to exist — we deliberately don't call them.)

### D3. Representation: `Vec<WordTiming>` co-located on `RawSegment`, default empty
`RawSegment` gains `pub words: Vec<WordTiming>` where `WordTiming { text: String, start_cs: i64, end_cs: i64 }`. Rationale:
- **Co-located, can't desync.** The timing lives on the same struct as the `text` it describes; there is no parallel `Vec<Vec<WordTiming>>` on the decode result to fall out of alignment with the segment list. (Rejected: a parallel vector keyed by segment index — extra plumbing, silent-desync risk.)
- **Additive, matches the `no_speech_prob` precedent.** Default `Vec::new()` = "no word timing available" ⇒ the finalizer degrades to segment-coarse. `ScriptedDecoder` and every existing test keep passing with empty `words`.
- **Carries `text` so the finalizer can self-heal.** `words_from_segments` cross-checks the word-timing count against `text.split_whitespace().count()`; on any mismatch it falls back to segment-coarse for that segment (D4). Storing the text (not just the span) makes that check trivial and keeps the finalizer's emitted word text **always** equal to the segment's split text — the timing is best-effort, the text is authoritative.

**Bounded blast radius of a count-matching-but-mis-grouped BPE reconstruction (finding 2).** The count guard (D4) only catches a *count* mismatch. A BPE grouping that produces the *right count* but attaches a token to the wrong word (e.g. a leading-space boundary misread) passes the guard. The damage is strictly **bounded timing skew on the two adjacent words at the mis-grouping** — their `start_ms`/`end_ms` shift by the mis-attributed sub-token's span. It **cannot corrupt text** (text always comes from the authoritative `split`-zip, never from token reconstruction) and **cannot violate append-only** (the coarse-seam rule still only drops a prefix of new words; worse case is a one-word over/under-drop at the seam, i.e. the same class of ±1-word imprecision the fallback already prices in). The R3 `no_speech_prob` gate is upstream of grouping and unaffected. Task 5 adds a per-word ground-truth spot-check (assert known fixture words land within a tolerance window) so gross mis-grouping is caught on real audio, not merely count-checked.

**`Word` gains `time_precise: bool` (D1).** This lives on the internal `finalize::Word` (constructed only in `words_from_segments`; `lib.rs::emit` reads `.start_ms`/`.end_ms`/`.text` by field and ignores it, so `FinalizedSegment` and the FFI surface are unchanged). Grep `Word {` before implementing to confirm the construction-site set (expected: `words_from_segments` only; any finalize.rs test that builds a `Word` literal directly gets `time_precise: false`).

### D4. `words_from_segments` prefers per-word timing, degrades safely, guards alignment
New logic, per segment (after the unchanged `no_speech_prob` drop):
- If `seg.words` is **empty** → today's behavior verbatim: split `text` on whitespace, every word gets the segment-coarse `start_ms`/`end_ms` and **`time_precise = false`**.
- If `seg.words` is **non-empty AND** `seg.words.len() == seg.text.split_whitespace().count()` → emit one `Word` per whitespace token, `time_precise = true`, taking `text` from the split (authoritative) and `start_ms`/`end_ms` from the aligned `WordTiming` via the identical `window_start_ms + cs*10` formula. Clamp so `end_ms ≥ start_ms` and each word's `start_ms`/`end_ms` are non-decreasing within the segment (defends against a stray out-of-order token timestamp; whisper token times are monotonic in practice but we do not assume it).
- If `seg.words` is **non-empty but the count disagrees** → fall back to segment-coarse (`time_precise = false`) for that segment (self-heal) — a silent-correctness event worth a debug log, not a panic.

`time_precise` is what the coarse seam's drop rule branches on (D1). This keeps the emitted stream identical for all existing scripted tests (empty `words` ⇒ `time_precise=false` ⇒ legacy `end_ms` rule) and word-precise for real whisper / word-scripted tests. The `no_speech_prob` gate runs first and is untouched.

### D5. `token_timestamps` is a `SttConfig` knob, default `true`; internal to `crates/stt` (not surfaced to Swift)
- `SttConfig` gains `pub word_timestamps: bool`, default **`true`**. `WhisperDecoder::decode` calls `params.set_token_timestamps(cfg.word_timestamps)` and only populates `RawSegment.words` when it is on.
- **Always-on-vs-config, resolved (not a joint blocker):** config knob, default on. Rationale: (i) reversibility without a code change matches the project's toggle discipline (Plan 08 D6/D7); (ii) the cost is trivially affordable — `RESULTS.md` Table 1 puts `base.en` at RTF **0.009** (≈55× real-time headroom), and `token_timestamps` adds only a post-decode timestamp-assignment pass, not a decode constraint (D2), so WER is expected unchanged (Task 6 *measures* this to confirm, not assumes). If the sweep shows an unacceptable RTF or WER delta, flip the default to `false` — the finalizer already degrades to coarse, so nothing else changes.
- **Not surfaced to Swift / `EngineConfig`.** Unlike `use_gpu` (which MUST differ sim-vs-device because Metal hard-crashes on the sim), `token_timestamps` is backend-agnostic (works on CPU/BLAS and Metal alike) and has no sim hazard, so it stays internal to `SttConfig::default()`. No FFI plumbing, no Swift change. (Revisit only if a product reason to toggle it per-platform appears.)
- **Struct-literal safety:** every `SttConfig { .. }` site in the tree uses `..SttConfig::default()` struct-update syntax (verified: `engine.rs:181`, `lib.rs:340/365/382/390/392`), so adding a field breaks **no** literal — only the `Default` impl (`lib.rs:66`) and the struct def (`lib.rs:29`) change.

### D6. Enumerate every `RawSegment` construction site (the struct-literal lesson)
Adding `words: Vec<WordTiming>` to `RawSegment` (a plain struct with no `Default` derive) breaks every struct literal until updated. The **complete** set (verified by `grep -rn "RawSegment {"`), all of which must add `words: Vec::new()` (or route through a helper):

| File | Line(s) | Kind | Change |
|------|---------|------|--------|
| `crates/stt/src/decoder.rs` | struct def (`:6`) | definition | add `pub words: Vec<WordTiming>` |
| `crates/stt/src/decoder.rs` | `:63`, `:64` | test literals | `words: vec![]` |
| `crates/stt/src/finalize.rs` | `:144` | `seg(..)` helper | `words: vec![]` in the one helper |
| `crates/stt/src/lib.rs` | `:272` | `seg(..)` helper | `words: vec![]` |
| `crates/stt/src/lib.rs` | `:362`, `:363` | test literals | `words: vec![]` |
| `crates/stt/src/whisper.rs` | `:58` | **production populate** | populate from tokens (Task 5) |
| `crates/stt/tests/stream_append_only.rs` | `:11` | `seg(..)` helper | `words: vec![]` |
| `crates/ffi/tests/audio_pump_e2e.rs` | `:56` | `seg(..)` closure | `words: vec![]` |
| `crates/ffi/src/session.rs` | `:911`, `:1127` | `seg(..)` closures | `words: vec![]` |

Most are `seg(..)` helpers (one edit each covers many callers). A `RawSegment::with_words(base, words)` builder (Task 1) gives word-scripted tests a one-liner without editing `ScriptedDecoder` at all.

### D7. Live-prompt pins are scaffolding; the honest regression signal is the assembled prompt, not the mocked output
`crates/evals/run.rs` currently drives `SessionProcessor::process` (the batch pass). Thread 2 pins the **`LiveExtractor`** path. The subtlety a reviewer must see: under a **deterministic `MockProvider`**, the board items are whatever the script emits — grading them is near-circular. The **real** regression signal when someone edits the live prompt is the **assembled request text** the `LiveExtractor` sends (which `MockProvider::requests()` records — exactly how `carried_scenarios.rs::restart_after_many_items_re_adds_an_evicted_item` already asserts). So the pin is:
- a **golden snapshot** of the assembled live prompt for a fixed corpus input (the true gate: a prompt edit diffs the golden and forces a conscious re-bless), **plus**
- a grader run over the live board to keep the plumbing honest (F0.5/R6 via the existing `grade()`), which also documents the swap-at-finish (Plan 06a) board state.

Real, non-circular F0.5 movement from live-prompt edits needs the **gated real-API runner** (the existing `examples/eval.rs`) extended to drive the live path — that is **flagged, not built here** (needs a key, non-deterministic, belongs with the optimization loop). Thread 2 is deliberately small; it does **not** merit its own plan — the scaffolding is ~2 tasks and rides Plan 05b's existing crate.

### D8. The SNR sweep is the accuracy-delta gate, and it is device/model-gated (flagged for dam)
`token_timestamps` should not move WER (D2/D5), but "should not" is a claim to *measure*, not assert. The `spikes/stt-whisper` `sweep` subcommand (Plan 08 Task 12) is the tool: rerun it with `token_timestamps` on and diff Table 4A (WER vs SNR) and the clean RTF against the committed `RESULTS.md` baseline. This needs the real model files + macOS `say`-generated WAVs — it is **manual, not CI**, and **flagged for dam** to run on hardware. The hermetic finalizer/decoder tests (Tasks 1–5) are the CI gate; the sweep is the empirical sign-off.

---

## File Structure

```
crates/
  stt/
    src/
      decoder.rs        # MODIFY: WordTiming type; RawSegment.words field; with_words builder; timed test helper
      finalize.rs       # MODIFY: Word.time_precise; words_from_segments word-anchored expansion + alignment guard; merge coarse-seam start-vs-end drop rule; update CAVEAT doc; new tests
      lib.rs            # MODIFY: SttConfig.word_timestamps (default true) + Default impl; seg helper + literals get words; new stream-level test
      whisper.rs        # MODIFY (#[cfg(feature="whisper")]): set_token_timestamps; populate RawSegment.words from token t0/t1; extend #[ignore] real-model test
    tests/
      stream_append_only.rs   # MODIFY: seg helper gets words: vec![]; NEW word-anchored append-only regression test
  ffi/
    src/session.rs      # MODIFY: two seg closures get words: vec![] (compile-only; no behavior change)
    tests/audio_pump_e2e.rs  # MODIFY: seg closure gets words: vec![]
  evals/
    src/run.rs          # MODIFY: run_live_scenario (LiveExtractor over a scenario, hermetic); assembled-prompt capture
    tests/
      live_prompt_pins.rs     # NEW: golden live-prompt snapshot pin + grader-over-live-board pin (hermetic)
    fixtures/
      live_prompt_golden.txt  # NEW: committed golden assembled live prompt for the pinned scenario
spikes/stt-whisper/
  src/sweep.rs          # MODIFY: honor a --token-timestamps flag (default off) in decode_with_nsp's params
  src/main.rs           # MODIFY: thread the flag (usage line)
  RESULTS.md            # MODIFY: Table 4A' — token_timestamps-on rerun deltas + clean RTF (dam, device)
docs/
  plans/2026-07-05-rust-core-09-stt-accuracy-hardening.md   # THIS FILE
```

Run cargo inside the Nix dev shell (`direnv` / `nix develop`), or `nix shell nixpkgs#cargo nixpkgs#rustc -c cargo <cmd>` from the repo root. Whisper-feature and sweep steps run **outside** CI (need model files / native toolchain).

---

## Part A — Word-level timestamps

### Task 1: `WordTiming` type + additive `RawSegment.words` field + builders

**Files:** Modify `crates/stt/src/decoder.rs` (+ every construction site in D6's table).

- [ ] **Step 1 — failing tests** (bottom of `crates/stt/src/decoder.rs`):

```rust
#[test]
fn raw_segment_defaults_to_no_word_timing() {
    let s = RawSegment { start_cs: 0, end_cs: 200, text: "hello world".into(),
        no_speech_prob: 0.0, words: vec![] };
    assert!(s.words.is_empty(), "empty words = degrade to segment-coarse");
}

#[test]
fn with_words_builds_a_timed_segment_from_a_base() {
    // Ergonomic constructor for word-scripted tests: base carries text/span/nsp,
    // words carries per-word timing. No change to ScriptedDecoder.
    let s = RawSegment::with_words(
        RawSegment { start_cs: 0, end_cs: 300, text: "order twelve".into(),
            no_speech_prob: 0.0, words: vec![] },
        vec![
            WordTiming { text: "order".into(),  start_cs: 0,   end_cs: 120 },
            WordTiming { text: "twelve".into(), start_cs: 120, end_cs: 300 },
        ],
    );
    assert_eq!(s.words.len(), 2);
    assert_eq!(s.words[1].end_cs, 300);
    assert_eq!(s.text, "order twelve", "base text preserved");
}

#[test]
fn scripted_decoder_replays_word_timed_segments_unchanged() {
    // The whole point of D3/D6: ScriptedDecoder needs NO change to script timings.
    let mut d = ScriptedDecoder::new(vec![vec![RawSegment::with_words(
        RawSegment { start_cs: 0, end_cs: 200, text: "french drain".into(),
            no_speech_prob: 0.0, words: vec![] },
        vec![
            WordTiming { text: "french".into(), start_cs: 0,  end_cs: 80 },
            WordTiming { text: "drain".into(),  start_cs: 80, end_cs: 200 },
        ],
    )]]);
    let out = d.decode(&[0.0; 16], None).unwrap();
    assert_eq!(out[0].words.len(), 2);
}
```

- [ ] **Step 2 — implement** (`crates/stt/src/decoder.rs`):

```rust
/// Per-word timing within a segment (whisper `token_timestamps`, chunk-relative
/// centiseconds — same reference as `RawSegment.start_cs`/`end_cs`). Additive:
/// an empty `RawSegment.words` means "no word timing", and the `Finalizer`
/// degrades to segment-coarse spans (Plan 09 D4). `text` is carried so the
/// finalizer can cross-check alignment against the segment text and self-heal.
#[derive(Clone, Debug, PartialEq)]
pub struct WordTiming {
    pub text: String,
    pub start_cs: i64,
    pub end_cs: i64,
}
```

Add `pub words: Vec<WordTiming>` to `RawSegment` (document it as additive/default-empty, mirroring the `no_speech_prob` doc). Add:

```rust
impl RawSegment {
    /// Attach per-word timing to a base segment. Convenience for word-scripted
    /// tests and the whisper populate path; no effect on `ScriptedDecoder`.
    pub fn with_words(base: RawSegment, words: Vec<WordTiming>) -> Self {
        RawSegment { words, ..base }
    }
}
```

Export `WordTiming` from `lib.rs` (`pub use decoder::{Decoder, RawSegment, ScriptedDecoder, WordTiming};`). Update the two existing `decoder.rs` test literals (`:63`, `:64`) with `words: vec![]`.

- [ ] **Step 3 — fix every OTHER construction site** so the workspace compiles (D6 table): the `seg` helpers in `finalize.rs`, `lib.rs`, `stream_append_only.rs`, the `seg` closures in `ffi/src/session.rs` (×2) and `ffi/tests/audio_pump_e2e.rs`, and the inline literals in `lib.rs` (`:362/:363`). Each adds `words: vec![]`. **No behavior change** — these are all coarse-path sites.

- [ ] **Step 4 — verify:** `cargo build --workspace && cargo test -p stt decoder` (green; the whole workspace still compiles with the whisper feature off).

- [ ] **Step 5 — commit:** `git add -A && git commit -m "feat(stt): additive WordTiming on RawSegment + with_words builder (no behavior change)"`

---

### Task 2: `Finalizer` word-anchored expansion + word-anchored coarse-seam drop rule

**Files:** Modify `crates/stt/src/finalize.rs`.

The heart of the plan. Two coupled changes (D1): (i) `words_from_segments` emits word-precise `Word`s tagged `time_precise = true`; (ii) `merge`'s coarse seam drops a *precise* new word by `start_ms ≤ pending_max_end` and a *coarse* one by the legacy `end_ms ≤ pending_max_end`. Prove the lumped-divergent-re-decode duplication is fixed while append-only, the segment-coarse behavior, and the no-speech gate all hold.

**Worked arithmetic the tests encode** (window offsets applied; `to_ms(cs) = window_start_ms + cs*10`):

*Flagship — lumped divergent overlap.* W0 `ingest(0, …, horizon=4000)`:
- `the`(0–1000), `french`(1000–2400), `drain`(2400–3600), then held segment `needs`(3600–4400), `work`(4400–**4800**).
- `finalize_before(4000)` cuts at `needs` (end 4400 > 4000) → **e0 = [the, french, drain]**; pending = `[needs(3600–4400), work(4400–4800)]`, `pending_max_end = 4800`.

W1 `ingest(4000, …, horizon=8000)`, one lumped segment re-decoding the overlap as "needs **word**" then new tail:
- new (precise): `needs`(4000–4800), `word`(4800–5600), `before`(5600–6600), `the`(6600–7300), `pour`(7300–8000).
- text seam: tail `["needs","work"]` vs head `["needs","word"]` → no match, `best=0` → coarse seam.
- precise drop `skip_while(start_ms ≤ 4800)`: `needs`(4000≤4800 drop), `word`(4800≤4800 drop — **boundary-equality resolves to drop**, R6 under-commit), `before`(5600≤4800 false → **stop**). Keep `[before, the, pour]`.
- `finalize_before(8000)` flushes pending+kept → **e1 = [needs, work, before, the, pour]**.
- **all = [the, french, drain, needs, work, before, the, pour]** — `work` once, `word` gone. (Legacy `end_ms ≤ 4800` would keep `word` at end 5600 → the leak this fixes.)

- [ ] **Step 1 — failing tests** (add to `finalize.rs` `mod tests`; add a `seg_words(..)` helper — the file's coarse `seg(..)` helper at `:143–144` gets `words: vec![]`):

```rust
fn seg_words(cs0: i64, cs1: i64, words: &[(&str, i64, i64)]) -> RawSegment {
    RawSegment::with_words(
        RawSegment { start_cs: cs0, end_cs: cs1,
            text: words.iter().map(|(t, _, _)| *t).collect::<Vec<_>>().join(" "),
            no_speech_prob: 0.0, words: vec![] },
        words.iter().map(|(t, a, b)| crate::decoder::WordTiming {
            text: (*t).into(), start_cs: *a, end_cs: *b }).collect(),
    )
}

#[test]
fn word_timing_gives_each_word_its_own_end_ms() {
    // One phrase-level segment [0,4800ms] but per-word timing: "needs" ends 4000,
    // "work" ends 4800. Coarse expansion would stamp BOTH at 4800.
    let mut f = Finalizer::default();
    let out = f.ingest(0, &[seg_words(0, 480, &[("needs", 0, 400), ("work", 400, 480)])], u64::MAX);
    assert_eq!(out[0].end_ms, 4000, "word-precise, not segment-coarse 4800");
    assert_eq!(out[1].end_ms, 4800);
}

#[test]
fn word_anchored_coarse_seam_drops_lumped_divergent_overlap_without_duplication() {
    // FLAGSHIP (see worked arithmetic above). W1 re-decodes the held overlap
    // "needs work" as "needs word" LUMPED with new text into one long segment; the
    // divergent word "word" is INFLATED to end 5600 (past pending_max_end 4800), so
    // a legacy end-based drop would leak it. The word-anchored start-based rule drops
    // it (start 4800 ≤ 4800) and keeps only the genuinely-new suffix.
    let mut f = Finalizer::default();
    let e0 = f.ingest(0, &[
        seg_words(0, 360, &[("the", 0, 100), ("french", 100, 240), ("drain", 240, 360)]),
        seg_words(360, 480, &[("needs", 360, 440), ("work", 440, 480)]),
    ], 4_000);
    assert_eq!(words(&e0), vec!["the", "french", "drain"]);
    let e1 = f.ingest(4_000, &[seg_words(0, 400, &[
        ("needs", 0, 80), ("word", 80, 160), ("before", 160, 260), ("the", 260, 330), ("pour", 330, 400),
    ])], 8_000);
    let all: Vec<&str> = words(&e0).into_iter().chain(words(&e1)).collect();
    assert_eq!(all, vec!["the", "french", "drain", "needs", "work", "before", "the", "pour"]);
    assert!(!all.contains(&"word"), "divergent re-decode dropped (start ≤ boundary)");
    assert_eq!(all.iter().filter(|w| **w == "work").count(), 1, "first decode wins, no duplication");
    // append-only: start_ms non-decreasing across the whole committed stream.
    let mut prev = 0;
    for w in words_full(&e0).iter().chain(words_full(&e1).iter()) { assert!(w.start_ms >= prev); prev = w.start_ms; }
}

#[test]
fn inflated_early_disputed_word_does_not_leak_past_the_seam() {
    // DEDICATED inflated-early-word case (reviewer's finding): the disputed word's
    // end is inflated FAR past the boundary; end-based drop would keep it (dup),
    // start-based drop removes it.
    let mut f = Finalizer::default();
    // W0: "pour" finalized (end 2000 ≤ 4000), "footing" held (2000..4800).
    let e0 = f.ingest(0, &[seg_words(0, 480, &[("pour", 0, 200), ("footing", 200, 480)])], 4_000);
    assert_eq!(words(&e0), vec!["pour"]);
    // W1: overlap re-decoded DIFFERENTLY ("footings") and INFLATED to end 6000 (≫4800),
    // then genuinely-new "now"(6000..7000).
    let e1 = f.ingest(4_000, &[seg_words(0, 300, &[("footings", 0, 200), ("now", 200, 300)])], 8_000);
    let all: Vec<&str> = words(&e0).into_iter().chain(words(&e1)).collect();
    // "footing" (W0 first decode) survives once; divergent "footings" dropped; "now" kept.
    assert_eq!(all, vec!["pour", "footing", "now"]);
    assert!(!all.contains(&"footings"), "inflated divergent re-decode dropped by start-based rule");
}

#[test]
fn empty_word_timing_degrades_to_segment_coarse() {
    let mut f = Finalizer::default();
    let out = f.ingest(0, &[seg(0, 480, "needs work")], u64::MAX);
    assert_eq!(out[0].end_ms, 4800, "coarse: both share segment end");
    assert_eq!(out[1].end_ms, 4800);
}

#[test]
fn existing_segment_coarse_disagreement_still_keeps_new_suffix() {
    // The pre-Plan-09 test's scenario, restated to guard the mode-awareness: in
    // COARSE mode the genuinely-new segment "before the pour" has segment-start
    // 4800 == pending_max_end. The start-based rule would wrongly DROP it; the
    // legacy end-based rule (time_precise=false) keeps it. This must stay green.
    let mut f = Finalizer::default();
    let e0 = f.ingest(0, &[seg(0, 180, "the french drain"), seg(180, 480, "needs work")], 4_000);
    assert_eq!(words(&e0), vec!["the", "french", "drain"]);
    let e1 = f.ingest(4_000, &[seg(0, 80, "needs word"), seg(80, 400, "before the pour")], 8_000);
    let all: Vec<&str> = words(&e0).into_iter().chain(words(&e1)).collect();
    assert_eq!(all, vec!["the", "french", "drain", "needs", "work", "before", "the", "pour"]);
    assert!(!all.contains(&"word"));
}

#[test]
fn mismatched_word_count_falls_back_to_coarse() {
    // Count disagrees with text split → coarse fallback (time_precise=false), no panic,
    // text still matches the split, spans segment-coarse.
    let mut f = Finalizer::default();
    let bad = RawSegment::with_words(
        RawSegment { start_cs: 0, end_cs: 300, text: "alpha beta gamma".into(),
            no_speech_prob: 0.0, words: vec![] },
        vec![crate::decoder::WordTiming { text: "alpha".into(), start_cs: 0, end_cs: 100 }], // 1 ≠ 3
    );
    let out = f.ingest(0, &[bad], u64::MAX);
    assert_eq!(words(&out), vec!["alpha", "beta", "gamma"]);
    assert!(out.iter().all(|w| w.end_ms == 3000), "coarse fallback: all share segment end");
}

#[test]
fn no_speech_gate_still_drops_before_word_expansion() {
    // Plan 08 R3 gate untouched: a high-nsp WORD-TIMED segment is still dropped.
    let mut f = Finalizer::with_no_speech_threshold(0.6);
    let mut noisy = seg_words(0, 200, &[("phantom", 0, 100), ("words", 100, 200)]);
    noisy.no_speech_prob = 0.9;
    let out = f.ingest(0, &[noisy, seg_words(200, 320, &[("order", 200, 320)])], u64::MAX);
    assert_eq!(words(&out), vec!["order"], "drone dropped, speech kept (R3)");
}
```

(`words_full` = a small test helper returning the `&[Word]` slice, for the append-only monotonicity check; or reuse `e0`/`e1` directly since they are `Vec<Word>`.)

- [ ] **Step 2a — add `time_precise` to `Word`** and set it in `words_from_segments` (D4):

```rust
fn words_from_segments(window_start_ms: u64, segs: &[RawSegment], no_speech_threshold: f32) -> Vec<Word> {
    let mut out = Vec::new();
    let to_ms = |cs: i64| window_start_ms + (cs.max(0) as u64) * 10;
    for s in segs {
        if s.no_speech_prob > no_speech_threshold { continue; } // R3 gate — unchanged, runs FIRST
        let seg_start = to_ms(s.start_cs);
        let seg_end = to_ms(s.end_cs);
        let split: Vec<&str> = s.text.split_whitespace().collect();
        if !s.words.is_empty() && s.words.len() == split.len() {
            // Word-anchored: authoritative text from split, timing from words.
            let mut last_end = seg_start;
            for (tok, w) in split.iter().zip(&s.words) {
                let start = to_ms(w.start_cs).max(last_end);   // non-decreasing start
                let end = to_ms(w.end_cs).max(start);          // end ≥ start
                out.push(Word { text: (*tok).to_string(), start_ms: start, end_ms: end, time_precise: true });
                last_end = end;
            }
        } else {
            // Coarse fallback (empty words OR count mismatch) — pre-Plan-09 behavior.
            for tok in split {
                out.push(Word { text: tok.to_string(), start_ms: seg_start, end_ms: seg_end, time_precise: false });
            }
        }
    }
    out
}
```

- [ ] **Step 2b — the word-anchored drop in `merge`'s coarse seam** (the ONLY change to `merge`; text seam, `finalize_before`, `flush`, `preview` untouched):

```rust
// Coarse seam: no text match → drop the covered prefix, keep first decode.
let pending_max_end = self.pending.iter().map(|w| w.end_ms).max().unwrap_or(0);
self.pending.extend(new_words.into_iter().skip_while(|w| {
    if w.time_precise {
        // Word-precise: a word STARTING at/inside already-committed audio is a
        // re-decode (first-decode-wins; boundary-equality drops — R6 under-commit).
        w.start_ms <= pending_max_end
    } else {
        // Segment-coarse: legacy rule — coarse starts are unreliable, ends aren't.
        w.end_ms <= pending_max_end
    }
}));
```

- [ ] **Step 3 — update the CAVEAT doc comment** on `merge` (`finalize.rs:79–88`): the caveat is **resolved when word timing is present** via the word-anchored (`start_ms`) drop; the segment-coarse (`end_ms`) branch is now the explicit **degraded** path (empty/mismatched `words`). Document *why* the two branches key on different fields (D1: coarse starts are segment-shared and unreliable; precise ends are inflated by divergent re-decodes and unreliable) and the boundary-equality under-commit choice.

- [ ] **Step 4 — verify:** `cargo test -p stt finalize` — new tests plus **every** existing coarse test green unchanged (`append_only_holds_under_overlap_disagreement`, `overlap_word_is_finalized_exactly_once`, `finalizes_incrementally_across_time_shifted_windows`, `no_speech_segments_are_dropped_and_append_only_still_holds`, `flush_emits_only_the_bounded_tail`).

- [ ] **Step 5 — commit:** `git add -A && git commit -m "feat(stt): word-anchored Finalizer + start-keyed coarse-seam drop (fixes lumped-divergent duplication; coarse path + R3 gate + append-only intact)"`

---

### Task 3: stream-level word-anchored append-only regression test

**Files:** Modify `crates/stt/tests/stream_append_only.rs` and add a `lib.rs` stream test.

The finalizer unit tests prove the merge; this proves it end-to-end through `SttStream::poll`/`end` with a `ScriptedDecoder` scripting word-timed segments across a real window boundary.

- [ ] **Step 1 — failing test** (`stream_append_only.rs`): a two-window script where window 1 re-decodes the overlap **inside a longer lumped segment** with word timing; assert the finalized stream (a) contains the overlap phrase exactly once, (b) is monotonic in `start_ms`, (c) drops the divergent re-decode — the same guarantees as `poll_finalizes_incrementally_and_end_flushes_bounded_tail` but exercising the word-anchored path. Add a `seg_words` helper to the test file (its own `seg` helper at `:11` gains `words: vec![]`).

- [ ] **Step 2 — verify:** `cargo test -p stt --test stream_append_only`. Also confirm `cargo test -p stt` whole-crate is green.

- [ ] **Step 3 — commit:** `git add -A && git commit -m "test(stt): stream-level word-anchored append-only regression across a window boundary"`

---

### Task 4: `SttConfig.word_timestamps` knob (default on)

**Files:** Modify `crates/stt/src/lib.rs`.

- [ ] **Step 1 — failing test** (`lib.rs` `mod tests`):

```rust
#[test]
fn word_timestamps_defaults_on_and_is_overridable() {
    assert!(SttConfig::default().word_timestamps);
    let off = SttConfig { word_timestamps: false, ..SttConfig::default() };
    assert!(!off.word_timestamps);
    assert!(off.validate().is_ok(), "orthogonal to config validity");
}
```

- [ ] **Step 2 — implement:** add `pub word_timestamps: bool` to `SttConfig` (doc it per D5: default `true`, internal to the crate, backend-agnostic, no sim hazard, reversible), set `word_timestamps: true` in the `Default` impl. **No literal edits needed** — all `SttConfig { .. }` sites use `..default()` (D5). Do not touch `validate()`'s logic (the knob is orthogonal).

- [ ] **Step 3 — verify:** `cargo test -p stt` green (whisper feature off — this task adds no whisper code).

- [ ] **Step 4 — commit:** `git add -A && git commit -m "feat(stt): SttConfig.word_timestamps knob (default on, crate-internal)"`

---

### Task 5: `WhisperDecoder` populates `words` from token `t0`/`t1` (whisper-gated)

**Files:** Modify `crates/stt/src/whisper.rs`. **All behind `#[cfg(feature = "whisper")]`** — never in the CI build.

The decoder must thread `SttConfig.word_timestamps` in. `WhisperDecoder::open` currently takes `(model, language, use_gpu)`; extend it to also carry `word_timestamps` (store on the struct; `SttStream::with_model` passes `cfg.word_timestamps`).

- [ ] **Step 1 — implement `set_token_timestamps`:** in `decode`, after the existing `params.set_*` calls, add `params.set_token_timestamps(self.word_timestamps);`. (Leave `max_len`/`split_on_word` unset — D2.)

- [ ] **Step 2 — populate `words` from tokens.** After building `text`, when `self.word_timestamps` is on, reconstruct per-word timing from the segment's tokens:

```rust
// Group whisper tokens into words. Word boundaries are marked by a leading
// space in the token's text (BPE); special/timestamp tokens (empty or bracketed
// text) are skipped. Each word takes the FIRST sub-token's t0 and the LAST
// sub-token's t1 (centiseconds, chunk-relative — same units as start_cs/end_cs).
let words = if self.word_timestamps {
    build_word_timings(&seg)   // -> Vec<WordTiming>
} else {
    Vec::new()
};
```

`build_word_timings(seg: &WhisperSegment) -> Vec<WordTiming>`: iterate `0..seg.n_tokens()`, `seg.get_token(i)`, read `tok.to_str_lossy()` and `tok.token_data()` (`.t0`, `.t1`). Skip tokens whose trimmed text is empty or begins with `[` / `<|` (special/timestamp markers). Start a new word when the raw token text begins with a space (or on the first content token); append sub-tokens to the current word, extending `end_cs` to the sub-token's `t1`. Return the accumulated words. **The finalizer (D4) is the safety net** — if this grouping's count disagrees with `seg.text.split_whitespace().count()`, `words_from_segments` falls back to coarse, so an imperfect reconstruction degrades gracefully rather than corrupting output.

- [ ] **Step 3 — extend the `#[ignore]` real-model test** (`real_model_decodes_silence` neighbor): a new `#[ignore]`d test gated on `MURMUR_WHISPER_MODEL` that decodes a short **speech** WAV (path via a second env var, e.g. `MURMUR_WHISPER_SPEECH_WAV`, so no fixture is committed) with `word_timestamps: true` and asserts:
  - **count + monotonicity:** at least one returned segment has `words.len() == text.split_whitespace().count()` and non-decreasing `start_cs`/`end_cs`;
  - **per-word ground-truth spot-check (finding 2):** for a WAV with known content, a couple of named words (e.g. `"french"`, `"drain"`) land in `words` with `start_cs`/`end_cs` inside a tolerance window of their expected position (e.g. ±50 cs) — this catches gross BPE **mis-grouping** that the count guard alone (D3) would pass, without asserting exact whisper timings (which drift by model/quant).
  `#[ignore]` keeps it out of CI (no model). If a speech WAV is impractical for a given runner, the test skips the spot-check (env absent) and falls back to asserting the *silence* decode returns without error with the flag on (contract: "no crash with `token_timestamps` enabled"); word-population correctness is then validated by the Task 7 sweep on real audio (which the reviewer can hand-check against the transcript).

- [ ] **Step 4 — verify (dam, whisper feature, has a model):** `cargo test -p stt --features whisper` compiles; the ignored test runs manually with `MURMUR_WHISPER_MODEL=... cargo test -p stt --features whisper -- --ignored`. **CI verify:** `cargo test --workspace` (feature off) still green and never compiles this file.

- [ ] **Step 5 — commit:** `git add -A && git commit -m "feat(stt): WhisperDecoder token_timestamps → RawSegment.words (whisper-gated; finalizer self-heals on mismatch)"`

---

## Part B — Live-prompt eval pins

### Task 6: `run_live_scenario` + hermetic live-prompt pins

**Files:** Modify `crates/evals/src/run.rs`; create `crates/evals/tests/live_prompt_pins.rs` and `crates/evals/fixtures/live_prompt_golden.txt`.

Per D7: pin the assembled live prompt (the true regression gate) + a grader run over the live board (plumbing honesty).

- [ ] **Step 1 — `run_live_scenario` in `run.rs`:** a function that opens an in-memory store, appends the scenario transcript, drives a `LiveExtractor` (from `murmur_core`) with a supplied `MockProvider` (deterministic script) via `maybe_extract()` to catch-up (loop while `cursor() < len`, mirroring `carried_scenarios.rs`), then reads the board into `Observed` and returns `(ScenarioScore, assembled_prompt_text)`. Reuse `observe(..)`'s item-reading (extract a shared helper if cleaner). Capture the assembled prompt from `MockProvider::requests()[0]` (first user text block) — the same access pattern `carried_scenarios.rs` uses.

- [ ] **Step 2 — failing pin tests** (`crates/evals/tests/live_prompt_pins.rs`, hermetic):
  - **Golden prompt snapshot:** run `run_live_scenario` over one fixed corpus scenario (e.g. `punch_list_short`) with a canned `MockProvider` script; read the committed `fixtures/live_prompt_golden.txt`; assert the assembled prompt **equals** the golden (normalizing only trailing whitespace). A `MURMUR_BLESS=1` env escape rewrites the golden (documented in the test), so a deliberate prompt change is a conscious re-bless, an accidental one is a red test. First run: write the golden from the observed prompt, then assert.
  - **Grader-over-live-board:** assert the F0.5 of the live board against the scenario truth is a **fixed** value for the canned script (pins the plumbing: grader + swap-at-finish board reading). Use the existing `grade()` and assert an exact `f_half` (deterministic).

- [ ] **Step 3 — verify:** `cargo test -p evals live_prompt` (hermetic, no key).

- [ ] **Step 4 — commit:** `git add -A && git commit -m "feat(evals): hermetic live-prompt pins — golden assembled-prompt snapshot + grader-over-live-board (Plan 06a contract)"`

- [ ] **Step 5 — flag (docs, no code):** note in the task's PR thinking that non-circular F0.5 movement from live-prompt edits requires the gated real-API runner (`examples/eval.rs`) extended to the live path — **deferred** to the optimization-loop work, not built here (D7).

---

## Part C — Measurement (device/model-gated; dam)

### Task 7: rerun the SNR sweep with `token_timestamps` on; compare Table 4

**Files:** Modify `spikes/stt-whisper/src/sweep.rs`, `spikes/stt-whisper/src/main.rs`, `spikes/stt-whisper/RESULTS.md`. **Manual / not CI — flagged for dam (needs model files + `say` WAVs).**

`token_timestamps` should not move WER (D2/D5); this measures it.

- [ ] **Step 1 — thread a flag:** add `--token-timestamps` (default off) to the `sweep` flags; in `decode_with_nsp`, when set, call `params.set_token_timestamps(true)` on the params built by `make_params`. (If `make_params` is shared, add an overload or set the field after construction so the flag is sweep-local — do not change the default decode path of the other subcommands.) Update the `main.rs` usage line.

- [ ] **Step 2 — run the sweep both ways (dam, device):** run the existing sweep (baseline, flag off) and again with `--token-timestamps`; for each model × noise × SNR, diff WER (Table 4A) and record clean-decode wall-time to derive an RTF delta. Command shape:
  `stt-whisper-spike sweep --modeldir <dir> --audio <say.wav> --reference <ref.txt> [--token-timestamps]`

- [ ] **Step 3 — record in `RESULTS.md`:** add **Table 4A′** (token_timestamps-on WER vs SNR) beside the committed Table 4A, plus a one-line RTF-cost note and a verdict: does the default `word_timestamps: true` (D5) hold, or should it flip to `false`? This is the empirical sign-off for the D5 decision.

- [ ] **Step 4 — commit:** `git add -A && git commit -m "spike(stt): SNR sweep --token-timestamps flag + Table 4A' accuracy/RTF-delta rerun (dam, device)"`

---

## Part D — Docs & final review

### Task 8: docs + independent whole-artifact review

**Files:** `crates/stt/README.md` (or `docs/` STT notes), `meta/ROADMAP.md` (mark the accuracy-hardening threads), and the review itself.

- [ ] **Step 1 — docs:** update `crates/stt/README.md` to describe the word-timestamp path (default on, degrades to coarse) and the `word_timestamps` knob; add a ROADMAP note that thread 1 (word timestamps) landed and thread 2 (live-prompt pins) landed as scaffolding with the real-API live extension flagged. Confirm the `finalize.rs` CAVEAT doc update (Task 2 Step 3) reads correctly as "resolved when word timing present."

- [ ] **Step 2 — full hermetic gate:** run, from inside the dev shell, and paste real output (exit codes, not grep counts — MEMORY lesson):
  - `cargo test --workspace`
  - `cargo clippy --workspace --all-targets -- -D warnings`
  - confirm neither compiles the `whisper` feature (grep the build plan or rely on feature-off default).

- [ ] **Step 3 — independent whole-artifact review** (CANON: independent final review has caught a real issue 9/9 times; a **separate agent** from the builder). Read the diff `decoder.rs → finalize.rs → whisper.rs → evals` as one artifact and specifically re-check:
  - **Append-only is preserved by construction:** `finalize_before`/`flush`/`preview` and the **text seam** are byte-for-byte unchanged; the only `merge` change is the coarse-seam `skip_while` predicate branching on `time_precise` (D1). Verify the seam still only ever *drops a prefix of new words* (never revises pending), and hand-check the flagship + inflated-early-word arithmetic (the reviewer re-runs the drop trace).
  - **Mode-awareness is load-bearing:** precise words drop by `start_ms ≤ pending_max_end`, coarse words by `end_ms ≤ pending_max_end`. Re-verify the counter-example that forced this (D1): the segment-coarse genuinely-new word and the word-precise disputed word share `start_ms == pending_max_end` but need opposite treatment. `existing_segment_coarse_disagreement_still_keeps_new_suffix` must be green.
  - **Boundary-equality drops (R6 under-commit):** `start_ms == pending_max_end` resolves to drop in the precise branch; confirm this can't silently eat a run of legitimate contiguous new words outside the divergent-seam case (it only fires when the text seam already failed).
  - **R3 gate ordering:** the `no_speech_prob` drop runs *before* word expansion for both branches (Plan 08 must keep working; the sweep threshold basis is unchanged — D2).
  - **Degradation is total:** empty `words` AND count-mismatch both produce `time_precise=false` `Word`s with segment-coarse spans → the exact pre-Plan-09 coarse output; every existing coarse test green unchanged.
  - **BPE mis-grouping blast radius (D3):** a count-matching-but-mis-grouped reconstruction only skews timing on adjacent words (text authoritative via split-zip); confirm it can't corrupt text or append-only, and that Task 5's spot-check guards it on real audio.
  - **Units:** token `t0`/`t1` are centiseconds and use the identical `window_start_ms + cs*10` conversion — no ms/cs mixup (the reviewer hand-checks one word's arithmetic against a test).
  - **CI hermeticity:** no whisper symbol reachable from `cargo test --workspace`; `whisper.rs` changes are entirely `#[cfg(feature="whisper")]`.
  - **`t_dtw` is never read** (we use `t0`/`t1`), so no alignment-head model variant is silently required.
  - **Live pins are honest:** the golden snapshot is the real gate; the grader-over-mock assertion isn't oversold as measuring prompt quality (D7).
- [ ] **Step 4 — commit:** `git add -A && git commit -m "docs(stt): Plan 09 word-timestamp + live-pin notes; independent review sign-off"`

---

## Non-goals

- **`max_len`/`split_on_word` single-word-segment mode** (D2 rejected — would re-open the calibrated R3 threshold).
- **DTW timestamps (`t_dtw`) / alignment-head model variants** — we use the classic `t0`/`t1` path; no new model file.
- **FFI / Swift changes** — `FinalizedSegment` shape, `WalkEvent` cases, `push_audio`, and the shell are untouched; word timing only sharpens the `end_ms` already carried.
- **Surfacing `word_timestamps` to `EngineConfig`/Swift** (D5 — crate-internal, no sim hazard).
- **The live-prompt *optimization* loop / real-API live grading** (D7 — flagged; this plan is pin scaffolding only).
- **Streaming window/latency retuning, biasing changes, diarization, Android.**
- **Making the SNR sweep hermetic / CI** — it stays a manual device tool (D8).

## Acceptance criteria

1. `cargo test --workspace` and `cargo clippy --workspace --all-targets -- -D warnings` green **with the whisper feature off** (CI invariant); no whisper symbol compiled.
2. `RawSegment.words` is additive: every existing coarse test passes **unchanged**; `ScriptedDecoder` is not modified.
3. `Finalizer` emits word-precise `Word`s (`time_precise=true`) when `words` is present and **byte-identical** segment-coarse output (`time_precise=false`) when it is empty or count-mismatched; the coarse seam drops precise words by `start_ms ≤ pending_max_end` and coarse words by the legacy `end_ms ≤ pending_max_end`; the lumped-divergent-overlap duplication has a passing regression test (flagship + inflated-early-word), and the pre-Plan-09 segment-coarse disagreement test stays green (mode-awareness guard).
4. The Plan 08 `no_speech_prob` R3 gate and the append-only contract hold under word-timed input (dedicated tests).
5. `WhisperDecoder` (feature on) sets `token_timestamps` from `SttConfig.word_timestamps` (default true) and populates `words` from token `t0`/`t1`; the real-model check is `#[ignore]`d out of CI.
6. Hermetic live-prompt pins exist: a committed golden assembled-prompt snapshot (with a documented re-bless escape) + a deterministic grader-over-live-board assertion.
7. The SNR sweep accepts `--token-timestamps` and `RESULTS.md` records the WER/RTF delta + the D5 default verdict (dam, device — flagged).
8. Independent whole-artifact review (separate agent) signs off on the Task 8 Step 3 checklist.
