#!/bin/bash
# Configure RTK globally for Claude Code and Codex using each supported path.
# Claude gets the PreToolUse rewriter; Codex gets AGENTS.md + RTK.md instructions
# because RTK does not support transparent PreToolUse rewriting there.
# Idempotent — RTK owns both convergent installs.
# Reference: https://github.com/rtk-ai/rtk
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if ! command -v rtk >/dev/null 2>&1; then
    echo "fail:rtk-hook (rtk not on PATH — run scripts/install/brew-bundle.sh)"
    exit 1
fi

rtk_status=$(rtk init -g --show 2>&1)
if [[ "${rtk_status}" == *"[ok] Hook:"* ]]; then
    echo "skip:rtk-hook (hook already registered)"
else
    echo "register:rtk-hook"
    rtk init -g --auto-patch || {
        echo "fail:rtk init (Claude Code)"
        exit 1
    }
fi

echo "configure:rtk-codex"
rtk init -g --codex || {
    echo "fail:rtk init (Codex)"
    exit 1
}

echo "ok:rtk-hook"
echo "      restart Claude Code and Codex to load the updated integration"
