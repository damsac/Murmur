Start a new work session on the Murmur project. Follow these steps in order:

## Step 1 — Sync with main

Determine the current user's branch (`dam` or `sac`) based on their git login:
```bash
gh api user --jq .login
```

- If `gudnuf` → working branch is `dam`
- If `IsaacMenge` → working branch is `sac`

Then sync:
```bash
git checkout main && git pull
git checkout <your-branch> && git pull && git merge main
```

Report what changed (or confirm already up to date).

## Step 2 — Fetch the project board

Run this query to get all open board items:
```bash
gh api graphql -f query='{
  organization(login: "damsac") {
    projectV2(number: 2) {
      items(first: 50) {
        nodes {
          id
          fieldValues(first: 10) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                name
                field { ... on ProjectV2SingleSelectField { name } }
              }
              ... on ProjectV2ItemFieldTextValue {
                text
                field { ... on ProjectV2Field { name } }
              }
            }
          }
          content {
            ... on Issue {
              number
              title
              assignees(first: 5) { nodes { login } }
              state
            }
          }
        }
      }
    }
  }
}'
```

Also run:
```bash
gh api user --jq .login
```

## Step 3 — Show available work

First, list items assigned to the current user (any status, OPEN state) under **"Your assignments"**:
```
Your assignments:
  - #49 — Edit view shows entry types that don't exist (e.g. 'list') [Todo]
  - #33 — App icon and launch screen [Todo]
```

Then, display unassigned items where **all** of these are true:
- Status is **Backlog** or **Todo**
- Issue state is **OPEN**
- Assignees are **empty**

Format as a numbered list under **"Available work"**, e.g.:
```
Available work:
  1. #16 — Polish onboarding flow
  2. #26 — Clean up Settings view: keep only balance + top up
  3. #28 — Clean up confirmation flow
  4. #31 — Entry status change UX
```

If there are items assigned to the *other* team member (not the current user), list them separately under "Assigned to partner — do not pick these".

## Step 4 — Read the meta

Read the shared meta files to understand the current state of collaboration:

```bash
cat meta/CANON.md
cat meta/ROADMAP.md
```

Then read your partner's state to see what they're working on:

```bash
# If you're gudnuf, read sac's state. If you're IsaacMenge, read dam's state.
cat meta/dam/STATE.md   # or meta/sac/STATE.md
```

Briefly summarize: what the other person is working on, any open questions directed at you, and any canon decisions you haven't seen yet.

## Step 5 — Check for open PRs

Run:
```bash
gh pr list --repo damsac/Murmur --state open --json number,title,author,headRefName
```

Show a brief summary: what's in review, who opened it. Flag any that might relate to what the user is about to work on.

## Step 6 — Ask what to work on

Ask the user: "What would you like to work on?" They can:
- Pick a number from the list above
- Type an issue number directly
- Describe something new (you'll create an issue for it)

Wait for their answer before proceeding.

## Step 7 — Confirm branch

Work happens on your branch (`dam` or `sac`), not feature branches by default. Confirm you're on the right branch:
```bash
git branch --show-current
```

If the user explicitly wants a feature branch for this work, create one from their working branch.

## Step 8 — Assign the issue

If the user picked an existing board item, assign it to them and move it to "In Progress":

```bash
# Assign the issue
gh issue edit N --repo damsac/Murmur --add-assignee "@me"

# Move to In Progress on the project board (use the item ID from Step 2)
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

Replace `ITEM_ID` with the item's id from the board query results.
