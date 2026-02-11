---
id: "001"
title: "Repo Creation & Pages Deploy"
status: completed
author: gudnuf
project: Murmur
tags: [infra, github, ci, deploy]
previous: "000"
sessions:
  - id: current
    slug: repo-creation-and-pages
    dir: -Users-claude-Murmur
prompts: []
created: "2026-02-11T08:25:00Z"
updated: "2026-02-11T08:30:00Z"
---

# 001: Repo Creation & Pages Deploy

## Context

Phase 1 (spec + mockups) was complete and sitting in a local git repo with no remote. Time to get it on GitHub and make the mockup index browsable.

## What Happened

### Repo setup (~2 min)

**What**: Created public repo at `damsac/Murmur`, pushed all existing commits.

**Decisions**:
- User chose **public** over private — open source from day one.
- Added `.gitignore` for `.claude/settings.local.json` (local Claude Code permissions config, not project-relevant).

**Result**: 3 commits pushed to `github.com/damsac/Murmur`.

### Pages deploy (~3 min)

**What**: Deployed `mockups/` directory to GitHub Pages via Actions workflow.

**Problem**: GitHub Pages source path only allows `/` or `/docs` — can't point directly at `/mockups/`.

**Solution**: Created `.github/workflows/pages.yml` using the official `actions/upload-pages-artifact` + `actions/deploy-pages` pattern. This uploads only the `mockups/` subdirectory as the site artifact. Auto-deploys on every push to `main`.

**Result**: Mockup index live at `damsac.github.io/Murmur/`.

## Artifacts

- `.gitignore` — new
- `.github/workflows/pages.yml` — new
- [Live mockup index](https://damsac.github.io/Murmur/)
- [GitHub repo](https://github.com/damsac/Murmur)

## What's Next

Phase 2: project scaffold (Nix flake, XcodeGen, models, theme) and GitHub Issues for milestone tracking.
