#!/usr/bin/env bash
# Emit the workspace registry (.specify/repos.yaml) as a single JSON document.
# Used by skill overrides that need structured access to the repo list.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=multirepo-common.sh
. "$SCRIPT_DIR/multirepo-common.sh"

multirepo_config_json
