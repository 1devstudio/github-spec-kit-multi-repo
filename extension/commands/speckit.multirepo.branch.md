---
description: "Create / check out a feature branch in one sibling repo"
---

# Create a feature branch in a sibling repo

Used by `/speckit-implement` (and callable on its own) to create or check out a
feature branch inside one of the repos listed in `.specify/repos.yaml`. Safe
to run repeatedly — already-on-branch is a no-op, and existing branches are
reused.

## User Input

```text
$ARGUMENTS
```

Expected forms:

- `repo=<id> name=<branch>` — minimum required.
- `repo=<id> name=<branch> base=<branch>` — override the configured base branch
  for stacked-PR phases that fork off a previous phase's branch instead of
  `defaults.base_branch`.

If `name` is omitted, default to the current spec-kit branch in the Spec Kit
root repo (`git -C <root> rev-parse --abbrev-ref HEAD`). The repo's configured
`branch_prefix` is automatically prepended to `name`.

## Prerequisites

- `git` and `yq` are installed.
- The target repo's path resolves on disk.
- The target repo has no uncommitted changes (the script aborts otherwise).

## Execution

Run the helper script:

```bash
.specify/extensions/multi-repo/scripts/bash/create-repo-branch.sh \
    --repo "<id>" \
    --name "<branch>" \
    [--base "<branch>"] \
    --json
```

The `--json` output contains:

- `repo_id`
- `repo_path`
- `branch` (with prefix already applied)
- `base`
- `action` — one of `already-on-branch`, `checked-out-existing`,
  `checked-out-from-remote`, `created-from-base`

## Stacked PR support

When a later implementation phase needs a different branch name than the spec
kit's auto-generated one (e.g. `<TICKET>-phase0-foundation` →
`<TICKET>-phase1-api`), call this command with the explicit `name` and pass
`base=<previous phase branch>` so the new branch forks from the stack's tip
rather than from the repo's configured `base_branch`.

## Output

Echo the JSON result to the user along with a one-line confirmation:
`[<repo_id>] <action> <branch> (base: <base>) at <repo_path>`.
