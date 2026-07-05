# stt

On-device streaming speech-to-text over whisper.cpp (spec Rev 2 §2). See
`crates/stt/src/lib.rs` for the module-level docs and API sketch in
`docs/plans/2026-07-04-rust-core-06-stt-crate.md`.

## Models

The crate opens a ggml whisper model the **shell** provisions (download/on-demand-resources
is not the crate's job). v1 target files (MIT, from `huggingface.co/ggerganov/whisper.cpp`;
`ggml-org` returns 401 today — spike note):

- `ggml-base.en-q5_1.bin` (~57 MB) — default; RTF 0.009, WER 5.8% clean.
- `ggml-small.en-q5_1.bin` (~182 MB) — higher accuracy; RTF 0.021, WER 4.7% clean.

Selection (base vs small, quality vs size/battery) is a shell/config decision, informed
by the pending on-device iPhone tier (`RESULTS.md` Table 4).

## Word-level timestamps (Plan 09)

The `Finalizer`'s overlap-merge has two seams: a precise TEXT seam (identical
re-decode stitched exactly) and a COARSE fallback for a divergent overlap. When
whisper `token_timestamps` are on (`SttConfig.word_timestamps`, **default true**,
crate-internal — not surfaced to Swift/`EngineConfig`), `WhisperDecoder`
reconstructs per-word timing from token `t0`/`t1` onto `RawSegment.words`, and
the coarse seam becomes **word-anchored**: a word STARTING at/inside
already-committed audio (`start_ms ≤ pending_max_end`) is dropped as a re-decode
(first-decode-wins), which fixes the lumped-divergent-overlap duplication the old
segment-coarse `end_ms` rule could leak.

The path **degrades safely**: when `words` is empty (`ScriptedDecoder`, any
non-whisper decoder) OR its count disagrees with the segment's whitespace split,
the finalizer falls back to the pre-Plan-09 segment-coarse spans and the legacy
`end_ms`-keyed drop — byte-for-byte the old behavior. Word text is always
authoritative (from the split, never token reconstruction); the timing is
best-effort. Flip `word_timestamps` to `false` to disable with no other change
(the SNR sweep, Task 7, is the empirical WER/RTF sign-off for the default).

## Integration with `murmur-core` (deferred to Plan 07 — the FFI/shell tick loop)

`crates/stt` and `murmur-core` do **not** depend on each other. The shell owns both pumps
and wires them:

```
// shell background thread, on cadence:
stt.push_pcm(pcm);                                  // audio thread hands off buffers
for seg in stt.poll()? {                            // append-only finalized segments
    store.append_transcript(&session_id, &format!("{} ", seg.text))?;
}
live_extractor.maybe_extract().await?;              // Plan 05: cursor advances over new transcript
// on DONE:
for seg in stt.end()? { store.append_transcript(&session_id, &format!("{} ", seg.text))?; }
// then queue end-of-session process() — the AUTHORITATIVE pass (Plan 04).
```

Why deferred, not built here: (1) cadence is shell policy (Plan 05 Deferred 3 already put
the LiveExtractor tick in the shell); (2) both `stt.poll` and `LiveExtractor.maybe_extract`
are shell-driven pumps with no core-side coupling (Plan 05 self-review constraint 4);
(3) building it here forces an `stt ↔ murmur-core` dependency both plans avoid. The
contract above is the whole seam — Plan 07 implements it across UniFFI.
