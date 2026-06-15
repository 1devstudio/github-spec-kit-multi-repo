# Spec Kit Multi-Repo Extension

Cross-repo coordination for [Spec Kit](https://github.com/github/spec-kit).
Reads a `.specify/repos.yaml` registry and lets the spec-driven workflow
(`/speckit-plan`, `/speckit-tasks`, `/speckit-implement`,
`/speckit-taskstoissues`) operate across **sibling** product repositories from a
single Spec Kit "root" repo.

## Why this exists

Upstream Spec Kit and the community
[multi-repo-branching preset](https://github.com/sakitA/spec-kit-preset-multi-repo-branching)
both assume sub-repos live **inside** the root repo (independent `.git` dirs or
submodules). This extension targets a different, common layout: every product
repo is cloned as a **sibling** of the Spec Kit root repo in the same workspace
directory. It also captures per-repo metadata (role, stack, branch prefix,
GitHub slug) that auto-discovery can't infer, so it uses an explicit registry
instead of a filesystem scan.

```
workspace/
├── <root>/         # the Spec Kit root repo — specs, plans, tasks, constitution
├── <app-repo>/     # a sibling product repo (e.g. apps + libs)
├── <infra-repo>/   # another sibling product repo (e.g. infrastructure as code)
└── …other sibling repos…
```

## What's in this repo

```
.
├── extension/                # the installable Spec Kit extension payload
│   ├── extension.yml         # extension manifest + tool requirements
│   ├── config-template.yaml  # template that .specify/repos.yaml ships with
│   ├── commands/             # /speckit-multirepo-{config,branch,status}
│   └── scripts/bash/         # yq-backed helper scripts
├── skill-overrides/          # PRESET fragments injected into the core skills
│   ├── manifest.yaml         # maps each block → target skill + anchor + fragment
│   └── fragments/            # one file per injected block
├── install.sh                # idempotent installer (payload + skill overrides)
├── uninstall.sh              # removes the skill overrides (and optionally payload)
└── examples/repos.inspiren.yaml   # a worked registry example
```

## Requirements

- `git`
- [`yq`](https://github.com/mikefarah/yq) (mikefarah/yq) — `brew install yq` on
  macOS, or see the project page for other platforms.
- A Spec Kit project (`>=0.8.0`) initialised with the Claude integration and
  AI skills enabled (the installer patches `.claude/skills/*/SKILL.md`).

## Install

From a clone of this repo, point the installer at your Spec Kit project root:

```bash
./install.sh --specify-root /path/to/your/spec-kit-repo
# or, run it from inside the target repo and let it auto-detect the root:
/path/to/this/repo/install.sh
```

The installer:

1. Copies `extension/` → `<root>/.specify/extensions/multi-repo/`.
2. Adds `multi-repo` to `<root>/.specify/extensions.yml` under `installed:`.
3. Injects each skill-override block from `skill-overrides/manifest.yaml` into the
   matching `<root>/.claude/skills/<skill>/SKILL.md`, wrapped in
   `<!-- PRESET: multi-repo:<block-id> START/END -->` markers.

It is **idempotent** — re-running updates blocks in place rather than
duplicating them. Use `--dry-run` to preview every change without writing.

After installing, create your registry:

```bash
cp extension/config-template.yaml /path/to/your/spec-kit-repo/.specify/repos.yaml
# then edit it — see examples/repos.inspiren.yaml for a worked example.
```

## `.specify/repos.yaml` schema

```yaml
schema_version: "1.0"

defaults:
  base_branch: main          # used when a repo entry omits base_branch
  branch_prefix: ""          # used when a repo entry omits branch_prefix

repos:
  - id: app                  # unique, kebab-case; used as the [repo:<id>] task label
    path: ../app             # relative to the Spec Kit root repo
    role: [backend, frontend]              # string or array
    stack: [typescript, nestjs, react]     # string or array
    branch_prefix: ""        # prepended to whatever branch /speckit-multirepo-branch is asked for
    base_branch: main       # branch to fork from when creating a new feature branch
    github: <owner>/app      # used by /speckit-taskstoissues for routing
```

- `id` is the stable handle that Spec Kit tasks reference via `[repo:<id>]`.
- `path` MUST be relative to the Spec Kit root repo (or absolute). It is resolved
  at runtime, so a repo that isn't cloned yet is reported as `missing` by
  `/speckit-multirepo-status` (which still exits non-zero so automation can detect
  it) instead of aborting the whole run.
- `role` and `stack` are advisory metadata used by `/speckit-plan` to decide
  which repos a feature touches.
- `branch_prefix` enables conventions like `feature/` on repos that want them.
- `base_branch` is the branch a new feature branch is forked from (e.g. `main`).
  It defaults to `defaults.base_branch`.
- `github` is the `owner/repo` slug; required only if you want
  `/speckit-taskstoissues` to route issues there.

## Commands

| Command | What it does |
|---|---|
| `/speckit-multirepo-config` | Parse and display `repos.yaml`; flag duplicate ids, unreachable paths, missing `github` slugs. |
| `/speckit-multirepo-branch` | Idempotently create / check out one branch in one repo. Called per-task by `/speckit-implement`. |
| `/speckit-multirepo-status` | Show clean/dirty + current branch for every repo in `repos.yaml`. |

## How the workflow uses the extension

| Skill | Behavior with the extension installed |
|---|---|
| `/speckit-specify` | Spec gains a "Multi-Repo Context" block listing the registry. |
| `/speckit-plan` | Reads `repos.yaml`; adds an **Affected Repositories** table to `plan.md`. |
| `/speckit-tasks` | Tags every sibling-repo task with `[repo:<id>]`. Emits a Phase-1 branch-setup task per affected repo. |
| `/speckit-implement` | Resolves `[repo:<id>]` → path; runs each task's commands inside that repo. Calls `/speckit-multirepo-branch` for setup tasks. |
| `/speckit-taskstoissues` | Routes issues to `<github>` per `repos.yaml`. |

## Stacked-PR support

Sibling-repo branches are created **at implementation time**, not at spec time,
so each implementation phase can use a different branch name. To fork a later
phase from a previous phase's tip, pass `base=<previous branch>` to
`/speckit-multirepo-branch`.

## Uninstall

```bash
./uninstall.sh --specify-root /path/to/your/spec-kit-repo
```

This strips the injected PRESET blocks from the core skills and removes
`multi-repo` from `extensions.yml`. It leaves `.specify/extensions/multi-repo/`
and `.specify/repos.yaml` in place by default — pass `--purge` to also delete the
extension payload directory.

## License

MIT — see [LICENSE](./LICENSE).
