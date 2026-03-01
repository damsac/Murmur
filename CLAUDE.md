# Murmur

Voice-to-structured-data iOS app. Speak into your phone, get organized entries (todos, notes, ideas) extracted by an LLM.

## Quick Start

```bash
direnv allow              # Enter Nix dev shell (provides xcodegen, swiftlint, xcbeautify)
make setup                # Check tools + create project.local.yml from template
# Edit project.local.yml with your Apple Team ID
make build                # Generate Xcode project + build for simulator
make run                  # Build, install, and launch on simulator
```

## Architecture

Two-layer project:

- **Murmur/** — SwiftUI iOS app (Xcode via XcodeGen)
- **Packages/MurmurCore/** — Swift package with transcription pipeline, LLM service, and data models

The Xcode project (`Murmur.xcodeproj`) is generated from `project.yml` — never edit it directly. Per-developer settings (Team ID, bundle ID, API keys) live in `project.local.yml` (gitignored).

## Make Targets

All development commands go through `make`. Run `make help` to see everything.

### App (Xcode)
| Command | What it does |
|---------|-------------|
| `make setup` | First-time setup: check tools, create config |
| `make generate` | Generate Xcode project from project.yml |
| `make build` | Generate + build for simulator |
| `make test` | Generate + run unit tests |
| `make run` | Build + install + launch on simulator |
| `make lint` | Lint Swift sources with SwiftLint |
| `make clean` | Remove build artifacts |

### Simulator
| Command | What it does |
|---------|-------------|
| `make sim-boot` | Boot the iOS simulator |
| `make sim-shutdown` | Shutdown all running simulators |
| `make sim-list` | List available iPhone simulators |
| `make sim-screenshot` | Screenshot the running simulator to `screenshots/` |

### MurmurCore (SPM)
| Command | What it does |
|---------|-------------|
| `make core-build` | Build MurmurCore package |
| `make core-test` | Run MurmurCore unit tests |
| `make core-repl` | Interactive REPL for transcription testing |
| `make core-scenarios` | Run LLM scenario tests (needs PPQ_API_KEY) |
| `make core-clean` | Clean MurmurCore build artifacts |

## Key Files

| File | Purpose |
|------|---------|
| `project.yml` | XcodeGen project spec (source of truth for Xcode project) |
| `project.local.yml` | Per-developer settings: Team ID, bundle IDs, API keys (gitignored) |
| `project.local.yml.template` | Template for project.local.yml |
| `flake.nix` | Nix dev shell: provides xcodegen, swiftlint, xcbeautify, git hooks |
| `Packages/MurmurCore/swift-clean` | Wrapper script that runs Swift without Nix SDK interference |

## Dev Shell (Nix)

The project uses a Nix flake for reproducible tooling. `direnv allow` activates it automatically. The dev shell provides:
- **xcodegen** — generates Xcode project from project.yml
- **swiftlint** — Swift linter
- **xcbeautify** — pretty xcodebuild output
- **git hooks** — pre-commit (lint + entitlements check), post-merge (auto-regenerate)

## Collaboration (dam + sac)

This project is built by **damsac** — two collaborators (dam and sac) working with Claude Code.

The `meta/` directory at the project root is the collaboration hub:

| File | Purpose |
|------|---------|
| `meta/CANON.md` | Shared decisions both have agreed on |
| `meta/ROADMAP.md` | Shared priorities and sequencing |
| `meta/WORKFLOWS.md` | How dam and sac work together |
| `meta/RECONCILIATION.md` | PR review protocol (review thinking, not code) |
| `meta/dam/STATE.md` | What dam is working on right now |
| `meta/sac/STATE.md` | What sac is working on right now |
| `meta/dam/PROCESS.md` | How dam works with Claude |
| `meta/sac/PROCESS.md` | How sac works with Claude |

**Key principle:** PRs must include a **Thinking** section. Reviewers read thinking first, code second. If the thinking is sound, the code follows.

**Session start:** Always read the other person's STATE.md and check CANON.md before working.

## Conventions

- Default simulator: **iPhone 17 Pro** (override with `make build SIM_NAME="iPhone 16"`)
- Xcode project is always regenerated before build/test (the `generate` target is a dependency)
- MurmurCore uses `swift-clean` wrapper to avoid Nix SDK conflicts with Xcode's toolchain
- `PPQ_API_KEY` in project.local.yml is passed to the app at build time via Info.plist
