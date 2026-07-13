#!/bin/bash
# Apply forge-provision's Brewfile via `brew bundle`.
# Idempotent: brew bundle skips already-installed entries.
# Reference: https://github.com/Homebrew/homebrew-bundle
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

# SCOPE=work (from .env) selects the corporate-laptop subset manifest;
# unset means the full personal Brewfile.
case "${SCOPE:-}" in
    work) BREWFILE="${FORGE_PROVISION_ROOT}/manifests/Brewfile.work" ;;
    "")   BREWFILE="${FORGE_PROVISION_ROOT}/manifests/Brewfile" ;;
    *)
        echo "fail:brew-bundle (unknown SCOPE '${SCOPE}'; use 'work' or leave unset)"
        exit 1
        ;;
esac

if [[ ! -f "${BREWFILE}" ]]; then
    echo "fail:brew-bundle (Brewfile not found at ${BREWFILE})"
    exit 1
fi

echo "scope:${SCOPE:-full} (${BREWFILE#"${FORGE_PROVISION_ROOT}/"})"

if ! command -v brew >/dev/null 2>&1; then
    echo "fail:brew-bundle (brew not on PATH — run scripts/install/brew.sh first)"
    exit 1
fi

# Newer Homebrew refuses to load formulae from non-official taps unless they are
# trusted, when HOMEBREW_REQUIRE_TAP_TRUST is set. Trust every tap the Brewfile
# declares so the bundle apply below never stalls on an untrusted-tap prompt.
# Derived from the Brewfile so the trust list cannot drift from the declared taps.
# brew trust is idempotent: re-trusting an already-trusted tap is a no-op.
declared_taps=$(awk '/^tap "/ { gsub(/"/, ""); print $2 }' "${BREWFILE}")
if [[ -n "${declared_taps}" ]]; then
    echo "trust:taps"
    # shellcheck disable=SC2086
    brew trust --tap ${declared_taps}
fi

echo "apply:Brewfile"
brew bundle install --file="${BREWFILE}"
