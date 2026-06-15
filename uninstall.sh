#!/usr/bin/env bash
# Remove the multi-repo extension from a Spec Kit project.
#
#   - strips every `<!-- PRESET: multi-repo:* START -->…END -->` block (and its
#     markers) from the core skills listed in skill-overrides/manifest.yaml,
#     restoring each SKILL.md to its pre-install state
#   - removes "multi-repo" from <root>/.specify/extensions.yml
#   - leaves <root>/.specify/extensions/multi-repo/ and repos.yaml in place
#     unless --purge is given
#
# Usage: uninstall.sh [--specify-root <path>] [--purge] [--dry-run]
#
# Exit codes:
#   0  success
#   1  bad arguments
#   2  target is not a Spec Kit project
#   3  yq missing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/skill-overrides/manifest.yaml"

ROOT=""
DRY_RUN=false
PURGE=false

usage() {
    cat >&2 <<EOF
Usage: uninstall.sh [--specify-root <path>] [--purge] [--dry-run]

Options:
  --specify-root <path>  Spec Kit project root (default: git rev-parse --show-toplevel)
  --purge                Also delete .specify/extensions/multi-repo/
  --dry-run              Print every planned change without writing anything
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --specify-root) ROOT="${2:-}"; shift 2 ;;
        --purge) PURGE=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "ERROR: unknown flag: $1" >&2; usage; exit 1 ;;
    esac
done

if [ -z "$ROOT" ]; then
    ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
        echo "ERROR: --specify-root not given and not inside a git repo" >&2
        exit 1
    }
fi
ROOT="$(cd "$ROOT" 2>/dev/null && pwd)" || { echo "ERROR: root '$ROOT' not found" >&2; exit 1; }

if [ ! -d "$ROOT/.specify" ]; then
    echo "ERROR: '$ROOT' is not a Spec Kit project (.specify/ not found)" >&2
    exit 2
fi
if ! command -v yq >/dev/null 2>&1; then
    echo "ERROR: yq is required (brew install yq / https://github.com/mikefarah/yq#install)" >&2
    exit 3
fi

log() { printf '%s\n' "$*" >&2; }
$DRY_RUN && log "== DRY RUN — no files will be written =="
log "Spec Kit root: $ROOT"

# --- 1. Strip injected blocks from the skills ------------------------------
block_count="$(yq '.blocks | length' "$MANIFEST")"
i=0
while [ "$i" -lt "$block_count" ]; do
    skill="$(yq -r ".blocks[$i].skill" "$MANIFEST")"
    block_id="$(yq -r ".blocks[$i].block_id" "$MANIFEST")"
    i=$((i + 1))

    skill_file="$ROOT/.claude/skills/$skill/SKILL.md"
    start_marker="<!-- PRESET: multi-repo:$block_id START -->"
    [ -f "$skill_file" ] || continue
    grep -qF -- "$start_marker" "$skill_file" || { log "[$skill:$block_id] not present"; continue; }

    new_file="$(mktemp)"
    awk -v block="$block_id" '
        $0 ~ ("<!-- PRESET: multi-repo:" block " START -->") { skip = 1; next }
        $0 ~ ("<!-- PRESET: multi-repo:" block " END -->")   { skip = 0; next }
        !skip { print }
    ' "$skill_file" > "$new_file"

    if $DRY_RUN; then
        log "[$skill:$block_id] would be removed:"
        diff -u "$skill_file" "$new_file" >&2 || true
    else
        cat "$new_file" > "$skill_file"
        log "[$skill:$block_id] removed"
    fi
    rm -f "$new_file"
done

# --- 2. Deregister from extensions.yml -------------------------------------
EXT_YML="$ROOT/.specify/extensions.yml"
if [ -f "$EXT_YML" ]; then
    present="$(yq '(.installed // []) | contains(["multi-repo"])' "$EXT_YML" 2>/dev/null || echo false)"
    if [ "$present" = "true" ]; then
        if $DRY_RUN; then
            log "[extensions.yml] would remove multi-repo from installed:"
        else
            yq -i '.installed = ((.installed // []) - ["multi-repo"])' "$EXT_YML"
            log "[extensions.yml] removed multi-repo from installed:"
        fi
    else
        log "[extensions.yml] multi-repo not registered"
    fi
fi

# --- 3. Optionally purge the payload ---------------------------------------
EXT_DST="$ROOT/.specify/extensions/multi-repo"
if $PURGE && [ -d "$EXT_DST" ]; then
    if $DRY_RUN; then
        log "[payload] would delete $EXT_DST/"
    else
        rm -rf "$EXT_DST"
        log "[payload] deleted $EXT_DST/"
    fi
elif [ -d "$EXT_DST" ]; then
    log "[payload] left in place at $EXT_DST/ (pass --purge to remove)"
fi

log ""
log "Uninstall complete."
