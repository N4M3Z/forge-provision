#!/bin/bash
# Register the rtk PreToolUse hook in ~/.claude/settings.json globally.
# Wraps `rtk init -g --auto-patch` — rtk owns the install (settings.json + RTK.md + CLAUDE.md @-include).
# Idempotent — re-running with hook already configured is a no-op.
# Reference: https://github.com/rtk-ai/rtk
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if ! command -v rtk >/dev/null 2>&1; then
    echo "fail:rtk-hook (rtk not on PATH — run scripts/install/brew-bundle.sh)"
    exit 1
fi

# Skip if hook already configured (rtk's own state check)
if rtk init -g --show 2>&1 | grep -q '^\[ok\] Hook:'; then
    echo "skip:rtk-hook (hook already registered)"
    exit 0
fi

echo "register:rtk-hook"
rtk init -g --auto-patch || {
    echo "fail:rtk init"
    exit 1
}

echo "ok:rtk-hook"
echo "      restart Claude Code for the hook to take effect in this session"
