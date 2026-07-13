#!/bin/bash
# Apply forge-provision's Brewfile via `brew bundle`.
# Idempotent: brew bundle skips already-installed entries.
# Reference: https://github.com/Homebrew/homebrew-bundle
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

# SCOPE=work selects manifests/Brewfile.work; env.sh resolves FORGE_BREWFILE.
if [[ -n "${SCOPE:-}" && "${SCOPE}" != "work" ]]; then
    echo "fail:brew-bundle (unknown SCOPE '${SCOPE}'; use 'work' or leave unset)"
    exit 1
fi
BREWFILE="${FORGE_BREWFILE}"

if [[ ! -f "${BREWFILE}" ]]; then
    echo "fail:brew-bundle (Brewfile not found at ${BREWFILE})"
    exit 1
fi

echo "scope:${SCOPE:-full} (${BREWFILE#"${FORGE_PROVISION_ROOT}/"})"

# brew-bundle globs before brew.sh in a topic run ('-' sorts before '.'), so a
# pristine machine reaches this script first. Bootstrap Homebrew inline instead
# of failing the very first step.
if ! command -v brew >/dev/null 2>&1; then
    echo "bootstrap:brew (not on PATH; running scripts/install/brew.sh)"
    bash "${SCRIPT_DIR}/brew.sh" || {
        echo "fail:brew-bundle (Homebrew bootstrap failed)"
        exit 1
    }
    [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
    command -v brew >/dev/null 2>&1 || {
        echo "fail:brew-bundle (brew still not on PATH after bootstrap)"
        exit 1
    }
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
