# Murmur (rebuild)

AI meeting notes for blue-collar field work. Rust core workspace.

- `crates/harness` — reusable agent harness (no app-specific logic)
- `crates/murmur-core` — domain entities + sync-ready SQLite storage (single-writer API, tombstones, UUIDv7)
- `crates/ffi` — UniFFI bridge crate (proc-macro mode); the only crate with a binding-generator dependency

Vision spec + plan series live in the Murmur meta repo under `docs/superpowers/`.

## Testing

`cargo test` — all tests are hermetic (MockProvider or wiremock); no network, no API keys.

## Plan series

Implementation plans 01–06 live in the Murmur meta repo at `docs/superpowers/plans/2026-07-01-rust-core-*.md`.
Done: 01 foundation, 02 memory + reflection + context assembler, 03 domain + storage, 04 processing pipeline + reflection coordinator, 05 live extraction, 05b eval suite, 06a source column + swap fix, 06 STT crate, 06-spike STT whisper-rs benchmark spike, 07 FFI bridge (Rust side + demo-path Swift changes; the iOS xcframework/package wiring is blocked on adding an iOS cross-compilation target to this repo's Nix toolchain — see the Plan 07 landing notes).
Next: STT stage 2 wiring (crates/stt behind the FFI's append_audio, additive), the generative layout-ops protocol (de-scoped from 07), and closing Plan 07's iOS toolchain gap.

Evals: `cargo test -p evals` (hermetic, no key). Real-API:
`ANTHROPIC_API_KEY=sk-... cargo run -p evals --example eval -- --out report.json`.
