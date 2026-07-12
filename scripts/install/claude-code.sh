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
# Download to a file first: a failed download aborts here instead of being
# masked by the pipe's shell exit status. The vendor installer is rolling
# (no stable upstream hash to pin against).
installer="$(command mktemp -t claude-install-XXXXXX)"
trap 'command rm -f "${installer}"' EXIT
command curl -fsSL https://claude.ai/install.sh -o "${installer}" || {
    echo "fail:claude (installer download failed)"
    exit 1
}
bash "${installer}"
