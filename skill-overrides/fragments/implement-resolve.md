   - **Repo label** (multi-repo extension): If the task carries a `[repo:<id>]` label, that is the target repo for the task. Resolve the id to an absolute working-tree path with the shared accessor (it resolves the configured `path` against the Spec Kit root repo for you):
     ```bash
     bash -c '. .specify/extensions/multi-repo/scripts/bash/multirepo-common.sh && multirepo_repo_path "<id>"'
     ```
     A non-zero exit means the id is unknown (3) or its path is missing on disk (4). Tasks without a label (or with `[repo:specs]`) operate inside the Spec Kit root repo itself.
