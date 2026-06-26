3. **Discover sibling repositories** (multi-repo extension):
   - If `.specify/repos.yaml` exists, parse it via:
     ```bash
     .specify/extensions/multi-repo/scripts/bash/parse-repos-yaml.sh
     ```
     The script emits JSON; capture `repos[].id`, `path`, `role`, `stack`, `branch_prefix`, `base_branch`, and `github` for each entry.
   - If `repos.yaml` is absent or the script fails, log a one-line warning and continue without multi-repo support (do not error).
   - Cross-reference each repo's `role` and `stack` against FEATURE_SPEC. A repo is *affected* if the spec references its role (e.g. "backend", "infrastructure") OR its stack (e.g. "react", "terraform"), OR if user stories describe behavior that lives in that repo.
   - Add an **Affected Repositories** section under **Project Structure** in IMPL_PLAN with this table:

     ```markdown
     ### Affected Repositories

     | Repo ID | Path | Role | Stack | Why affected | Suggested branch prefix |
     |---------|------|------|-------|--------------|-------------------------|
     | app | ../app | backend, frontend | typescript, nestjs, react | New /feature API + admin page | (empty — use ticket ID) |
     | infra | ../infra | infrastructure | terraform, opentofu | New queue + IAM role for the worker | (empty) |
     ```

   - Branches are NOT created here. They are created per-task by `/speckit-multi-repo-branch` during `/speckit-implement`.
   - If no sibling repos are affected (the spec is purely about the Spec Kit root repo), omit the section.
