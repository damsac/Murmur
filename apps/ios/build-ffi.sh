#!/usr/bin/env bash
# Regenerates apps/ios/Packages/MurmurCoreFFI's binary artifacts:
#   - crates/ffi built for aarch64-apple-ios-sim and aarch64-apple-ios
#   - Swift bindings generated via the uniffi-bindgen dev binary
#   - Frameworks/ffiFFI.xcframework (device + sim slices)
#
# These artifacts are GITIGNORED (large binaries); Sources/MurmurCoreFFI/ffi.swift
# and Package.swift ARE committed. Run this after any crates/ffi surface change,
# or any time Frameworks/ffiFFI.xcframework is missing.
#
# Why this isn't `nix develop -c cargo build --target ...` alone (Plan 07
# Task 9 / flake.nix multi-target toolchain): the nix-wrapped clang/cc-wrapper
# hardcodes macOS SDK paths and a `-mmacos-version-min` flag that conflicts
# with `-target arm64-apple-ios...-simulator`, and its default library search
# resolves against the MacOSX SDK's libiconv.tbd even when --target is iOS,
# which fails at the final link step ("building for iOS Simulator, but
# linking in .tbd built for macOS/Mac Catalyst"). The fix used here: keep the
# nix devShell's rust-overlay toolchain (cargo/rustc/clippy — unchanged, still
# the single source for host builds and `cargo test --workspace`), but for the
# iOS cross builds only, point CC/AR/the linker at the *system* Xcode
# toolchain (`/usr/bin/clang`, `/usr/bin/ar`) and SDKROOT at the real
# iphoneos/iphonesimulator SDK via `xcrun`. This is the "system Xcode
# fallback" path referenced in the Plan 07 Task 9 report — the pure-nix path
# (unset SDKROOT/NIX_*FLAGS only) still fails on SDK linkage.
#
# ---------------------------------------------------------------------------
# Options
#   --features "<list>"  cargo features for crates/ffi (default: "whisper").
#   --device-only        build only the aarch64-apple-ios (device) slice and a
#                        device-only xcframework. Skips the simulator slice —
#                        halves the expensive whisper.cpp/Metal compile. Use in
#                        CI (a TestFlight archive is device-only anyway). Local
#                        default builds BOTH slices so the simulator still runs.
#
# Nix vs no-nix: the cross-build blocks below point CC/AR/linker at the *system*
# Xcode toolchain and unset the nix cc-wrapper flags, so the exact same commands
# work whether or not nix is present. On a machine WITH nix (nous) they run
# inside `nix develop` (pinned rust toolchain, cmake); on a GitHub runner WITHOUT
# nix they run against rustup's cargo + brew's cmake directly. `dev` picks the
# right wrapper.
set -euo pipefail

FEATURES="whisper"
DEVICE_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --features) FEATURES="$2"; shift 2 ;;
    --features=*) FEATURES="${1#*=}"; shift ;;
    --device-only) DEVICE_ONLY=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Run a command inside the nix dev shell when nix is available (nous), or
# directly otherwise (GitHub runner: rustup cargo + brew cmake on PATH).
dev() {
  if command -v nix >/dev/null 2>&1; then
    nix develop -c "$@"
  else
    "$@"
  fi
}

cd "$(dirname "$0")/../.."   # repo root
FFI_DIR="apps/ios/Packages/MurmurCoreFFI"
BINDINGS_DIR="$(mktemp -d)"
trap 'rm -rf "$BINDINGS_DIR"' EXIT

# Cross-build env is passed through to the inner shell via the environment.
export FEATURES

if [ "$DEVICE_ONLY" -eq 0 ]; then
echo "==> building crates/ffi for aarch64-apple-ios-sim"
dev bash -c '
  set -euo pipefail
  export DEVELOPER_DIR="${XCODE_DEVELOPER_DIR:-$(env -u DEVELOPER_DIR /usr/bin/xcode-select -p)}"
  export SDKROOT=$(/usr/bin/xcrun --sdk iphonesimulator --show-sdk-path)
  # Match the app deployment target (project.yml: iOS 17.0). Without this, rustc
  # links the cdylib probe at its default min (arm64-apple-ios10.0), and the
  # whisper.cpp objects that cmake built against the real iOS SDK min fail to
  # link with a missing ___chkstk_darwin symbol for architecture arm64.
  export IPHONEOS_DEPLOYMENT_TARGET=17.0
  export CC_aarch64_apple_ios_sim=/usr/bin/clang
  export CXX_aarch64_apple_ios_sim=/usr/bin/clang++
  export AR_aarch64_apple_ios_sim=/usr/bin/ar
  export CARGO_TARGET_AARCH64_APPLE_IOS_SIM_LINKER=/usr/bin/clang
  unset NIX_CFLAGS_COMPILE NIX_LDFLAGS NIX_CFLAGS_COMPILE_FOR_BUILD NIX_LDFLAGS_FOR_BUILD
  # --features whisper: pulls whisper-rs + vendored whisper.cpp + Metal (Plan 08
  # Task 8). Needs cmake/clang (dev shell, Plan 06 Task 1). The vendored
  # whisper.cpp Metal shaders compile against the iphonesimulator SDK via the
  # SDKROOT/system-clang cross-link set above. `cargo test --workspace` never
  # sees this feature — it stays hermetic (no model, no cmake, no Metal).
  cargo build -p ffi --release --target aarch64-apple-ios-sim --features "$FEATURES"
'
fi

echo "==> building crates/ffi for aarch64-apple-ios (device)"
dev bash -c '
  set -euo pipefail
  export DEVELOPER_DIR="${XCODE_DEVELOPER_DIR:-$(env -u DEVELOPER_DIR /usr/bin/xcode-select -p)}"
  export SDKROOT=$(/usr/bin/xcrun --sdk iphoneos --show-sdk-path)
  # Match the app deployment target (project.yml: iOS 17.0) — see the sim
  # invocation above; without it the device cdylib link fails on a missing
  # ___chkstk_darwin symbol for architecture arm64.
  export IPHONEOS_DEPLOYMENT_TARGET=17.0
  export CC_aarch64_apple_ios=/usr/bin/clang
  export CXX_aarch64_apple_ios=/usr/bin/clang++
  export AR_aarch64_apple_ios=/usr/bin/ar
  export CARGO_TARGET_AARCH64_APPLE_IOS_LINKER=/usr/bin/clang
  unset NIX_CFLAGS_COMPILE NIX_LDFLAGS NIX_CFLAGS_COMPILE_FOR_BUILD NIX_LDFLAGS_FOR_BUILD
  # --features whisper (device slice) — see the sim invocation above.
  cargo build -p ffi --release --target aarch64-apple-ios --features "$FEATURES"
'

# Bindgen reads symbols from a built static lib; either slice works. Prefer the
# sim slice when it exists, else the device slice (--device-only).
BINDGEN_LIB="target/aarch64-apple-ios-sim/release/libffi.a"
[ -f "$BINDGEN_LIB" ] || BINDGEN_LIB="target/aarch64-apple-ios/release/libffi.a"

echo "==> generating Swift bindings (uniffi-bindgen, host build)"
dev cargo run -p ffi --features uniffi-bindgen-cli --bin uniffi-bindgen -- \
  generate --library "$BINDGEN_LIB" \
  --language swift --out-dir "$BINDINGS_DIR"

cp "$BINDINGS_DIR/ffi.swift" "$FFI_DIR/Sources/MurmurCoreFFI/ffi.swift"

echo "==> assembling ffiFFI.xcframework"
rm -rf "$FFI_DIR/Frameworks/ffiFFI.xcframework"

# Slices to include: always device; sim too unless --device-only.
SLICES=(device)
[ "$DEVICE_ONLY" -eq 0 ] && SLICES=(sim device)

XCF_ARGS=()
for slice in "${SLICES[@]}"; do
  hdir="$BINDINGS_DIR/headers-$slice"
  mkdir -p "$hdir"
  cp "$BINDINGS_DIR/ffiFFI.h" "$hdir/"
  cp "$BINDINGS_DIR/ffiFFI.modulemap" "$hdir/module.modulemap"
  case "$slice" in
    sim)    lib="target/aarch64-apple-ios-sim/release/libffi.a" ;;
    device) lib="target/aarch64-apple-ios/release/libffi.a" ;;
  esac
  XCF_ARGS+=(-library "$lib" -headers "$hdir")
done

xcodebuild -create-xcframework \
  "${XCF_ARGS[@]}" \
  -output "$FFI_DIR/Frameworks/ffiFFI.xcframework"

# ---------------------------------------------------------------------------
# Whisper model provisioning (Plan 08 D5/Task 8)
# ---------------------------------------------------------------------------
# The FFI libs are now built WITH the `whisper` feature, so the app can run
# on-device STT. It needs a GGML model bundled as an APP-TARGET resource:
#
#   ggml-small.en-q5_1.bin  (~190 MB, MIT, huggingface.co/ggerganov/whisper.cpp)
#     — the default (small.en promotion; see fetch-whisper-model.sh header for
#     the RTF/WER rationale and the iPhone-T5-unproven caveat)
#   ggml-base.en-q5_1.bin   (~60 MB) — the one-arg revert (STT_MODEL=base.en)
#
# Both binaries are GITIGNORED (large — like the xcframework), sha256-pinned,
# and fetched/cache-verified by ./fetch-whisper-model.sh (called automatically
# from ./generate.sh, which runs after this script). Manual fetch:
#
#   ./fetch-whisper-model.sh            # default: small.en
#   ./fetch-whisper-model.sh base.en    # revert
#
# WHY Sources/Resources and NOT Packages/MurmurCoreFFI/Resources: SwiftPM
# package resources land in `Bundle.module` (the package's resource bundle),
# but GalleryApp.resolveEngine resolves the model via `Bundle.main.path(
# forResource: "ggml-<model>-q5_1", ofType: "bin")` — the APP bundle. A model
# placed in the package would silently never resolve. The app-target `Sources`
# glob (picked up by both project.yml and project-real.yml) is the mechanism
# that actually works — verified on the simulator. If neither model is present
# the live walk degrades to text-only — no crash (the Rust side treats a nil
# path as text-only); ./generate.sh prints a NOTE when the fetch fails. Keep
# CODE_SIGNING_ALLOWED: NO for the simulator.
#
# NOTE: the tracked demo spec (project.yml) deliberately does NOT bundle the
# model — a clean checkout must build the scripted DemoWalkEngine app from that
# file alone (no ~60 MB gitignored dependency). The model rides the real build.

echo "==> done. Run 'cd apps/ios && xcodegen generate' next."
