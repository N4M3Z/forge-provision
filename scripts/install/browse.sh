#!/bin/bash
# Install the Browserbase `browse` CLI (npm global). Not a Homebrew cask, so it
# lives here rather than in the Brewfile. Idempotent: skips if already present.
# Auth is one env var, BROWSERBASE_API_KEY (no project id); verify with
# `browse cloud projects list`. Skill: skills/BrowserbaseToolkit.
# Reference: https://browserbase.com/SKILL.md
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"
require_scope full

if ! command -v npm >/dev/null 2>&1; then
    echo "fail:browse (npm not on PATH; run scripts/install/brew-bundle.sh for node)"
    exit 1
fi

# Clear deprecated CLIs that shadow `browse`, if present.
if npm ls -g @browserbasehq/cli @browserbasehq/browse-cli >/dev/null 2>&1; then
    echo "clean:browse (removing deprecated @browserbasehq CLIs)"
    npm uninstall -g @browserbasehq/cli @browserbasehq/browse-cli >/dev/null 2>&1
fi

if command -v browse >/dev/null 2>&1; then
    echo "skip:browse (already installed: $(browse --version 2>/dev/null | grep -viE 'update available' | head -1))"
    echo "ok:browse"
    exit 0
fi

echo "install:browse (npm install -g browse@latest)"
npm install -g browse@latest || { echo "fail:browse (npm install)"; exit 1; }
echo "ok:browse"
echo "      set BROWSERBASE_API_KEY, then verify with \`browse cloud projects list\`"
