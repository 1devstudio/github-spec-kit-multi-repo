   - **Multi-repo task tagging**: If plan.md contains an "Affected Repositories" section (table with Repo ID / Path / Role / Stack / Why affected columns), extract the repo ids and paths. Every task that modifies a file *inside* one of those repos MUST carry a `[repo:<id>]` label immediately after any `[Story]` label, e.g. `- [ ] T012 [P] [US1] [repo:app] Implement controller in src/feature/controller.ts`. Tasks that modify the Spec Kit root repo itself omit the label or use `[repo:specs]` for clarity.
   - **Phase-1 branch-setup tasks**: For each affected repo, generate a Phase-1 setup task with `[P]` (parallelizable) immediately at the top of Phase 1, *before* any other setup task. Format:
     ```text
     - [ ] T00X [P] [repo:<id>] Create feature branch via /speckit-multi-repo-branch repo=<id> name=<BRANCH_NAME>
     ```
     - `BRANCH_NAME` defaults to the Spec Kit root repo feature branch (from `git rev-parse --abbrev-ref HEAD` in the root repo). It is overridable when a phase needs a different name (e.g. for stacked PRs).
     - The configured `branch_prefix` for that repo is applied automatically by `/speckit-multi-repo-branch`; do not bake it into the task text.
     - If a phase later needs to fork from a previous phase's branch tip instead of the repo's `base_branch`, the task SHOULD include `base=<previous-phase-branch>` in the command, e.g. `… name=PROJ-123-phase1-api base=PROJ-123-phase0-foundation`.
   - **Stacked-PR support**: When the spec or plan explicitly calls for stacked PRs across phases in a sibling repo, emit one branch-setup task per stack tip (one in Phase 1 for the foundation branch, then one at the start of each subsequent user-story phase to roll the branch forward).
