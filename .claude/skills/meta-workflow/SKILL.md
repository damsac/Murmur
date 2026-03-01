---
name: meta-workflow
description: >
  Create or update developer journey documentation in workflows/meta/.
  Use when the user says "meta", "meta-workflow", "document this session",
  "write up what we did", or wants to create a changelog-style entry
  documenting developer thinking, decisions, and session history.
  Also use after completing a non-trivial PR or feature.
---

# Meta Workflow

Create structured developer journal entries.

> **Note:** The old `workflows/meta/<author>/` directory has been archived to `workflows.archive/`.
> Journal entries now live alongside the collaborative meta structure. For the canonical
> collaboration files, see `meta/` at the project root (CANON.md, ROADMAP.md, WORKFLOWS.md,
> RECONCILIATION.md, and per-person PROCESS.md/STATE.md).

## Step 1: Resolve Author & Next Entry

```bash
AUTHOR=$(git config user.name)
```

- If `workflows/meta/$AUTHOR/` doesn't exist → create it, start at `000`
- If it exists → `ls workflows/meta/$AUTHOR/*.md`, find highest number, increment

For first-time authors, copy `workflows/meta/000-template.md` as starting point.

## Step 2: Determine Scope

Ask the user (via `AskUserQuestion`) what this entry covers:
- Feature or set of features just completed
- Research / exploration session
- Onboarding (first entry)
- Retrospective on recent work

## Step 3: Mine Conversation History

Session transcripts live in `~/.claude/projects/`. The current project directory is named with the workspace absolute path's separators replaced by dashes (e.g., `/Users/me/Murmur` → `-Users-me-Murmur`).

### Discovery process

First, derive the project directory name:
```bash
PROJECT_DIR=$(pwd | sed 's|/|-|g')
```

1. **Find sessions for this project:**
   ```bash
   ls ~/.claude/projects/${PROJECT_DIR}/*.jsonl
   ```

2. **Search for relevant sessions** using keywords from the current work:
   ```
   Grep pattern="keyword1|keyword2" path="~/.claude/projects/${PROJECT_DIR}/" glob="*.jsonl"
   ```
   Note: Use unquoted keywords (not JSON-escaped). The JSONL content is raw text.

3. **Get message counts** per file to gauge session size:
   ```
   Grep pattern='"type":"user"' path="<dir>" glob="*.jsonl" output_mode="count"
   ```

4. **Launch parallel subagents** (one per session, `sonnet` model) to extract:
   - Main topic/goal
   - Decisions made and rationale
   - Problems encountered and solutions
   - Files created/modified
   - Key timestamps and duration
   - Developer thinking — what they went back and forth on

   Also check `<session-id>/subagents/` directories for subagent transcripts.

5. **Establish chronological order** from timestamps across all sessions.

### Subagent prompt template

> Read the conversation transcript at `<path>`. Extract: (1) main goal, (2) decisions made, (3) what was built/changed, (4) problems and solutions, (5) developer thinking. Focus on human messages and assistant text — skip tool call JSON. Keep under 600 words.

## Step 4: Write the Entry

File: `workflows/meta/<author>/<NNN>-<slug>.md`

### Frontmatter

```yaml
---
id: "<NNN>"
title: "<descriptive title>"
status: active | completed
author: <AUTHOR>
project: Murmur
tags: [<relevant>]
previous: "<NNN-1>"  # omit for 000
sessions:
  - id: <session-uuid-prefix>
    slug: <short-description>
    dir: <project-dir-name>
prompts: []  # backlinks filled as prompts are created
created: "<ISO 8601>"
updated: "<ISO 8601>"
---
```

### Body structure

```markdown
# <NNN>: <Title>

## Context
<1-3 sentences: what was happening, why this work started>

## Timeline
### Phase N: <name> (`<session-id>`, ~duration)
**What**: <one sentence>
**Decisions**: ...
**Problems**: ...

## Architecture Snapshot  (only if architecture changed)

## Developer Patterns Observed
- bullet points: what worked, what didn't

## Artifacts
- [link](assets/NNN/file.png) to visuals, mockups, screenshots

## Open Questions

## What's Next
```

## Step 5: Handle Assets

Store images, screenshots, mockups in `workflows/meta/<author>/assets/<NNN>/`.

```
workflows/meta/<author>/
  assets/
    000/
      index.html        # UI mockups
      screenshot.png
    001/
      before.png
      after.png
```

Link with relative paths: `[view mocks](assets/000/index.html)`, `![screenshot](assets/001/screenshot.png)`

When user provides screenshots or references external files:
1. Create `assets/<NNN>/` for the entry
2. Copy files there
3. Link with relative paths so clicking opens in browser/viewer

## Style Rules

- **Concise and skimmable** — humans skim, not read linearly
- **Show thinking, not just output** — "wanted X, considered Y, chose Z because..."
- **Problems are valuable** — document what went wrong
- **No implementation code** — reference files and prompts instead
- **Bold key terms** for scan-reading
- **Timestamps matter** — session IDs and durations for traceability

## Connecting to Prompts

Meta ↔ prompt files (`workflows/prompts/`) are bidirectionally linked:
- Meta `prompts:` frontmatter lists related prompt files
- Prompt `meta:` frontmatter references parent meta entry
- Meta = narrative; prompts = implementation receipts

## Directory Layout

```
workflows/
  meta/
    000-template.md        # new authors copy this
    <author>/
      000-project-setup.md
      001-initial-features.md
      assets/000/index.html
    <other-dev>/
      000-onboarding.md
  prompts/
    <timestamp>.md         # linked from meta entries
```

## Bootstrap Note

This skill was installed standalone (not via full Phase 2 init). The existing
entry at `.claude/meta/000-voice-to-vision.md` predates this skill's directory
conventions. When writing the first entry under `workflows/meta/`, migrate or
reference that original 000 entry as the foundation.
