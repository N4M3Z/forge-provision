#!/bin/bash
# Install OpenCode through the vendor installer, not Homebrew: the core
# formula lags the weekly releases, and the harness self-updates in place.
# Idempotent: skips if `opencode` is already on PATH.
# Reference: https://opencode.ai/docs/ ("curl -fsSL https://opencode.ai/install | bash")
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if command -v opencode >/dev/null 2>&1; then
    echo "skip:opencode (already installed: $(command -v opencode))"
    exit 0
fi

echo "install:opencode"
# Download to a file first: a failed download aborts here instead of being
# masked by the pipe's shell exit status. The vendor installer is rolling
# (no stable upstream hash to pin against).
installer="$(command mktemp -t opencode-install-XXXXXX)"
trap 'command rm -f "${installer}"' EXIT
command curl -fsSL https://opencode.ai/install -o "${installer}" || {
    echo "fail:opencode (installer download failed)"
    exit 1
}
bash "${installer}"
