#!/bin/bash
# Bootstrap chezmoi-managed dotfiles from DOTFILES_REPO (.env).
# Deploys ~/.macos, shell rc files, and app configs that later configure
# scripts (macos-defaults.sh, zed.sh, dcg.sh) consume.
# Idempotent: an initialized chezmoi source converges via `chezmoi apply`.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if [[ -z "${DOTFILES_REPO:-}" ]]; then
    echo "skip:dotfiles (DOTFILES_REPO unset in .env; no dotfiles deployed)"
    echo "      macos-defaults and other chezmoi-consuming steps will skip or fail"
    exit 0
fi

if ! command -v chezmoi >/dev/null 2>&1; then
    echo "fail:dotfiles (chezmoi not on PATH; run scripts/install/brew-bundle.sh)"
    exit 1
fi

if [[ -n "${FORGE_ENV_DEFAULTS:-}" ]]; then
    echo "fail:dotfiles (.env missing; refusing to clone a placeholder dotfiles repo)"
    echo "      cp .env.example .env and set DOTFILES_REPO"
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
    echo "init:dotfiles (${DOTFILES_REPO})"
    chezmoi init --apply "${DOTFILES_REPO}" || {
        echo "fail:dotfiles (chezmoi init failed; check repo access and DOTFILES_REPO)"
        exit 1
    }
fi

echo "ok:dotfiles"
echo "      verify: chezmoi verify || chezmoi diff"
