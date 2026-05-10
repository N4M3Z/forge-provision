#!/bin/bash
# Apply forge-provision's Brewfile via `brew bundle`.
# Idempotent: brew bundle skips already-installed entries.
# Reference: https://github.com/Homebrew/homebrew-bundle
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

BREWFILE="${FORGE_PROVISION_ROOT}/manifests/Brewfile"

if [[ ! -f "${BREWFILE}" ]]; then
    echo "fail:brew-bundle (Brewfile not found at ${BREWFILE})"
    exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
    echo "fail:brew-bundle (brew not on PATH — run scripts/install/brew.sh first)"
    exit 1
fi

echo "apply:Brewfile"
brew bundle install --file="${BREWFILE}"
