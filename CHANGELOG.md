# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-06-26

### Changed

- **BREAKING:** Renamed the three provided commands from `speckit.multirepo.*`
  to `speckit.multi-repo.*` (slash commands `/speckit-multi-repo-{config,branch,status}`).
  Spec Kit **0.11+** validates that every command name uses the owning
  extension's id as its namespace, and the extension id is `multi-repo`; the old
  `multirepo` (no hyphen) names fail `specify extension add` with
  `Command 'speckit.multirepo.config' must use extension namespace 'multi-repo'`.
  The new names also work on 0.8–0.10, so the extension remains compatible with
  `speckit_version >= 0.8.0`.

### Notes

- Internal shell helpers (`multirepo_*` functions, `multirepo-common.sh`) and the
  `<!-- PRESET: multi-repo:* -->` skill-override markers are unchanged.
- Skill-override anchors were re-verified against Spec Kit 0.11.8 stock skills and
  all still match, so injection behavior is unchanged.

## [1.0.0] - 2026-06-15

### Added

- Initial public release, extracted from a private Spec Kit project into a
  standalone, project-agnostic extension.
- `extension/` — the installable Spec Kit extension payload: `extension.yml`,
  `config-template.yaml`, three commands (`speckit.multirepo.config`,
  `speckit.multirepo.branch`, `speckit.multirepo.status`), and four bash helper
  scripts.
- `skill-overrides/` — PRESET fragments injected into the core Spec Kit skills
  (`speckit-specify`, `speckit-plan`, `speckit-tasks`, `speckit-implement`,
  `speckit-taskstoissues`) plus a `manifest.yaml` describing where each block is
  anchored.
- `install.sh` / `uninstall.sh` — idempotent installer/uninstaller that copies
  the payload and injects/strips the skill-override blocks. Spec Kit's extension
  manifest has no native skill-overlay mechanism, so this is provided as a
  separate step.
- `examples/repos.inspiren.yaml` — a worked multi-repo registry example.

### Changed

- Skill-override markers are now **namespaced per block**
  (`<!-- PRESET: multi-repo:<block-id> START/END -->`) so that skills carrying
  more than one block (e.g. `speckit-tasks` has four) can be addressed and
  updated individually. The original internal version used a single
  un-namespaced `<!-- PRESET: multi-repo START/END -->` marker.
- All project-specific identifiers (repo names, paths, ticket prefixes) were
  replaced with neutral placeholders. Real values survive only in
  `examples/repos.inspiren.yaml`.
