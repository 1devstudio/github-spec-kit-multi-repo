#!/usr/bin/env bash
# Install the multi-repo extension into a Spec Kit project.
#
# Idempotent:
#   - copies the extension payload into <root>/.specify/extensions/multi-repo/
#   - registers "multi-repo" in <root>/.specify/extensions.yml
#   - injects each skill-override block from skill-overrides/manifest.yaml into the
#     matching <root>/.claude/skills/<skill>/SKILL.md, wrapped in namespaced
#     `<!-- PRESET: multi-repo:<block-id> START/END -->` markers. Re-running
#     updates blocks in place rather than duplicating them.
#
# Usage: install.sh [--specify-root <path>] [--dry-run]
#
# Exit codes:
#   0  success
#   1  bad arguments
#   2  target is not a Spec Kit project
#   3  yq missing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT_SRC="$SCRIPT_DIR/extension"
OVERRIDES_DIR="$SCRIPT_DIR/skill-overrides"
MANIFEST="$OVERRIDES_DIR/manifest.yaml"

ROOT=""
DRY_RUN=false

usage() {
    cat >&2 <<EOF
Usage: install.sh [--specify-root <path>] [--dry-run]

Options:
  --specify-root <path>  Spec Kit project root (default: git rev-parse --show-toplevel)
  --dry-run              Print every planned change without writing anything
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --specify-root) ROOT="${2:-}"; shift 2 ;;
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

# --- 1. Copy the extension payload -----------------------------------------
EXT_DST="$ROOT/.specify/extensions/multi-repo"
if $DRY_RUN; then
    log "[payload] would copy $EXT_SRC/ -> $EXT_DST/"
else
    mkdir -p "$EXT_DST"
    cp -R "$EXT_SRC"/. "$EXT_DST"/
    find "$EXT_DST/scripts/bash" -name '*.sh' -exec chmod +x {} +
    log "[payload] copied -> $EXT_DST/"
fi

# --- 2. Register in extensions.yml -----------------------------------------
EXT_YML="$ROOT/.specify/extensions.yml"
register_extension() {
    if [ ! -f "$EXT_YML" ]; then
        if $DRY_RUN; then
            log "[extensions.yml] would create $EXT_YML with installed: [multi-repo]"
        else
            printf 'installed:\n  - multi-repo\n' > "$EXT_YML"
            log "[extensions.yml] created with installed: [multi-repo]"
        fi
        return
    fi
    local present
    present="$(yq '(.installed // []) | contains(["multi-repo"])' "$EXT_YML" 2>/dev/null || echo false)"
    if [ "$present" = "true" ]; then
        log "[extensions.yml] multi-repo already registered"
    elif $DRY_RUN; then
        log "[extensions.yml] would add multi-repo to installed:"
    else
        yq -i '.installed = ((.installed // []) + ["multi-repo"])' "$EXT_YML"
        log "[extensions.yml] added multi-repo to installed:"
    fi
}
register_extension

# --- 3. Inject skill-override blocks ---------------------------------------
# Build the wrapped block (START marker + fragment + END marker) for a block id.
build_wrapped() {
    local block_id="$1" frag_file="$2" out="$3"
    {
        printf '<!-- PRESET: multi-repo:%s START -->\n' "$block_id"
        cat "$frag_file"
        printf '<!-- PRESET: multi-repo:%s END -->\n' "$block_id"
    } > "$out"
}

block_count="$(yq '.blocks | length' "$MANIFEST")"
i=0
while [ "$i" -lt "$block_count" ]; do
    skill="$(yq -r ".blocks[$i].skill" "$MANIFEST")"
    block_id="$(yq -r ".blocks[$i].block_id" "$MANIFEST")"
    mode="$(yq -r ".blocks[$i].mode" "$MANIFEST")"
    anchor="$(yq -r ".blocks[$i].anchor" "$MANIFEST")"
    frag_rel="$(yq -r ".blocks[$i].fragment" "$MANIFEST")"
    i=$((i + 1))

    skill_file="$ROOT/.claude/skills/$skill/SKILL.md"
    frag_file="$OVERRIDES_DIR/$frag_rel"
    start_marker="<!-- PRESET: multi-repo:$block_id START -->"

    if [ "$mode" != "after" ]; then
        log "[$skill:$block_id] WARN unsupported mode '$mode' — skipping"
        continue
    fi
    if [ ! -f "$skill_file" ]; then
        log "[$skill:$block_id] WARN skill not found at $skill_file — skipping"
        continue
    fi
    if [ ! -f "$frag_file" ]; then
        log "[$skill:$block_id] WARN fragment not found at $frag_file — skipping"
        continue
    fi

    wrapped="$(mktemp)"
    new_file="$(mktemp)"
    build_wrapped "$block_id" "$frag_file" "$wrapped"

    if grep -qF -- "$start_marker" "$skill_file"; then
        # Markers present: replace everything between START and END (inclusive).
        awk -v frag="$wrapped" -v block="$block_id" '
            $0 ~ ("<!-- PRESET: multi-repo:" block " START -->") {
                while ((getline l < frag) > 0) print l
                close(frag); skip = 1; next
            }
            $0 ~ ("<!-- PRESET: multi-repo:" block " END -->") { skip = 0; next }
            !skip { print }
        ' "$skill_file" > "$new_file"
        verb="updated"
    else
        # Markers absent: insert wrapped block after the first anchor line.
        if ! grep -qF -- "$anchor" "$skill_file"; then
            log "[$skill:$block_id] WARN anchor not found — skipping (skill may have drifted)"
            rm -f "$wrapped" "$new_file"
            continue
        fi
        awk -v anchor="$anchor" -v frag="$wrapped" '
            { print }
            !done && index($0, anchor) {
                while ((getline l < frag) > 0) print l
                close(frag); done = 1
            }
        ' "$skill_file" > "$new_file"
        verb="injected"
    fi

    if cmp -s "$skill_file" "$new_file"; then
        log "[$skill:$block_id] no change"
    elif $DRY_RUN; then
        log "[$skill:$block_id] would be $verb:"
        diff -u "$skill_file" "$new_file" >&2 || true
    else
        cat "$new_file" > "$skill_file"
        log "[$skill:$block_id] $verb"
    fi
    rm -f "$wrapped" "$new_file"
done

log ""
log "Done. Next step: create your registry —"
log "  cp $EXT_DST/config-template.yaml $ROOT/.specify/repos.yaml"
log "  (see examples/repos.inspiren.yaml for a worked example)"
