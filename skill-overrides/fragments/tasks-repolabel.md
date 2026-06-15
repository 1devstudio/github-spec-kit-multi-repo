5. **[Repo] label** (multi-repo extension): REQUIRED for tasks that modify files in a sibling repo
   - Format: `[repo:<id>]` where `<id>` is from `.specify/repos.yaml`, e.g. `[repo:app]`, `[repo:infra]`
   - Tasks that modify the Spec Kit root repo itself: omit the label, or use `[repo:specs]` for clarity
   - The label appears AFTER `[Story]` and BEFORE the description
   - File paths in the description are interpreted relative to that repo's working tree
