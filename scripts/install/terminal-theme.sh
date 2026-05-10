#!/bin/bash
# Apply ${TERMINAL_THEME} to default macOS Terminal.app via mbadolato/iTerm2-Color-Schemes.
# Idempotent: skips if Default Window Settings already matches.
#
# Note: the active Terminal window keeps its current profile until you open
# a new window (Cmd+N) — `defaults write` only affects new windows.
#
# Future: per-emulator companions (terminal-theme-ghostty.sh, …) will read the
# same TERMINAL_THEME. mbadolato has a ghostty/ subdir; warp/wave need separate
# sources (e.g. catppuccin/warp). Manifest mapping TBD when those land.
#
# Reference: https://github.com/mbadolato/iTerm2-Color-Schemes
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

THEME="${TERMINAL_THEME:-Dracula}"
SCHEMES_REPO="${TERMINAL_SCHEMES_REPO:-${DEV_DIR}/iTerm2-Color-Schemes}"
SCHEMES_URL="https://github.com/mbadolato/iTerm2-Color-Schemes.git"
THEME_FILE="${SCHEMES_REPO}/terminal/${THEME}.terminal"

# Auto-clone mbadolato if SCHEMES_REPO points at it and is missing.
# Custom local repos (e.g. ${DEV_DIR}/themes) are NOT auto-cloned — the user owns them.
if [[ ! -d "${SCHEMES_REPO}" ]]; then
    if [[ "${SCHEMES_REPO}" == "${DEV_DIR}/iTerm2-Color-Schemes" ]]; then
        echo "clone:iTerm2-Color-Schemes"
        git clone --depth 1 --quiet "${SCHEMES_URL}" "${SCHEMES_REPO}" || {
            echo "fail:clone iTerm2-Color-Schemes"
            exit 1
        }
    else
        echo "fail:terminal-theme (SCHEMES_REPO missing: ${SCHEMES_REPO})"
        exit 1
    fi
fi

# Verify the theme file exists
if [[ ! -f "${THEME_FILE}" ]]; then
    echo "fail:terminal-theme (${THEME}.terminal not found)"
    echo "      check ${SCHEMES_REPO}/terminal/ for available themes"
    exit 1
fi

# Idempotency: skip if Default Window Settings already matches
CURRENT=$(defaults read com.apple.terminal "Default Window Settings" 2>/dev/null | tr -d '"')
if [[ "${CURRENT}" == "${THEME}" ]]; then
    echo "skip:terminal-theme (Default Window Settings already ${THEME})"
    exit 0
fi

# Import the .terminal file into Terminal.app's preferences
echo "import:${THEME}.terminal"
open "${THEME_FILE}"
sleep 2

# Set as default + startup
echo "set:default-window-settings=${THEME}"
defaults write com.apple.terminal "Default Window Settings" -string "${THEME}"
defaults write com.apple.terminal "Startup Window Settings" -string "${THEME}"

echo "ok:terminal-theme=${THEME}"
echo "      open a new Terminal window (Cmd+N) to see the theme"
