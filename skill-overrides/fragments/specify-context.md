6a. **Multi-repo context** (multi-repo extension): If `.specify/repos.yaml` exists, append a `## Multi-Repo Context` section near the top of `SPEC_FILE` (after the summary, before Functional Requirements). Populate it from:
    ```bash
    .specify/extensions/multi-repo/scripts/bash/parse-repos-yaml.sh
    ```
    Render every registered repo as a row:

    ```markdown
    ## Multi-Repo Context

    The following repositories are registered in `.specify/repos.yaml`. Spec authors
    SHOULD think about which of them this feature touches; `/speckit-plan` will mark
    the affected ones in `plan.md`.

    | Repo ID | Path | Role | Stack |
    |---------|------|------|-------|
    | app | ../app | backend, frontend | typescript, nestjs, react |
    | infra | ../infra | infrastructure | terraform, opentofu |
    ```

    Branches are NOT created in sibling repos at spec time — only the Spec Kit root repo branch is created here (by the `before_specify` git hook). Sibling-repo branches are created per-task during `/speckit-implement` via `/speckit-multirepo-branch`.
