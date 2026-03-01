Ship the current work: commit, open a PR, and update the project board. Follow these steps:

## Step 1 — Confirm state

Run:
```bash
git status
git diff --stat HEAD
gh api user --jq .login
```

Report the current branch, what files have changed, and the current user.

If on `main`, stop and tell the user: "You're on main — work should be on your branch (`dam` or `sac`). Did you mean to run /start first?"

## Step 2 — Update your STATE.md

Before shipping, update your meta state file (`meta/dam/STATE.md` or `meta/sac/STATE.md`):
- Current focus (what you just worked on)
- Recent decisions (what you decided in this PR and why)
- Open questions (anything surfaced during this work)
- What you need from the other person

Also check if any decisions should be added to `meta/CANON.md` or if `meta/ROADMAP.md` needs updating.

Stage the meta changes along with the code changes.

## Step 3 — Check for conflicts with open PRs

Run:
```bash
gh pr list --repo damsac/Murmur --state open --json number,title,author,files
```

If any open PR (not authored by the current user) touches the same files as the current changes, warn the user before proceeding:
"⚠️ PR #N by [author] also touches [file] — coordinate before merging."

## Step 4 — Stage and commit

If there are uncommitted changes, stage and commit them. Ask the user for a brief description of what they built if a good commit message isn't obvious from the diff.

Use the standard format:
```
type: short description

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

## Step 5 — Create PR branch and push

Branch off the current working branch for the PR:

```bash
# Determine PR branch name — ask user for a short name or derive from the work
git checkout -b <user>/<pr-name>
git push -u origin HEAD
```

Use `dam/<name>` or `sac/<name>` based on the current user (e.g. `dam/meta-genesis`, `sac/category-cleanup`).

## Step 6 — Detect linked issue

Check the branch name for an issue number (e.g. `feat/issue-16-polish-onboarding` → issue #16).
Also check recent commit messages for "closes #N" or "#N" references.

## Step 7 — Open the PR

Create the PR targeting `main` (unless the branch was created from another feature branch, in which case target that branch):

```bash
gh pr create \
  --repo damsac/Murmur \
  --title "..." \
  --body "..." \
  --base main
```

PR body format:
```
## Thinking
<!-- What did you decide and why? What did you consider and reject? What assumptions are you making? -->

## Summary
- [bullet points describing what changed and why] 
- [This should be focused on the concepts and core architectural decisions]
- [wtihout geting in to the nitty gritty code changes]

## State changes
<!-- How did your STATE.md change? Any new open questions? Any canon candidates? -->

## Related
Closes #N  ← include if linked to a board issue

## Test plan
- [ ] [manual test steps]

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

The **Thinking** section is the primary review surface. The reviewer reads this first. If the thinking is sound, the code follows.

## Step 8 — Move issue to "In Progress" (if not already)

If linked to a board issue, ensure it's marked "In Progress" on the project board. Query the board to find the item ID, then update:

```bash
gh api graphql -f query='
  mutation {
    updateProjectV2ItemFieldValue(input: {
      projectId: "PVT_kwDODwsfWc4BP0Xe"
      itemId: "ITEM_ID"
      fieldId: "PVTSSF_lADODwsfWc4BP0Xezg-HhAY"
      value: { singleSelectOptionId: "47fc9ee4" }
    }) { projectV2Item { id } }
  }
'
```

## Step 9 — Return to working branch

Go back to your working branch so you can keep going:

```bash
git checkout dam   # or sac
```

## Step 10 — Report

Print a summary:
```
✓ PR #N opened: [title]
  Branch: <user>/<pr-name>
  Linked issue: #N — [title]
  URL: https://github.com/damsac/Murmur/pull/N
  Back on: dam (ready to keep working)
```
