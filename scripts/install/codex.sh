#!/bin/bash
# Install Codex CLI (OpenAI's terminal coding agent).
# Idempotent: skips if `codex` is already on PATH.
# Reference: https://developers.openai.com/codex/cli
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if command -v codex >/dev/null 2>&1; then
    echo "skip:codex (already installed: $(command -v codex))"
    exit 0
fi

echo "install:codex"
# Download to a file first: a failed download aborts here instead of being
# masked by the pipe's shell exit status. The vendor installer is rolling
# (no stable upstream hash to pin against).
installer="$(command mktemp -t codex-install-XXXXXX)"
trap 'command rm -f "${installer}"' EXIT
command curl -fsSL https://chatgpt.com/codex/install.sh -o "${installer}" || {
    echo "fail:codex (installer download failed)"
    exit 1
}
sh "${installer}"
