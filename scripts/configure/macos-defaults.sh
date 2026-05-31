#!/bin/bash
# Delegate to the canonical .macos script deployed by chezmoi from
# github.com/N4M3Z/dotfiles (source: dot_macos → ~/.macos).
#
# Rationale: docs/decisions/ARCH-0017 macOS defaults pattern and location.
# Defaults values are user data and live in the dotfiles repo; this script
# is only the entry point from `./provision.sh --topic configure`.

MACOS_SCRIPT="${HOME}/.macos"

if [[ ! -f "${MACOS_SCRIPT}" ]]; then
    echo "fail:macos-defaults"
    echo "      ${MACOS_SCRIPT} not found. Run 'chezmoi apply' first to deploy dot_macos."
    exit 1
fi

exec bash "${MACOS_SCRIPT}"
