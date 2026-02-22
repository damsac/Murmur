Show the current state of the Murmur project: what's in flight, who's working on what, and whether anything might conflict with the current working directory.

## Step 1 — Fetch open PRs

```bash
gh pr list --repo damsac/Murmur --state open --json number,title,author,headRefName,files
gh api user --jq .login
```

## Step 2 — Fetch project board

```bash
gh api graphql -f query='{
  organization(login: "damsac") {
    projectV2(number: 2) {
      items(first: 50) {
        nodes {
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

## Step 3 — Check local state

```bash
git status
git branch --show-current
```

## Step 4 — Display the summary

Format the output in three sections:

### In Progress
List board items with status "In Progress", grouped by assignee:
```
In Progress:
  gudnuf  — #13 Add ability to pause the recording
  you     — (nothing)
```

### Open PRs
```
Open PRs:
  #N  [title]  by gudnuf   feat/some-branch
  #N  [title]  by you      feat/other-branch
```

### Available (Backlog / Todo, unassigned or yours)
```
Available to pick up:
  #16  Polish onboarding flow
  #26  Clean up Settings view
  #28  Clean up confirmation flow
  #31  Entry status change UX
```

### Conflict check
If the current branch has uncommitted changes or differs from main, check whether any open PRs touch the same files. If so:
```
⚠️  Potential conflict: PR #N (gudnuf) also touches HomeView.swift
```

If nothing is in flight or no conflicts: "All clear — no conflicts detected."
