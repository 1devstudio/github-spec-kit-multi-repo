**Multi-repo routing** (multi-repo extension): If a task carries a `[repo:<id>]` label, route the issue to the GitHub repo configured for that id in `.specify/repos.yaml`, NOT to the current `git remote origin` slug:

```bash
bash -c '. .specify/extensions/multi-repo/scripts/bash/multirepo-common.sh && multirepo_github_slug "<id>"'
```

- If the slug is non-empty, create the issue against that `owner/repo`.
- If it is empty, fall back to the Spec Kit root repo remote and prefix the issue title with `[<repo_id>]` so reviewers know which repo it targets.
- Tasks without a `[repo:<id>]` label (and tasks labeled `[repo:specs]`) route to the Spec Kit root repo remote as before.

The CAUTION below still applies — never create issues outside the union of (a) the Spec Kit root repo remote and (b) the `github` slugs explicitly listed in `.specify/repos.yaml`.
