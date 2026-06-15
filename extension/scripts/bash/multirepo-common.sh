#!/usr/bin/env bash
# Shared helpers for the multi-repo extension.

set -u

# Resolve the Spec Kit root repo regardless of where the script was invoked from.
multirepo_repo_root() {
    git rev-parse --show-toplevel 2>/dev/null
}

# Path to the workspace registry.
multirepo_config_path() {
    local root
    root="$(multirepo_repo_root)" || return 1
    printf '%s/.specify/repos.yaml\n' "$root"
}

# Fail fast if yq isn't installed. We use the Go yq (mikefarah/yq) JSON output.
multirepo_require_yq() {
    if ! command -v yq >/dev/null 2>&1; then
        echo "ERROR: yq is required by the multi-repo extension." >&2
        echo "Install on macOS: brew install yq" >&2
        echo "Install elsewhere: https://github.com/mikefarah/yq#install" >&2
        return 127
    fi
}

# Emit the full repos.yaml as JSON to stdout.
multirepo_config_json() {
    multirepo_require_yq || return $?
    local cfg
    cfg="$(multirepo_config_path)" || return 1
    if [ ! -f "$cfg" ]; then
        echo "ERROR: .specify/repos.yaml not found at $cfg" >&2
        return 2
    fi
    yq -o=json '.' "$cfg"
}

# Print the absolute path for a repo id (resolves repo.path against the Spec Kit root repo).
multirepo_repo_path() {
    local repo_id="$1"
    multirepo_require_yq || return $?
    local root cfg rel
    root="$(multirepo_repo_root)" || return 1
    cfg="$(multirepo_config_path)" || return 1
    rel=$(yq -r ".repos[] | select(.id == \"$repo_id\") | .path" "$cfg")
    if [ -z "$rel" ] || [ "$rel" = "null" ]; then
        echo "ERROR: repo id '$repo_id' not found in $cfg" >&2
        return 3
    fi
    # Resolve relative paths against the Spec Kit root repo.
    if [[ "$rel" = /* ]]; then
        printf '%s\n' "$rel"
    else
        (cd "$root" && cd "$rel" 2>/dev/null && pwd) || {
            echo "ERROR: repo path '$rel' for id '$repo_id' does not exist on disk" >&2
            return 4
        }
    fi
}

# Echo the configured base_branch for a repo id (falling back to defaults.base_branch).
multirepo_base_branch() {
    local repo_id="$1"
    multirepo_require_yq || return $?
    local cfg
    cfg="$(multirepo_config_path)" || return 1
    local value
    value=$(yq -r "
        (.repos[] | select(.id == \"$repo_id\") | .base_branch) //
        .defaults.base_branch //
        \"main\"
    " "$cfg")
    printf '%s\n' "$value"
}

# Echo the configured branch_prefix for a repo id (falling back to defaults.branch_prefix).
multirepo_branch_prefix() {
    local repo_id="$1"
    multirepo_require_yq || return $?
    local cfg
    cfg="$(multirepo_config_path)" || return 1
    local value
    value=$(yq -r "
        (.repos[] | select(.id == \"$repo_id\") | .branch_prefix) //
        .defaults.branch_prefix //
        \"\"
    " "$cfg")
    [ "$value" = "null" ] && value=""
    printf '%s\n' "$value"
}

# Echo the configured github slug ("owner/repo") for a repo id.
multirepo_github_slug() {
    local repo_id="$1"
    multirepo_require_yq || return $?
    local cfg
    cfg="$(multirepo_config_path)" || return 1
    local value
    value=$(yq -r "(.repos[] | select(.id == \"$repo_id\") | .github) // \"\"" "$cfg")
    [ "$value" = "null" ] && value=""
    printf '%s\n' "$value"
}

# Echo every repo id in declaration order.
multirepo_repo_ids() {
    multirepo_require_yq || return $?
    local cfg
    cfg="$(multirepo_config_path)" || return 1
    yq -r '.repos[].id' "$cfg"
}
