#!/usr/bin/env bash
# Deploy and verify the chezmoi-owned Jujutsu configuration.
#
# The canonical config is dotfiles/dot_config/jj/config.toml; this script runs
# a targeted `chezmoi apply` of it and then verifies the signing contract:
#
# signing.behavior is "drop" and git.sign-on-push is off: commits and pushes
# stay unsigned, so agent sessions never hit pinentry or the YubiKey mid-push.
# The owner's signature enters at release tags, and the signed tag vouches for
# the history beneath it. GitHub vigilant mode stays off, or unsigned commits
# render as Unverified.
#
# jj does not inherit git's identity or signing key at runtime; it keeps its own
# config, which is why the contract needs verifying at all.
#
# Decision: docs/decisions/ARCH-0032 (jj colocated) + ARCH-0006 (signing).
#
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

dotfiles_source="${DOTFILES_SOURCE:-${HOME}/Developer/N4M3Z/dotfiles}"
target="${XDG_CONFIG_HOME:-${HOME}/.config}/jj/config.toml"

if ! command -v jj >/dev/null 2>&1; then
    echo "fail:jujutsu (jj not found; install it via the Brewfile)"
    exit 0
fi
if ! command -v chezmoi >/dev/null 2>&1; then
    echo "fail:jujutsu (chezmoi not found; jj config remains unchanged)"
    exit 0
fi
if [[ ! -f "${dotfiles_source}/dot_config/jj/config.toml" ]]; then
    echo "fail:jujutsu (canonical chezmoi source missing at ${dotfiles_source}/dot_config/jj/config.toml)"
    exit 0
fi

if ! chezmoi \
    --source "$dotfiles_source" \
    --destination "$HOME" \
    --no-tty \
    --refresh-externals=never \
    apply "$target"; then
    echo "fail:jujutsu (targeted chezmoi apply failed)"
    exit 0
fi

verify_value() {
    local key="$1" expected="$2" actual

    actual="$(jj config get --user "$key" 2>/dev/null)"
    if [[ "$actual" != "$expected" ]]; then
        echo "fail:jujutsu (${key} expected ${expected}, got ${actual:-unset})"
        return 1
    fi
}

failures=0
verify_value signing.backend gpg || failures=$((failures + 1))
verify_value signing.behavior drop || failures=$((failures + 1))
verify_value git.sign-on-push false || failures=$((failures + 1))
if ! jj config get --user aliases.push >/dev/null 2>&1; then
    echo "fail:jujutsu (aliases.push is missing)"
    failures=$((failures + 1))
fi

if [[ "$failures" -gt 0 ]]; then
    echo "fail:jujutsu (${failures} verification check(s) failed)"
    exit 0
fi

echo "ok:jujutsu (chezmoi-owned config converged)"
echo "      verify: jj config list --user"
