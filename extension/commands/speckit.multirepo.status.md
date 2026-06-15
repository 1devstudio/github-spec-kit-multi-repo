---
description: "Report clean/dirty + current branch across every repo in repos.yaml"
---

# Workspace status across all repos

Quick health check before / during multi-repo implementation: shows the current
branch + working-tree state (clean / dirty) for every repo listed in
`.specify/repos.yaml`. Repos whose `path` does not resolve are reported as
`missing` so the operator knows to clone them.

## User Input

```text
$ARGUMENTS
```

Optional flag:

- `--json` — emit a JSON array instead of the default table.

## Execution

```bash
.specify/extensions/multi-repo/scripts/bash/repo-status.sh        # table
.specify/extensions/multi-repo/scripts/bash/repo-status.sh --json # JSON
```

## When to call

- Before `/speckit-implement` to confirm the workspace is in a clean state.
- After a stacked-PR phase merges, to make sure follow-up phases branch from
  the right tip.
- During code review prep, to spot dirty repos that shouldn't be touched.

## Output

A table with `REPO · STATE · BRANCH @ PATH` per row. Exit code is non-zero if
any repo is missing or non-clean — surface that to the user.
