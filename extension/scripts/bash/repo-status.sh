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

results=()
overall_status=0

while IFS= read -r repo_id; do
    [ -z "$repo_id" ] && continue

    if ! repo_path="$(multirepo_repo_path "$repo_id" 2>/dev/null)"; then
        results+=("$(printf '{"repo_id":"%s","status":"missing","branch":null,"path":null}' "$repo_id")")
        overall_status=1
        continue
    fi

    if ! git -C "$repo_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        results+=("$(printf '{"repo_id":"%s","status":"not-a-repo","branch":null,"path":"%s"}' "$repo_id" "$repo_path")")
        overall_status=1
        continue
    fi

    branch=$(git -C "$repo_path" rev-parse --abbrev-ref HEAD)
    if [ -z "$(git -C "$repo_path" status --porcelain)" ]; then
        state=clean
    else
        state=dirty
    fi

    results+=("$(printf '{"repo_id":"%s","status":"%s","branch":"%s","path":"%s"}' "$repo_id" "$state" "$branch" "$repo_path")")
done < <(multirepo_repo_ids)

if $EMIT_JSON; then
    printf '['
    sep=""
    for r in "${results[@]}"; do
        printf '%s%s' "$sep" "$r"
        sep=','
    done
    printf ']\n'
else
    printf '%-22s  %-12s  %s\n' "REPO" "STATE" "BRANCH @ PATH"
    printf '%-22s  %-12s  %s\n' "----" "-----" "-------------"
    for r in "${results[@]}"; do
        repo_id=$(printf '%s' "$r" | sed -E 's/.*"repo_id":"([^"]*)".*/\1/')
        status=$(printf '%s' "$r" | sed -E 's/.*"status":"([^"]*)".*/\1/')
        branch=$(printf '%s' "$r" | sed -E 's/.*"branch":(null|"([^"]*)").*/\2/')
        path=$(printf '%s' "$r" | sed -E 's/.*"path":(null|"([^"]*)").*/\2/')
        printf '%-22s  %-12s  %s @ %s\n' "$repo_id" "$status" "${branch:--}" "${path:--}"
    done
fi

exit $overall_status
