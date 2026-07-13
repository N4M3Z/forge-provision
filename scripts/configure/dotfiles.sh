#!/bin/bash
# Bootstrap chezmoi-managed dotfiles from github.com/${GITHUB_USER}/dotfiles.
# Deploys ~/.macos, shell rc files, and app configs that later configure
# scripts (macos-defaults.sh, zed.sh, dcg.sh) consume.
# Idempotent: an initialized chezmoi source converges via `chezmoi apply`.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if ! command -v chezmoi >/dev/null 2>&1; then
    echo "fail:dotfiles (chezmoi not on PATH; run scripts/install/brew-bundle.sh)"
    exit 1
fi

if [[ -n "${FORGE_ENV_DEFAULTS:-}" ]]; then
    echo "fail:dotfiles (.env missing; refusing to clone the placeholder dotfiles repo)"
    echo "      cp .env.example .env and set GITHUB_USER"
    exit 1
fi

CHEZMOI_SOURCE="${HOME}/.local/share/chezmoi"

if [[ -d "${CHEZMOI_SOURCE}/.git" ]]; then
    echo "apply:dotfiles (source present; converging)"
    chezmoi apply || {
        echo "fail:dotfiles (chezmoi apply failed)"
        exit 1
    }
else
    echo "init:dotfiles (github.com/${GITHUB_USER}/dotfiles)"
    chezmoi init --apply "${GITHUB_USER}" || {
        echo "fail:dotfiles (chezmoi init failed; check repo access and GITHUB_USER)"
        exit 1
    }
fi

echo "ok:dotfiles"
echo "      verify: chezmoi verify || chezmoi diff"
