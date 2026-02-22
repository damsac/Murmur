Start a new work session on the Murmur project. Follow these steps in order:

## Step 1 — Sync with main

Run:
```bash
git checkout main && git pull
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

Display items where **all** of these are true:
- Status is **Backlog** or **Todo**
- Issue state is **OPEN**
- Assignees are **empty** OR include the current user's login

Format as a numbered list, e.g.:
```
Available work:
  1. #16 — Polish onboarding flow
  2. #26 — Clean up Settings view: keep only balance + top up
  3. #28 — Clean up confirmation flow
  4. #31 — Entry status change UX
```

If there are items assigned to the *other* team member (not the current user), list them separately under "Assigned to partner — do not pick these".

## Step 4 — Check for open PRs

Run:
```bash
gh pr list --repo damsac/Murmur --state open --json number,title,author,headRefName
```

Show a brief summary: what's in review, who opened it. Flag any that might relate to what the user is about to work on.

## Step 5 — Ask what to work on

Ask the user: "What would you like to work on?" They can:
- Pick a number from the list above
- Type an issue number directly
- Describe something new (you'll create an issue for it)

Wait for their answer before proceeding.

## Step 6 — Create a branch

Once the user picks something:
1. Confirm we're on main: `git status`
2. Create a branch: `git checkout -b feat/issue-N-short-description` (use the issue number and a 2-4 word slug from the title)
3. Confirm: "Created branch `feat/issue-N-short-description`. Ready to build."

## Step 7 — Assign the issue

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
