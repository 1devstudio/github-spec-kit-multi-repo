#!/usr/bin/env bash
# Integration test for the multi-repo extension installer.
#
# Builds a throwaway stock-shaped Spec Kit project from test/fixtures/, then:
#   1. installs and verifies the payload + every injected block
#   2. re-installs and asserts the second run is a no-op (idempotency)
#   3. uninstalls and asserts every skill returns to its pre-install bytes
#   4. uninstalls --purge and asserts the payload directory is gone
#
# Requires: git, yq.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES="$SCRIPT_DIR/fixtures"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'ok: %s\n' "$*"; }

command -v yq  >/dev/null 2>&1 || fail "yq is required"
command -v git >/dev/null 2>&1 || fail "git is required"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- Build a stock-shaped Spec Kit project ---------------------------------
mkdir -p "$TMP/.specify" "$TMP/.claude/skills"
cp -R "$FIXTURES/skills/." "$TMP/.claude/skills/"
( cd "$TMP" && git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm init )

# Pristine copy of the skills for the restoration check.
ORIG="$TMP-orig"
cp -R "$TMP/.claude/skills" "$ORIG"

SKILLS=(speckit-specify speckit-plan speckit-tasks speckit-implement speckit-taskstoissues)

# --- 1. Install ------------------------------------------------------------
"$REPO_DIR/install.sh" --specify-root "$TMP" >/dev/null
[ -f "$TMP/.specify/extensions/multi-repo/extension.yml" ] || fail "payload not copied"
pass "payload copied"
[ "$(yq '(.installed // []) | contains(["multi-repo"])' "$TMP/.specify/extensions.yml")" = "true" ] \
    || fail "multi-repo not registered in extensions.yml"
pass "registered in extensions.yml"

# Every block id from the manifest must appear (as a START marker) in its skill.
mcount="$(yq '.blocks | length' "$REPO_DIR/skill-overrides/manifest.yaml")"
j=0
while [ "$j" -lt "$mcount" ]; do
    skill="$(yq -r ".blocks[$j].skill" "$REPO_DIR/skill-overrides/manifest.yaml")"
    bid="$(yq -r ".blocks[$j].block_id" "$REPO_DIR/skill-overrides/manifest.yaml")"
    j=$((j + 1))
    grep -qF "<!-- PRESET: multi-repo:$bid START -->" "$TMP/.claude/skills/$skill/SKILL.md" \
        || fail "block $bid not injected into $skill"
done
pass "all $mcount blocks injected"

# --- 2. Idempotency --------------------------------------------------------
SNAP1="$TMP-snap1"
cp -R "$TMP/.claude/skills" "$SNAP1"
cp "$TMP/.specify/extensions.yml" "$TMP-ext1.yml"
"$REPO_DIR/install.sh" --specify-root "$TMP" >/dev/null
diff -r "$SNAP1" "$TMP/.claude/skills" >/dev/null || fail "second install changed the skills (not idempotent)"
diff "$TMP-ext1.yml" "$TMP/.specify/extensions.yml" >/dev/null || fail "second install changed extensions.yml"
pass "re-install is a no-op (idempotent)"

# --- 3. Uninstall restores stock ------------------------------------------
"$REPO_DIR/uninstall.sh" --specify-root "$TMP" >/dev/null
for s in "${SKILLS[@]}"; do
    diff "$ORIG/$s/SKILL.md" "$TMP/.claude/skills/$s/SKILL.md" >/dev/null \
        || fail "$s not restored to pre-install state"
done
pass "all skills restored to pre-install bytes"
[ "$(yq '(.installed // []) | contains(["multi-repo"])' "$TMP/.specify/extensions.yml")" = "false" ] \
    || fail "multi-repo still registered after uninstall"
pass "deregistered from extensions.yml"
[ -d "$TMP/.specify/extensions/multi-repo" ] || fail "payload should remain without --purge"
pass "payload left in place without --purge"

# --- 4. Uninstall --purge removes payload ----------------------------------
"$REPO_DIR/uninstall.sh" --specify-root "$TMP" --purge >/dev/null
[ ! -d "$TMP/.specify/extensions/multi-repo" ] || fail "--purge did not delete payload"
pass "--purge deleted payload"

rm -rf "$ORIG" "$SNAP1" "$TMP-ext1.yml"
printf '\nALL TESTS PASSED\n'
