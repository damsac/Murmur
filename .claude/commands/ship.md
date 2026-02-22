Ship the current work: commit, open a PR, and update the project board. Follow these steps:

## Step 1 — Confirm state

Run:
```bash
git status
git diff --stat HEAD
gh api user --jq .login
```

Report the current branch, what files have changed, and the current user.

If on `main`, stop and tell the user: "You're on main — work should be on a feature branch. Did you mean to run /start first?"

## Step 2 — Check for conflicts with open PRs

Run:
```bash
gh pr list --repo damsac/Murmur --state open --json number,title,author,files
```

If any open PR (not authored by the current user) touches the same files as the current changes, warn the user before proceeding:
"⚠️ PR #N by [author] also touches [file] — coordinate before merging."

## Step 3 — Stage and commit

If there are uncommitted changes, stage and commit them. Ask the user for a brief description of what they built if a good commit message isn't obvious from the diff.

Use the standard format:
```
type: short description

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

## Step 4 — Push the branch

```bash
git push -u origin HEAD
```

## Step 5 — Detect linked issue

Check the branch name for an issue number (e.g. `feat/issue-16-polish-onboarding` → issue #16).
Also check recent commit messages for "closes #N" or "#N" references.

## Step 6 — Open the PR

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
## Summary
- [bullet points describing what changed and why]

## Related
Closes #N  ← include if linked to a board issue

## Test plan
- [ ] [manual test steps]

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## Step 7 — Move issue to "In Progress" (if not already)

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

## Step 8 — Report

Print a summary:
```
✓ PR #N opened: [title]
  Branch: feat/issue-N-...
  Linked issue: #N — [title]
  URL: https://github.com/damsac/Murmur/pull/N
```
