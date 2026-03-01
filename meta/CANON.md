# Canon

Shared source of truth between dam and sac. Every entry here has been explicitly agreed on by both. If it's not in this file, it's not canonical.

Updated via PR. Changes to this file require review from the other person.

---

## Architecture

- **Two-layer project:** SwiftUI iOS app (`Murmur/`) + Swift package (`Packages/MurmurCore/`)
- **LLM provider:** Currently PPQ.ai. Architecture supports swapping to any provider.
- **Xcode project generated** from `project.yml` via XcodeGen — never edit `.xcodeproj` directly
- **Per-developer settings** in `project.local.yml` (gitignored)

## Product

- **What Murmur is:** An autonomous second brain. You speak, and an agent captures, organizes, surfaces, and acts on your entries. Not a transcription app — a thinking partner that manages your mental load.
- **Core insight:** Capture first, categorize automatically. The agent doesn't just structure your input — it actively curates what you need to see and when.
- **Entry model:** The atomic unit is `Entry`. Category (todo, idea, reminder, note, list, habit, question, thought) carries the semantic weight.
- **Agent-first UI:** Three layers — smart list (flat, agent-curated), gestures (swipe to act), mic (voice to agent).
- **Privacy (goal):** All user data encrypted at rest. Zero plaintext storage. Not yet implemented — required for production release.
- **Credits as fuel:** Token-based usage with starter balance. Additional payment methods planned post-launch.

## Conventions

- **Branch model:** `main` (stable), `dam` (dam's working branch), `sac` (sac's working branch). PRs go from `pr/dam/<name>` or `pr/sac/<name>` → `main`. Rebase working branch onto main after merge.
- **Commit format:** `type: short description` (no Co-Authored-By footers)
- **PR process:** Feature branches to main, PR review required, includes Thinking section
- **Default simulator:** iPhone 17 Pro
- **Dev shell:** Nix flake, activated via `direnv allow`
- **Make targets:** All dev commands through `make` (see CLAUDE.md)

## Decisions Log

Append new decisions here with date, who proposed, who agreed.

| Date | Decision | Proposed by | Context |
|------|----------|-------------|---------|
| 2026-02-28 | Adopt collaborative meta structure at `meta/` | dam | Genesis: bootstrap shared process |
| 2026-02-28 | Archive old `workflows/` to `workflows.archive/` | dam | Clean slate for meta |
| 2026-02-28 | PRs must include Thinking section | dam | Review thinking, not just code |
| 2026-02-28 | Metacraft skills installed at user level (~/.claude/skills/) | dam | Shared tooling: genesis, meta-agent, session-lifecycle, tmux-lanes, gather, skill-creator |
