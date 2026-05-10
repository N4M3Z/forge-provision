#!/bin/bash
# Install Claude Code.
# Idempotent: skips if `claude` is already on PATH.
# Reference: https://code.claude.com/docs/en/quickstart
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if command -v claude >/dev/null 2>&1; then
    echo "skip:claude (already installed: $(command -v claude))"
    exit 0
fi

echo "install:claude"
curl -fsSL https://claude.ai/install.sh | bash
