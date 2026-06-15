#!/usr/bin/env bash
# Create or check out a branch in one sibling repo. Idempotent:
#   - if the branch already exists locally → check it out
#   - if the branch exists on the remote   → fetch + check it out
#   - otherwise                            → create it from the configured base
#
# Usage: create-repo-branch.sh --repo <id> --name <branch> [--base <branch>] [--json]
#
# Exit codes:
#   0    success (already on branch, or switched/created)
#   1    bad arguments
#   2    repos.yaml not found
#   3    repo id unknown
#   4    repo path missing on disk
#   5    repo path is not a git working tree
#   6    uncommitted changes block the checkout
#   7    base branch not found locally or on origin
#   127  yq not installed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=multirepo-common.sh
. "$SCRIPT_DIR/multirepo-common.sh"

REPO_ID=""
BRANCH_NAME=""
BASE_OVERRIDE=""
EMIT_JSON=false

usage() {
    cat >&2 <<EOF
Usage: create-repo-branch.sh --repo <id> --name <branch> [--base <branch>] [--json]

Options:
  --repo <id>    Repo id from .specify/repos.yaml (required)
  --name <name>  Branch name to create or switch to (required; branch_prefix is applied)
  --base <name>  Override the configured base_branch (optional)
  --json         Emit a JSON result on stdout instead of human-readable text
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --repo) REPO_ID="${2:-}"; shift 2 ;;
        --name) BRANCH_NAME="${2:-}"; shift 2 ;;
        --base) BASE_OVERRIDE="${2:-}"; shift 2 ;;
        --json) EMIT_JSON=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "ERROR: unknown flag: $1" >&2; usage; exit 1 ;;
    esac
done

if [ -z "$REPO_ID" ] || [ -z "$BRANCH_NAME" ]; then
    usage
    exit 1
fi

REPO_PATH="$(multirepo_repo_path "$REPO_ID")" || exit $?

if ! git -C "$REPO_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "ERROR: $REPO_PATH is not a git working tree" >&2
    exit 5
fi

PREFIX="$(multirepo_branch_prefix "$REPO_ID")"
FULL_BRANCH="${PREFIX}${BRANCH_NAME}"

BASE_BRANCH="$BASE_OVERRIDE"
if [ -z "$BASE_BRANCH" ]; then
    BASE_BRANCH="$(multirepo_base_branch "$REPO_ID")"
fi

CURRENT_BRANCH=$(git -C "$REPO_PATH" rev-parse --abbrev-ref HEAD)

# Refuse to switch away from a dirty tree to avoid losing work. "Dirty" matches
# /speckit-multirepo-status exactly: any tracked change OR untracked file
# (git status --porcelain), so the two commands never disagree about a repo.
if [ "$CURRENT_BRANCH" != "$FULL_BRANCH" ] && [ -n "$(git -C "$REPO_PATH" status --porcelain)" ]; then
    echo "ERROR: $REPO_PATH has uncommitted changes; refusing to switch from $CURRENT_BRANCH to $FULL_BRANCH" >&2
    exit 6
fi

ACTION=""
if [ "$CURRENT_BRANCH" = "$FULL_BRANCH" ]; then
    ACTION="already-on-branch"
elif git -C "$REPO_PATH" show-ref --verify --quiet "refs/heads/$FULL_BRANCH"; then
    git -C "$REPO_PATH" checkout "$FULL_BRANCH" >&2
    ACTION="checked-out-existing"
elif git -C "$REPO_PATH" ls-remote --exit-code --heads origin "$FULL_BRANCH" >/dev/null 2>&1; then
    git -C "$REPO_PATH" fetch origin "$FULL_BRANCH" >&2
    git -C "$REPO_PATH" checkout -b "$FULL_BRANCH" "origin/$FULL_BRANCH" >&2
    ACTION="checked-out-from-remote"
else
    # Make sure the base branch is up-to-date before forking from it.
    if git -C "$REPO_PATH" ls-remote --exit-code --heads origin "$BASE_BRANCH" >/dev/null 2>&1; then
        git -C "$REPO_PATH" fetch origin "$BASE_BRANCH" >&2
        git -C "$REPO_PATH" checkout -b "$FULL_BRANCH" "origin/$BASE_BRANCH" >&2
    elif git -C "$REPO_PATH" show-ref --verify --quiet "refs/heads/$BASE_BRANCH"; then
        git -C "$REPO_PATH" checkout -b "$FULL_BRANCH" "$BASE_BRANCH" >&2
    else
        echo "ERROR: base branch '$BASE_BRANCH' not found locally or on origin in $REPO_PATH" >&2
        exit 7
    fi
    ACTION="created-from-base"
fi

if $EMIT_JSON; then
    # Build JSON via yq so values with quotes/backslashes can't produce invalid output.
    repo_id="$REPO_ID" repo_path="$REPO_PATH" branch="$FULL_BRANCH" base="$BASE_BRANCH" action="$ACTION" \
        yq -n -o=json -I=0 '{
            "repo_id": strenv(repo_id),
            "repo_path": strenv(repo_path),
            "branch": strenv(branch),
            "base": strenv(base),
            "action": strenv(action)
        }'
else
    printf '[%s] %s — %s (base: %s) at %s\n' \
        "$REPO_ID" "$ACTION" "$FULL_BRANCH" "$BASE_BRANCH" "$REPO_PATH"
fi
