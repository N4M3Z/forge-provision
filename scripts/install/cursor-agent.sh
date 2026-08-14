#!/bin/bash
# Install the Cursor CLI (the `agent` binary) through the vendor installer.
# It lands in ~/.local/bin and auto-updates by default (`agent update` by
# hand). The Cursor IDE itself stays a cask in the Brewfile; the app has its
# own updater and the cask is marked auto_updates, so Homebrew does not pin it.
# Idempotent: skips if `agent` is already on PATH.
# Reference: https://cursor.com/docs/cli/installation ("curl https://cursor.com/install -fsS | bash")
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if command -v agent >/dev/null 2>&1; then
    echo "skip:cursor-agent (already installed: $(command -v agent))"
    exit 0
fi

echo "install:cursor-agent"
installer="$(command mktemp -t cursor-agent-install-XXXXXX)"
trap 'command rm -f "${installer}"' EXIT
command curl -fsS https://cursor.com/install -o "${installer}" || {
    echo "fail:cursor-agent (installer download failed)"
    exit 1
}
bash "${installer}"
