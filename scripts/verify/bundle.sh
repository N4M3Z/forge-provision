#!/bin/bash
# Verify the scope-selected Brewfile is satisfied. env.sh resolves
# FORGE_BREWFILE from SCOPE, so the same command checks the right manifest on
# a full personal machine and a work-scoped one.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if ! command -v brew >/dev/null 2>&1; then
    echo "fail:bundle (brew not on PATH)"
    exit 1
fi

echo "check:${FORGE_BREWFILE#"${FORGE_PROVISION_ROOT}/"} (scope ${SCOPE:-full})"
if brew bundle check --file="${FORGE_BREWFILE}"; then
    echo "ok:bundle"
else
    echo "fail:bundle (missing entries — run scripts/install/brew-bundle.sh)"
    exit 1
fi
