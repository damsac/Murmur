# STT whisper.cpp Rust-side spike — RESULTS

**The deliverable of Plan 06-spike.** Decides dam's stated preference — *"go straight to
whisper.cpp Rust-side only"* (Option B) — against measured evidence, vs. the staged-hybrid
fallback (Option C: Apple `SpeechAnalyzer` for v1).

- **Host:** Apple Silicon Mac (dam's dev machine), macOS. Metal backend.
- **Engine:** `whisper-rs =0.16.0` (pinned) → `whisper-rs-sys 0.15.0` → vendored whisper.cpp.
- **Status:** Mac tiers (T0–T4, T6) executed by the spike worker. iPhone tier (T5) **pending — needs dam's device.**

---

## Table 1 — Feasibility & performance (Mac, Apple Silicon, Metal backend)

| Model | Quant | Size (MB) | Load (s) | RTF | Peak RSS (MB) | Backend | Notes |
|-------|-------|-----------|----------|-----|---------------|--------|-------|
| tiny.en | q5_1 | | | | | metal | |
| base.en | q5_1 | | | | | metal | |
| small.en | q5_1 | | | | | metal | |
| large-v3-turbo | q5_0 | | | | | metal | |
| distil-large-v3 | q5_0 | | | | | metal | |

> RTF = wall-clock decode time ÷ audio duration, measured on the **second** decode (first is a
> discarded Metal-shader-JIT warm-up). RTF < 1.0 = faster than real-time. Peak RSS from
> `getrusage` `ru_maxrss` (**bytes** on macOS).

## Table 2 — Streaming / append-only (chosen model from Table 1)

| Chunk (s) | Overlap (s) | Boundary re-transcription % | Finalize latency (s) | Append-only derivable? | Notes |
|-----------|-------------|-----------------------------|----------------------|------------------------|-------|

## Table 3 — Accuracy & biasing (per model × condition)

| Model | Audio clip | Noise cond. | WER % | Target-term recall (no bias) | Target-term recall (initial_prompt) | Recall Δ (pp) | Hallucination flag | Notes |
|-------|-----------|-------------|-------|------------------------------|-------------------------------------|---------------|--------------------|-------|

## Table 4 — iPhone tier (optional, real device)

**PENDING — not run.** Requires dam's physical iPhone (T5, hardware-gated). The iOS simulator
is explicitly insufficient (no Metal/ANE, no real battery/thermal). See `ios/README.md` for the
build recipe (whisper.cpp's bundled `examples/whisper.swiftui`, path B — no UniFFI).

| Device | iOS | Model | RTF | Battery Δ (%/10 min) | Thermal state @ 10 min | Killed in background? | Notes |
|--------|-----|-------|-----|----------------------|------------------------|-----------------------|-------|
| — | — | — | — | — | — | — | pending device |

---

## Feasibility (kill-question 1)

**PASS — `whisper-rs =0.16.0` with the `metal` feature builds and runs on this Apple Silicon Mac.**

- `nix-shell` (spike-local `shell.nix`: `cargo rustc cmake clang` + `LIBCLANG_PATH`) built the
  full native stack cleanly: `whisper-rs-sys 0.15.0` compiled vendored whisper.cpp via cmake +
  bindgen; `stt-whisper-spike` linked and ran. Release build: ~32 s cold.
- **Environment note (not KILL evidence):** the plan's `shell.nix` uses `import <nixpkgs>`, but
  this machine is a channel-less flake system — `<nixpkgs>` is not on `NIX_PATH`. Bare
  `nix-shell` fails with *"file 'nixpkgs' was not found in the Nix search path."* Resolved by
  invoking `nix-shell -I nixpkgs=flake:nixpkgs` (resolves nixpkgs via the flake registry). The
  system Xcode CLI-tools fallback was therefore **not needed** — the nix path works. Recorded
  because it's a real friction for reproducing the spike shell on this host.

---

## Decision

_(Filled in Task 6 against the exit criteria.)_

---

## Attribution

- **whisper.cpp** — MIT. Vendored by `whisper-rs-sys` as a git submodule.
- **whisper-rs** (tazz4843) `=0.16.0` — MIT. https://crates.io/crates/whisper-rs
- **whisper-rs-sys** `0.15.0` — MIT.
- **hound** `3.5.1` — MIT/Apache-2.0.
- ggml Whisper models — see model download section below (filled in Task 1).
