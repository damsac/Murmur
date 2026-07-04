# Reconciliation Protocol

How dam and sac stay in sync. The goal: review thinking, not just code.

---

## How it works in practice

When reviewing a PR or starting a session, ask Claude to read the meta files and report:
- Discrepancies between the two STATE files (conflicting assumptions, overlapping work)
- Decisions in one person's STATE that should be in CANON
- ROADMAP items that are done but not moved to Completed
- Open questions that have been sitting unresolved
- Anything that looks stale or out of date

Claude does the diff. You review the summary and decide what to act on.

## The PR is the reconciliation surface

Every PR is a reconciliation event. The reviewer's job is not primarily to review code — it's to review the other person's *thinking*.

### PR requirements

1. **Thinking section** — what you decided and why, what you considered and rejected, what assumptions you're making
2. **STATE.md update** — your state file must reflect what you just did and what you need from the other person
3. **Canon candidates** (when applicable) — new conventions or resolved questions get added to CANON.md
4. **Roadmap updates** (when applicable) — work completed, new work surfaced, priorities shifted

## Session start

When starting a session (`/start`), Claude reads:
1. The other person's STATE.md
2. CANON.md
3. ROADMAP.md
4. Open PRs that need review

And gives you a summary of where things stand.

## Conflict resolution

If dam and sac disagree on a canonical decision:
1. Open a discussion issue on GitHub
2. Each states their position
3. Resolve synchronously (call/chat) if text isn't converging
4. Winner updates CANON.md, loser reviews and approves

## Anti-patterns

- **Stale STATE.md** — if your state file doesn't reflect reality, the other person's Claude is flying blind.
- **Silent canonization** — making decisions that affect both without adding to CANON.md.
- **Skipping the meta read** — starting work without knowing what the other person is doing.
