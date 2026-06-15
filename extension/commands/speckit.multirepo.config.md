---
description: "Validate and summarize .specify/repos.yaml"
---

# Inspect the workspace repo registry

Show the parsed contents of `.specify/repos.yaml` so the operator can confirm
the multi-repo extension sees what they expect before running plan / tasks /
implement.

## User Input

```text
$ARGUMENTS
```

## Prerequisites

- `yq` must be installed (`brew install yq` on macOS).
- `.specify/repos.yaml` must exist at the Spec Kit root repo.

## Execution

Run the parser script:

```bash
.specify/extensions/multi-repo/scripts/bash/parse-repos-yaml.sh
```

The script emits the registry as JSON. Render it to the user as a small table
of `id · path · role · stack · branch_prefix · base_branch · github`, and call
out anything obviously wrong:

- Repo ids that are not unique.
- Paths that don't resolve on disk (use `ls` to verify each path).
- Repos with empty `github` slugs when `/speckit-taskstoissues` is expected to
  route to them.

## Output

A short markdown summary that lists every repo, plus an explicit pass/fail
verdict on the three checks above.
