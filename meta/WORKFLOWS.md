# Workflows

How dam and sac work together on Murmur. The day-to-day practices.

---

## The cycle

```
/start → pick work → build → /ship → review → merge → reconcile
```

### 1. Start a session (`/start`)

- Sync with main
- Read the other person's STATE.md — know their headspace
- Check CANON.md for new decisions
- Check ROADMAP.md for priorities
- Look at open PRs that need review
- Pick work from the board or propose something new

### 2. Build

- Work on your branch (`dam` or `sac`) — commit freely
- Each person works with their own Claude instance
- Claude's reasoning is the valuable artifact — not just the code it produces

### 3. Ship (`/ship`)

- Update your STATE.md with decisions, open questions, needs
- Branch off for the PR: `git checkout -b pr/dam/<pr-name>`
- Open PR from `pr/dam/<pr-name>` → `main` with **Thinking** section
- Update ROADMAP.md if priorities changed
- Propose CANON.md additions if decisions were made
- Go back to your working branch and keep going: `git checkout dam`

### After a PR merges

Rebase your working branch onto main to stay clean:
```
git checkout main && git pull
git checkout dam && git rebase main
```

This keeps your next PR's diff clean — no duplicate commits from already-merged work.

### 4. Review

The reviewer's job is to review **thinking**, not code.

Read in this order:
1. **Thinking section** — do I agree with the reasoning?
2. **STATE.md diff** — do I understand their current headspace? Any questions for me?
3. **Canon candidates** — do I agree these should be canonical?
4. **Code** — does the implementation match the thinking?

If the thinking is wrong, the code doesn't matter. Push back on the thinking.
If the thinking is sound but the code is off, that's a smaller conversation.

Sac reviews dam's PRs in order. Dam reviews sac's PRs in order. Linear thinking review.

### 5. Reconcile

After merging:
- New canon entries take effect immediately
- Both STATE files should be consistent with reality
- ROADMAP reflects what just shipped and what's next

## Communication patterns

### Async (default)
- PRs are the primary communication channel
- STATE.md is the "here's where my head is at" signal
- CANON.md is the "here's what we've agreed on" record
- GitHub issues for new work items

### Sync (when needed)
- When a CANON decision is contentious (see RECONCILIATION.md)
- When STATE files show conflicting assumptions
- When both are touching the same area of the codebase

## Tool conventions

- **Claude Code:** Both dam and sac use Claude Code with project-specific skills
- **Metacraft skills:** Installed at user level (`~/.claude/skills/`). Both collaborators have: `/genesis`, `/meta-agent`, `/session-lifecycle`, `/tmux-lanes`, `/gather`, `/skill-creator`
- **Project commands:** `/start`, `/status`, `/ship` — the mechanical workflow (project-level, in `.claude/commands/`)
- **GitHub:** PRs, issues, project board — the collaboration surface
- **Nix:** Reproducible dev environment — no "works on my machine"
- **XcodeGen:** Xcode project generated from project.yml — no merge conflicts on .xcodeproj

## What goes where

| Artifact | Location | When to update |
|----------|----------|---------------|
| Shared decisions | `meta/CANON.md` | When both agree on something |
| Priorities | `meta/ROADMAP.md` | When work ships or priorities shift |
| Your current state | `meta/<you>/STATE.md` | Every PR |
| Your process | `meta/<you>/PROCESS.md` | When your workflow changes |
| Feature plans | `docs/plans/` | Before building |
| Design explorations | `docs/brainstorms/` | When exploring |
| Product spec | `.claude/project-spec.yml` | When product decisions change |
| How we work | `meta/WORKFLOWS.md` | When practices evolve |
| PR reconciliation | `meta/RECONCILIATION.md` | Rarely (it's the protocol) |
