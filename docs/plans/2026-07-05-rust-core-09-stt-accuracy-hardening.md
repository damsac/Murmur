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

### D1. The fix is *precision fed into the existing merge*, not a new merge algorithm
The `Finalizer`'s two-seam merge (`finalize.rs::merge`) is unchanged. Today the **coarse (time) seam** drops the prefix of `new_words` whose `end_ms ≤ pending_max_end` — exact only when the decoder isolates the overlap in its own early-ending segment; when whisper lumps the overlap into a longer phrase-level segment, a divergent overlap can (a) duplicate (covering segment ends past `pending_max_end` → nothing dropped) or (b) drop genuinely-new words that share the covered segment's `end_ms` (the CAVEAT, `finalize.rs:79–88`). The **only** thing wrong is that `Word::end_ms` is segment-coarse. Give each `Word` its **own** `end_ms` and the *same* `skip_while(|w| w.end_ms <= pending_max_end)` becomes word-exact. So the entire change to the append-only path is inside `words_from_segments` (how a `RawSegment` expands into `Word`s); `merge` / `finalize_before` / `flush` / `preview` are byte-for-byte untouched. This is why append-only is preserved by construction: no committed word is revisited; we only change which `Word`s are computed at ingest.

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

### D4. `words_from_segments` prefers per-word timing, degrades safely, guards alignment
New logic, per segment (after the unchanged `no_speech_prob` drop):
- If `seg.words` is **empty** → today's behavior verbatim: split `text` on whitespace, every word gets the segment-coarse `start_ms`/`end_ms`.
- If `seg.words` is **non-empty AND** `seg.words.len() == seg.text.split_whitespace().count()` → emit one `Word` per whitespace token, taking `text` from the split (authoritative) and `start_ms`/`end_ms` from the aligned `WordTiming` via the identical `window_start_ms + cs*10` formula. Clamp so `end_ms ≥ start_ms` and each word's `end_ms` is non-decreasing within the segment (defends against a stray out-of-order token timestamp; whisper token times are monotonic in practice but we do not assume it).
- If `seg.words` is **non-empty but the count disagrees** → fall back to segment-coarse for that segment (self-heal) and it is a silent-correctness event worth a debug log, not a panic.

This keeps the emitted stream identical for all existing scripted tests (empty `words`) and word-precise for real whisper / word-scripted tests. The `no_speech_prob` gate runs first and is untouched.

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
      finalize.rs       # MODIFY: words_from_segments word-anchored expansion + alignment guard; update CAVEAT doc; new tests
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

### Task 2: `Finalizer` word-anchored expansion + the coarse-seam fix

**Files:** Modify `crates/stt/src/finalize.rs`.

This is the heart of the plan: give each `Word` its own `end_ms` so the unchanged coarse (time) seam becomes word-exact, and prove the CAVEAT failure mode is fixed while append-only + the no-speech gate hold.

- [ ] **Step 1 — failing tests** (add to `finalize.rs` `mod tests`; keep a `seg_words(..)` helper that builds a `RawSegment` with `WordTiming`s):

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
fn coarse_seam_is_word_exact_when_overlap_is_lumped_into_a_long_segment() {
    // The CAVEAT case (finalize.rs:79–88): whisper lumps the re-decoded overlap
    // into a LONGER phrase-level segment. With word timing the coarse seam drops
    // exactly the covered words and keeps the genuinely-new suffix.
    let mut f = Finalizer::default();
    // W0: "the french drain" finalized (ends ≤4000), "needs work" held (word ends 4400/4800).
    let e0 = f.ingest(0, &[
        seg_words(0, 360, &[("the", 0, 100), ("french", 100, 240), ("drain", 240, 360)]),
        seg_words(360, 480, &[("needs", 360, 440), ("work", 440, 480)]),
    ], 4_000);
    assert_eq!(words(&e0), vec!["the", "french", "drain"]);
    // W1: overlap "needs work" re-decoded DIFFERENTLY ("needs word") but now LUMPED
    // with new text into ONE long segment [0,4000ms rel = 4000..8000 abs]. Per-word
    // timing lets the seam drop only the two covered words (end ≤ 4800), not the tail.
    let e1 = f.ingest(4_000, &[seg_words(0, 400, &[
        ("needs", 0, 80), ("word", 80, 160), ("before", 160, 260), ("the", 260, 330), ("pour", 330, 400),
    ])], 8_000);
    let all: Vec<&str> = words(&e0).into_iter().chain(words(&e1)).collect();
    assert_eq!(all, vec!["the", "french", "drain", "needs", "work", "before", "the", "pour"]);
    assert!(!all.contains(&"word"), "divergent re-decode dropped word-exactly");
    assert_eq!(all.iter().filter(|w| **w == "work").count(), 1, "no duplication");
}

#[test]
fn empty_word_timing_degrades_to_segment_coarse() {
    // The existing coarse tests still pass because seg(..) leaves words empty.
    let mut f = Finalizer::default();
    let out = f.ingest(0, &[seg(0, 480, "needs work")], u64::MAX);
    assert_eq!(out[0].end_ms, 4800, "coarse: both share segment end");
    assert_eq!(out[1].end_ms, 4800);
}

#[test]
fn mismatched_word_count_falls_back_to_coarse() {
    // Defensive: word timing count disagrees with text split → coarse fallback,
    // no panic, emitted text still matches the segment split.
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
    // Plan 08 R3 gate is untouched: a high-nsp WORD-TIMED segment is still dropped.
    let mut f = Finalizer::with_no_speech_threshold(0.6);
    let mut noisy = seg_words(0, 200, &[("phantom", 0, 100), ("words", 100, 200)]);
    noisy.no_speech_prob = 0.9;
    let out = f.ingest(0, &[noisy, seg_words(200, 320, &[("order", 200, 320)])], u64::MAX);
    assert_eq!(words(&out), vec!["order"], "drone dropped, speech kept (R3)");
}
```

- [ ] **Step 2 — implement:** rewrite `words_from_segments` per D4. Skeleton:

```rust
fn words_from_segments(window_start_ms: u64, segs: &[RawSegment], no_speech_threshold: f32) -> Vec<Word> {
    let mut out = Vec::new();
    let to_ms = |cs: i64| window_start_ms + (cs.max(0) as u64) * 10;
    for s in segs {
        if s.no_speech_prob > no_speech_threshold { continue; } // R3 gate — unchanged, runs first
        let seg_start = to_ms(s.start_cs);
        let seg_end = to_ms(s.end_cs);
        let split: Vec<&str> = s.text.split_whitespace().collect();
        if !s.words.is_empty() && s.words.len() == split.len() {
            // Word-anchored: authoritative text from split, timing from words.
            let mut last_end = seg_start;
            for (tok, w) in split.iter().zip(&s.words) {
                let start = to_ms(w.start_cs).max(last_end);        // non-decreasing
                let end = to_ms(w.end_cs).max(start);                // end ≥ start
                out.push(Word { text: (*tok).to_string(), start_ms: start, end_ms: end });
                last_end = end;
            }
        } else {
            // Coarse fallback (empty words OR count mismatch) — today's behavior.
            for tok in split { out.push(Word { text: tok.to_string(), start_ms: seg_start, end_ms: seg_end }); }
        }
    }
    out
}
```

Note the non-decreasing/`end ≥ start` clamps (D4). **Do not touch** `merge`, `finalize_before`, `flush`, or `preview`.

- [ ] **Step 3 — update the CAVEAT doc comment** on `merge` (`finalize.rs:79–88`): the caveat is now resolved *when word timing is present*, and the fallback prose should say the segment-coarse behavior is the **degraded** path (empty `words`), not the only path. Keep the description of the coarse seam mechanics (it is still the algorithm; only the input precision changed).

- [ ] **Step 4 — verify:** `cargo test -p stt finalize` (new + all existing coarse tests green — `append_only_holds_under_overlap_disagreement`, `no_speech_segments_are_dropped_and_append_only_still_holds`, etc. must stay green unchanged).

- [ ] **Step 5 — commit:** `git add -A && git commit -m "feat(stt): word-anchored Finalizer expansion — coarse-seam fix, degrades to segment-coarse (R3 gate + append-only intact)"`

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

- [ ] **Step 3 — extend the `#[ignore]` real-model test** (`real_model_decodes_silence` neighbor): a new `#[ignore]`d test gated on `MURMUR_WHISPER_MODEL` that decodes a short **speech** WAV (or reuses the spike's `say` clip if available via env) with `word_timestamps: true` and asserts at least one returned segment has `words.len() == text.split_whitespace().count()` and monotonic non-decreasing `end_cs`. `#[ignore]` keeps it out of CI (no model). If a speech fixture is impractical, assert instead that the *silence* decode returns without error with the flag on (contract: "no crash / no panic with token_timestamps enabled") and document that word-population is validated by the Task 6 sweep on real audio.

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
  - **Append-only is preserved by construction:** `merge`/`finalize_before`/`flush` are byte-for-byte unchanged; only `words_from_segments` computes different `Word` spans. Verify no path lets a per-word `end_ms` go *backwards* across the pending boundary in a way that could re-drop a committed word.
  - **R3 gate ordering:** the `no_speech_prob` drop runs *before* word expansion for both the coarse and word-anchored branches (Plan 08 must keep working; the sweep threshold basis is unchanged — D2).
  - **Degradation is total:** empty `words` AND count-mismatch both reach the exact pre-Plan-09 coarse output; every existing coarse test is green unchanged.
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
3. `Finalizer` emits word-precise `end_ms` when `words` is present and **byte-identical** segment-coarse output when it is empty or count-mismatched; the CAVEAT duplicate/drop failure mode has a passing regression test.
4. The Plan 08 `no_speech_prob` R3 gate and the append-only contract hold under word-timed input (dedicated tests).
5. `WhisperDecoder` (feature on) sets `token_timestamps` from `SttConfig.word_timestamps` (default true) and populates `words` from token `t0`/`t1`; the real-model check is `#[ignore]`d out of CI.
6. Hermetic live-prompt pins exist: a committed golden assembled-prompt snapshot (with a documented re-bless escape) + a deterministic grader-over-live-board assertion.
7. The SNR sweep accepts `--token-timestamps` and `RESULTS.md` records the WER/RTF delta + the D5 default verdict (dam, device — flagged).
8. Independent whole-artifact review (separate agent) signs off on the Task 8 Step 3 checklist.
