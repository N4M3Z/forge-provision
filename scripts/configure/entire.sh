#!/bin/bash
# Enable Entire session capture in one or more git repos with the privacy
# flags ARCH-0028 mandates for public repos: push_sessions disabled (the
# checkpoint branch carrying the full transcript must never ride a routine
# git push), settings kept local (gitignored), telemetry off.
#
# Guard pattern adapted from calebrosario/opencode-auto-entire: detect the
# enabled-state before agent work starts instead of discovering months of
# missing capture after the fact.
#
# Usage:
#   scripts/configure/entire.sh [--dry-run] [repo-path ...]
# With no paths, operates on the git repo containing the current directory.
#
# Idempotent: enabled repos with correct settings are skipped; enabled repos
# with push_sessions=true are flagged loudly but not auto-rewritten.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

DRY_RUN=0
REPOS=()
for arg in "$@"; do
    if [[ "$arg" == "--dry-run" ]]; then
        DRY_RUN=1
    else
        REPOS+=("$arg")
    fi
done

if ! command -v entire >/dev/null 2>&1; then
    echo "fail:entire (CLI not installed — brew tap entireio/tap && brew install --cask entire)"
    exit 1
fi

if [[ ${#REPOS[@]} -eq 0 ]]; then
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -z "$repo_root" ]]; then
        echo "fail:entire (not inside a git repo and no paths given)"
        exit 1
    fi
    REPOS=("$repo_root")
fi

for repo in "${REPOS[@]}"; do
    name=$(basename "$repo")
    if [[ ! -d "$repo/.git" ]]; then
        echo "skip:${name} (not a git repo)"
        continue
    fi

    # Read state from the settings files directly — `entire status` output
    # is formatted for humans and unreliable to parse non-interactively.
    # settings.local.json (gitignored, written by --local) wins over the
    # tracked settings.json.
    settings=""
    [[ -f "$repo/.entire/settings.local.json" ]] && settings="$repo/.entire/settings.local.json"
    [[ -z "$settings" && -f "$repo/.entire/settings.json" ]] && settings="$repo/.entire/settings.json"

    enabled=""
    push_sessions=""
    if [[ -n "$settings" ]]; then
        # No `// empty` here: jq's `//` treats boolean false as absent and
        # would swallow push_sessions=false. Bare paths print true/false/null.
        enabled=$(jq -r '.enabled' "$settings" 2>/dev/null)
        push_sessions=$(jq -r '.strategy_options.push_sessions' "$settings" 2>/dev/null)
    fi

    if [[ "$enabled" == "true" ]]; then
        if [[ "$push_sessions" == "false" ]]; then
            echo "skip:${name} (enabled, push_sessions=false)"
        else
            echo "warn:${name} (enabled but push_sessions is NOT false — a git push"
            echo "      would publish transcripts; fix with: entire configure --skip-push-sessions)"
        fi
        continue
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        echo "would-enable:${name}"
        continue
    fi

    if (cd "$repo" && entire enable --agent claude-code --skip-push-sessions --local --telemetry=false >/dev/null 2>&1); then
        echo "enable:${name} (claude-code hooks, push_sessions=false, local settings, telemetry off)"
    else
        echo "fail:${name} (entire enable returned non-zero — run 'entire doctor' in the repo)"
    fi
done
