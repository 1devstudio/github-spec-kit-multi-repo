   - **Repo label** (multi-repo extension): If the task carries a `[repo:<id>]` label, that is the target repo for the task. Resolve the id to a working-tree path via:
     ```bash
     .specify/extensions/multi-repo/scripts/bash/parse-repos-yaml.sh | yq -r ".repos[] | select(.id == \"<id>\") | .path"
     ```
     Resolve the path against the Spec Kit root repo (relative paths use `cd <root> && cd <path>`). Tasks without a label (or with `[repo:specs]`) operate inside the Spec Kit root repo itself.
