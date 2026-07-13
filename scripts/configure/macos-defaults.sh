#!/bin/bash
# Delegate to the canonical .macos script deployed by chezmoi from
# github.com/N4M3Z/dotfiles (source: dot_macos → ~/.macos).
#
# Rationale: docs/decisions/ARCH-0017 macOS defaults pattern and location.
# Defaults values are user data and live in the dotfiles repo; this script
# is only the entry point from `./provision.sh --topic configure`.

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

MACOS_SCRIPT="${HOME}/.macos"

if [[ ! -f "${MACOS_SCRIPT}" ]]; then
    # ~/.macos ships in the dotfiles repo. When no dotfiles source is
    # configured, this step has nothing to apply and skips rather than fails.
    if [[ -z "${DOTFILES_REPO:-}" ]]; then
        echo "skip:macos-defaults (no ~/.macos; DOTFILES_REPO unset, so no dotfiles deployed)"
        exit 0
    fi
    echo "fail:macos-defaults"
    echo "      ${MACOS_SCRIPT} not found. Run scripts/configure/dotfiles.sh (chezmoi init --apply) first."
    exit 1
fi

exec bash "${MACOS_SCRIPT}"
