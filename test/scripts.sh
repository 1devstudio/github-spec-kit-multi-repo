#!/usr/bin/env bash
# Unit/integration tests for the multi-repo runtime helper scripts:
#   multirepo-common.sh, parse-repos-yaml.sh, create-repo-branch.sh, repo-status.sh
#
# Builds throwaway sibling-repo workspaces under a temp dir and exercises the
# scripts the way /speckit-implement and the slash commands do (CWD inside the
# Spec Kit root repo, which the scripts locate via `git rev-parse`).
#
# Requires: git, yq.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASH_DIR="$(cd "$SCRIPT_DIR/../extension/scripts/bash" && pwd)"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'ok: %s\n' "$*"; }

command -v yq  >/dev/null 2>&1 || fail "yq is required"
command -v git >/dev/null 2>&1 || fail "git is required"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Make a git repo at $1 with a `main` branch and one commit.
mkrepo() {
    git init -q -b main "$1"
    git -C "$1" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
}

# Assert two values are equal.
eq() { [ "$2" = "$3" ] || fail "$1: expected '$3', got '$2'"; }

# Run a command and assert its exit code.
expect_rc() {
    local exp="$1"; shift
    local rc=0
    "$@" >/dev/null 2>&1 || rc=$?
    [ "$rc" = "$exp" ] || fail "expected rc=$exp, got rc=$rc, from: $*"
}

# Extract one field from a JSON blob on stdin.
jget() { yq -p=json -r "$1"; }

# --- Build a workspace -----------------------------------------------------
# workspace/
#   root/   (Spec Kit root repo, holds .specify/repos.yaml)
#   app/    (sibling; explicit base_branch + empty prefix + github)
#   web/    (sibling; no base_branch -> default, "feature/" prefix, no github)
#   (ghost path ../missing is intentionally never created)
WS="$TMP/ws"
mkdir -p "$WS"
mkrepo "$WS/root"
mkrepo "$WS/app"
mkrepo "$WS/web"
mkdir -p "$WS/root/.specify"
cat > "$WS/root/.specify/repos.yaml" <<'YAML'
schema_version: "1.0"
defaults:
  base_branch: main
  branch_prefix: ""
repos:
  - id: app
    path: ../app
    role: [backend]
    stack: [typescript]
    branch_prefix: ""
    base_branch: main
    github: acme/app
  - id: web
    path: ../web
    branch_prefix: "feature/"
  - id: ghost
    path: ../missing
YAML

cd "$WS/root"

# --- 1. parse-repos-yaml.sh ------------------------------------------------
json="$("$BASH_DIR/parse-repos-yaml.sh")"
eq "repo count"        "$(printf '%s' "$json" | jget '.repos | length')" "3"
eq "first repo id"     "$(printf '%s' "$json" | jget '.repos[0].id')"    "app"
eq "defaults.base"     "$(printf '%s' "$json" | jget '.defaults.base_branch')" "main"
pass "parse-repos-yaml.sh emits the registry as JSON"

# --- 2. multirepo-common.sh accessors --------------------------------------
# shellcheck source=../extension/scripts/bash/multirepo-common.sh
. "$BASH_DIR/multirepo-common.sh"

eq "repo ids"          "$(multirepo_repo_ids | tr '\n' ',')" "app,web,ghost,"
eq "app base_branch"   "$(multirepo_base_branch app)"   "main"
eq "web base fallback" "$(multirepo_base_branch web)"   "main"   # inherits defaults
eq "web prefix"        "$(multirepo_branch_prefix web)" "feature/"
eq "app prefix empty"  "$(multirepo_branch_prefix app)" ""
eq "app github"        "$(multirepo_github_slug app)"   "acme/app"
eq "web github empty"  "$(multirepo_github_slug web)"   ""
case "$(multirepo_repo_path app)" in */app) ;; *) fail "repo_path app wrong" ;; esac
expect_rc 4 multirepo_repo_path ghost      # path declared but missing on disk
expect_rc 3 multirepo_repo_path nope       # id not in registry
pass "multirepo-common.sh accessors resolve ids, paths, and defaults"

# --- 3. create-repo-branch.sh ----------------------------------------------
# new branch forks from the configured base (main) — the path that used to
# fail when base_branch was the unimplemented "this" sentinel.
out="$("$BASH_DIR/create-repo-branch.sh" --repo app --name F-1 --json)"
eq "create action" "$(printf '%s' "$out" | jget '.action')" "created-from-base"
eq "create branch" "$(printf '%s' "$out" | jget '.branch')" "F-1"
eq "create base"   "$(printf '%s' "$out" | jget '.base')"   "main"
eq "app on F-1"    "$(git -C "$WS/app" rev-parse --abbrev-ref HEAD)" "F-1"

# re-running while already on the branch is a no-op.
out="$("$BASH_DIR/create-repo-branch.sh" --repo app --name F-1 --json)"
eq "idempotent action" "$(printf '%s' "$out" | jget '.action')" "already-on-branch"

# an existing local branch is checked out, not recreated.
git -C "$WS/app" branch B-2 main
out="$("$BASH_DIR/create-repo-branch.sh" --repo app --name B-2 --json)"
eq "existing action" "$(printf '%s' "$out" | jget '.action')" "checked-out-existing"

# branch_prefix is applied automatically.
out="$("$BASH_DIR/create-repo-branch.sh" --repo web --name X-9 --json)"
eq "prefixed branch" "$(printf '%s' "$out" | jget '.branch')" "feature/X-9"

# --base overrides the configured base.
git -C "$WS/app" branch dev main
out="$("$BASH_DIR/create-repo-branch.sh" --repo app --name S-1 --base dev --json)"
eq "override base"   "$(printf '%s' "$out" | jget '.base')"   "dev"
eq "override action" "$(printf '%s' "$out" | jget '.action')" "created-from-base"

# a dirty working tree blocks switching away (exit 6).
git -C "$WS/app" checkout -q main
echo dirty > "$WS/app/tracked.txt"
git -C "$WS/app" add tracked.txt
git -C "$WS/app" -c user.email=t@t -c user.name=t commit -q -m add
echo more >> "$WS/app/tracked.txt"     # now dirty vs HEAD
expect_rc 6 "$BASH_DIR/create-repo-branch.sh" --repo app --name F-1
git -C "$WS/app" checkout -q -- tracked.txt   # clean up for later

# unknown id and missing args fail with documented codes.
expect_rc 3 "$BASH_DIR/create-repo-branch.sh" --repo nope --name X
expect_rc 1 "$BASH_DIR/create-repo-branch.sh" --repo app
pass "create-repo-branch.sh: create/idempotent/existing/prefix/override/dirty/errors"

# --- 4. repo-status.sh -----------------------------------------------------
# (exits non-zero because ghost is missing, hence the `|| true` on captures)
out="$("$BASH_DIR/repo-status.sh" --json || true)"
eq "status app"   "$(printf '%s' "$out" | jget '.[] | select(.repo_id=="app")   | .status')" "clean"
eq "status ghost" "$(printf '%s' "$out" | jget '.[] | select(.repo_id=="ghost") | .status')" "missing"

# a dirty tree is reported as dirty.
echo wip >> "$WS/app/tracked.txt"
out="$("$BASH_DIR/repo-status.sh" --json || true)"
eq "status dirty" "$(printf '%s' "$out" | jget '.[] | select(.repo_id=="app") | .status')" "dirty"
git -C "$WS/app" checkout -q -- tracked.txt

# a missing repo makes the overall exit code non-zero.
expect_rc 1 "$BASH_DIR/repo-status.sh"

# table mode renders a row per repo.
"$BASH_DIR/repo-status.sh" >/dev/null 2>&1 || true   # non-zero exit (ghost) is fine
table="$("$BASH_DIR/repo-status.sh" 2>/dev/null || true)"
printf '%s' "$table" | grep -q '^app ' || fail "table mode missing app row"
pass "repo-status.sh reports clean/dirty/missing in table and JSON"

# --- 5. empty registry must not crash (bash < 4.4 empty-array guard) -------
EWS="$TMP/empty"
mkrepo "$EWS"
mkdir -p "$EWS/.specify"
printf 'schema_version: "1.0"\nrepos: []\n' > "$EWS/.specify/repos.yaml"
out="$(cd "$EWS" && "$BASH_DIR/repo-status.sh" --json)"
eq "empty json"  "$out" "[]"
( cd "$EWS" && "$BASH_DIR/repo-status.sh" >/dev/null ) || fail "empty registry table crashed"
pass "repo-status.sh handles an empty registry without crashing"

printf '\nALL TESTS PASSED\n'
