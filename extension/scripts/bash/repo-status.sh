#!/usr/bin/env bash
# Report dirty/clean state + current branch for every repo in .specify/repos.yaml.
# Useful before /speckit-implement to make sure sibling repos are in a known state.
#
# Usage: repo-status.sh [--json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=multirepo-common.sh
. "$SCRIPT_DIR/multirepo-common.sh"

EMIT_JSON=false
case "${1:-}" in
    --json) EMIT_JSON=true ;;
    "") ;;
    *) echo "Usage: $0 [--json]" >&2; exit 1 ;;
esac

# Each row is TAB-separated: repo_id <TAB> status <TAB> branch <TAB> path.
# An empty branch/path field renders as JSON null. Keeping the raw fields here
# (instead of pre-rendered JSON) avoids parsing JSON back out for the table view.
results=()
overall_status=0

while IFS= read -r repo_id; do
    [ -z "$repo_id" ] && continue

    if ! repo_path="$(multirepo_repo_path "$repo_id" 2>/dev/null)"; then
        results+=("$repo_id"$'\t'"missing"$'\t'$'\t')
        overall_status=1
        continue
    fi

    if ! git -C "$repo_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        results+=("$repo_id"$'\t'"not-a-repo"$'\t'$'\t'"$repo_path")
        overall_status=1
        continue
    fi

    branch=$(git -C "$repo_path" rev-parse --abbrev-ref HEAD)
    if [ -z "$(git -C "$repo_path" status --porcelain)" ]; then
        state=clean
    else
        state=dirty
    fi

    results+=("$repo_id"$'\t'"$state"$'\t'"$branch"$'\t'"$repo_path")
done < <(multirepo_repo_ids)

# ${arr[@]+...} guards against "unbound variable" on an empty array under
# `set -u` in bash < 4.4 (macOS still ships bash 3.2).
if $EMIT_JSON; then
    printf '['
    sep=""
    for r in ${results[@]+"${results[@]}"}; do
        IFS=$'\t' read -r id st br pth <<<"$r"
        # Build JSON via yq so values can't produce malformed output; empty
        # branch/path become null.
        obj="$(id="$id" st="$st" br="$br" pth="$pth" yq -n -o=json -I=0 '{
            "repo_id": strenv(id),
            "status": strenv(st),
            "branch": (strenv(br) | select(. != "")) // null,
            "path": (strenv(pth) | select(. != "")) // null
        }')"
        printf '%s%s' "$sep" "$obj"
        sep=','
    done
    printf ']\n'
else
    printf '%-22s  %-12s  %s\n' "REPO" "STATE" "BRANCH @ PATH"
    printf '%-22s  %-12s  %s\n' "----" "-----" "-------------"
    for r in ${results[@]+"${results[@]}"}; do
        IFS=$'\t' read -r id st br pth <<<"$r"
        printf '%-22s  %-12s  %s @ %s\n' "$id" "$st" "${br:--}" "${pth:--}"
    done
fi

exit $overall_status
