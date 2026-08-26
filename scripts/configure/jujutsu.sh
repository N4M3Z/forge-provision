#!/usr/bin/env bash
# Deploy and verify the chezmoi-owned Jujutsu configuration.
#
# The canonical config is dotfiles/dot_config/jj/config.toml; this script runs
# a targeted `chezmoi apply` of it and then verifies the signing contract:
#
# signing.behavior is "drop" so jj does not sign on every working-copy snapshot
# (that would touch the YubiKey on nearly every command); git.sign-on-push signs
# the pushed commits in one batch instead. Under the cached touch policy that is
# one touch per push, and pushed commits still land "Verified" on GitHub.
#
# jj does not inherit git's identity or signing key at runtime; it keeps its own
# config, which is why the contract needs verifying at all.
#
# Decision: docs/decisions/ARCH-0032 (jj colocated) + ARCH-0006 (signing).
#
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

target="${XDG_CONFIG_HOME:-${HOME}/.config}/jj/config.toml"

if ! command -v jj >/dev/null 2>&1; then
    echo "fail:jujutsu (jj not found; install it via the Brewfile)"
    exit 1
fi
if ! command -v chezmoi >/dev/null 2>&1; then
    echo "fail:jujutsu (chezmoi not found; jj config remains unchanged)"
    exit 1
fi

# Ask chezmoi where its source is rather than guessing a clone location. The
# default is ~/.local/share/chezmoi, and a guess of ~/Developer/<account>/dotfiles
# is wrong on any machine that installed the dotfiles the ordinary way, besides
# hardcoding one person's account name. DOTFILES_SOURCE still overrides, for a
# machine that keeps a second checkout deliberately.
dotfiles_source="${DOTFILES_SOURCE:-$(chezmoi source-path 2>/dev/null)}"

if [[ -z "${dotfiles_source}" ]]; then
    echo "fail:jujutsu (chezmoi could not report a source path; run 'chezmoi init' first)"
    exit 1
fi
if [[ ! -f "${dotfiles_source}/dot_config/jj/config.toml" ]]; then
    echo "fail:jujutsu (no jj config in the chezmoi source at ${dotfiles_source})"
    exit 1
fi

if ! chezmoi \
    --source "$dotfiles_source" \
    --destination "$HOME" \
    --no-tty \
    --refresh-externals=never \
    apply "$target"; then
    echo "fail:jujutsu (targeted chezmoi apply failed)"
    exit 1
fi

# Read one user-scoped value. `jj config get` takes no --user flag, so asking it
# for one errors out; with stderr discarded that produced an empty result and
# every key was reported unset while the config was in fact correct. `config
# list` does take --user, and its value template returns the value alone, quoted
# for strings and bare for booleans.
read_user_value() {
    local value
    value="$(jj config list --user --template value "$1" 2>/dev/null)"
    value="${value#\"}"
    printf '%s' "${value%\"}"
}

# Fail loudly if that interface ever moves again, rather than reporting a correct
# config as unset. A check that cannot distinguish "wrong value" from "cannot
# read values" is worse than no check.
if ! jj config list --user --template value signing.backend >/dev/null 2>&1; then
    echo "fail:jujutsu (this jj does not support 'config list --user --template'; the check needs updating)"
    echo "      installed: $(jj --version 2>/dev/null)"
    exit 1
fi

verify_value() {
    local key="$1" expected="$2" actual
    actual="$(read_user_value "$key")"

    if [[ -z "${actual}" ]]; then
        echo "fail:jujutsu (${key} is not set in the user config)"
        return 1
    fi
    if [[ "${actual}" != "${expected}" ]]; then
        echo "fail:jujutsu (${key} expected ${expected}, got ${actual})"
        return 1
    fi
}

failures=0
verify_value signing.backend gpg || failures=$((failures + 1))
verify_value signing.behavior drop || failures=$((failures + 1))
verify_value git.sign-on-push true || failures=$((failures + 1))
if [[ -z "$(read_user_value aliases.push)" ]]; then
    echo "fail:jujutsu (aliases.push is missing)"
    failures=$((failures + 1))
fi

if [[ "$failures" -gt 0 ]]; then
    echo "fail:jujutsu (${failures} verification check(s) failed)"
    exit 1
fi

echo "ok:jujutsu (chezmoi-owned config converged)"
echo "      verify: jj config list --user"
