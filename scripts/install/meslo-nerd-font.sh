#!/bin/bash
# Install Meslo Nerd Font via Homebrew (homebrew/cask).
# Idempotent: skips if the cask is installed OR if Meslo nerd font files are
# already present in ~/Library/Fonts/.
# Note: setting the font for a Terminal.app profile is deferred — NSFont archive
# encoding is binary plist and not shell-friendly. Pick the font once in Terminal
# Settings GUI after this install.
# Reference: https://www.nerdfonts.com/font-downloads
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

CASK="font-meslo-lg-nerd-font"

if brew list --cask 2>/dev/null | grep -qx "${CASK}"; then
    echo "skip:meslo-nerd-font (cask installed: ${CASK})"
    exit 0
fi

if compgen -G "${HOME}/Library/Fonts/MesloLG*NerdFont*.ttf" >/dev/null 2>&1; then
    echo "skip:meslo-nerd-font (font files present in ~/Library/Fonts)"
    exit 0
fi

if ! command -v brew >/dev/null 2>&1; then
    echo "fail:meslo-nerd-font (brew not on PATH — run scripts/install/brew.sh first)"
    exit 1
fi

echo "install:meslo-nerd-font"
brew install --cask "${CASK}"
