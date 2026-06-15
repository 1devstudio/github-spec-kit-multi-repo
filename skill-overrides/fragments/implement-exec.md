   - **Repo-scoped execution**: When a task carries `[repo:<id>]`:
     - All file paths in the task description are interpreted relative to that repo's working tree, NOT the Spec Kit root repo.
     - File edits MUST be made inside that repo's tree (`<repo_path>/<task_relative_path>`).
     - Shell commands MUST be run with `git -C <repo_path>` (for git operations) or `cd <repo_path> && …` (for build/test commands).
     - **Branch-setup tasks** — tasks whose description starts with `Create feature branch via /speckit-multirepo-branch …` — MUST be executed by invoking the helper script directly, NOT by manually running `git checkout`:
       ```bash
       .specify/extensions/multi-repo/scripts/bash/create-repo-branch.sh \
           --repo "<id>" --name "<BRANCH_NAME>" [--base "<previous-phase-branch>"] --json
       ```
       The script is idempotent — already-on-branch is a success. It refuses to switch from a dirty working tree, so run `/speckit-multirepo-status` first if you're unsure.
     - Before editing files inside a sibling repo, verify the current branch is the one the task expects (`git -C <repo_path> rev-parse --abbrev-ref HEAD`). If a feature branch was supposed to be created by an earlier Phase-1 task but wasn't, halt and ask the user rather than committing onto the wrong branch.
