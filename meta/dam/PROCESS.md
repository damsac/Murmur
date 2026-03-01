# Dam's Process

How dam works with Claude. Conventions, preferences, patterns.

---

## Working style

- Architecture-first. Designs the system before implementing.
- SwiftUI iOS app with MurmurCore Swift package.
- Uses Claude Code on macOS (nous) with Nix-managed tooling.
- Leans on meta-agent thinking: define the process, then execute.

## Claude configuration

- **Host:** nous (macOS/Darwin)
- **Shell:** zsh via Home Manager
- **Dev shell:** Nix flake with direnv
- **Skills:** skill-creator, meta-workflow, icon-generator, genesis, session-lifecycle, tmux-lanes, gather
- **XcodeBuildMCP:** Preferred over shell commands for Xcode/simulator ops

## Session habits

- Starts with `/start` to sync and pick up work
- Uses `/status` to check state before diving in
- Ships with `/ship` when work is ready
- Documents sessions with `/meta-workflow` after non-trivial PRs

## Preferences

- Concise communication, no ceremony
- Commit messages: `type: description` — no footers
- Plans before builds. Brainstorms before plans.
- Thinks in terms of data flow and state machines (TEA architecture)
