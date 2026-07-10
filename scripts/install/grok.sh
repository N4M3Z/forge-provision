#!/bin/bash
# Install Grok Build CLI (xAI's terminal coding agent).
# Installs `grok` and `agent` binaries into ~/.grok/bin (override with GROK_BIN_DIR).
# Idempotent: skips if `grok` is already on PATH.
# Reference: https://x.ai/news/grok-build-cli
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if command -v grok >/dev/null 2>&1; then
    echo "skip:grok (already installed: $(command -v grok))"
    exit 0
fi

echo "install:grok"
# Download to a file first: a failed download aborts here instead of being
# masked by the pipe's shell exit status. The vendor installer is rolling
# (no stable upstream hash to pin against).
installer="$(command mktemp -t grok-install-XXXXXX)"
trap 'command rm -f "${installer}"' EXIT
command curl -fsSL https://x.ai/cli/install.sh -o "${installer}" || {
    echo "fail:grok (installer download failed)"
    exit 1
}
bash "${installer}"
