#!/bin/bash
# Install pxpipe, a localhost proxy that cuts Claude token usage by rendering
# static request context (system prompt, tool docs, collapsed history) as PNGs,
# exploiting image-token pricing (~3.1 chars/token vs ~1 for text). Reported
# 59-70% cuts; on a subscription the saving is usage-window headroom.
#
# Pinned bun global install, never `npx pxpipe-proxy`: the proxy sits in the
# model API path and sees every request, so the version that runs must be the
# version that was reviewed, not whatever npm serves next. Bump the pin
# deliberately.
#
# Runtime wiring is NOT here: the claude() wrapper in the dotfiles zshrc
# auto-starts the proxy and sets ANTHROPIC_BASE_URL only while the port
# answers, so sessions fall back to the direct API when the proxy is down.
# Compression applies only to allowlisted models (default: fable-5, gpt-5.6);
# others pass through byte-identical. Decision: docs/decisions/PROV-0022.
#
# Reference: https://github.com/teamchong/pxpipe
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

PXPIPE_VERSION="${PXPIPE_VERSION:-0.7.1}"

if ! command -v bun >/dev/null 2>&1; then
    echo "fail:pxpipe (bun not on PATH; run scripts/install/brew-bundle.sh)"
    exit 1
fi

if bun pm ls -g 2>/dev/null | grep -q "pxpipe-proxy@${PXPIPE_VERSION}"; then
    echo "skip:pxpipe (pxpipe-proxy@${PXPIPE_VERSION} already installed)"
    exit 0
fi

echo "install:pxpipe (pxpipe-proxy@${PXPIPE_VERSION} via bun global)"
bun install -g "pxpipe-proxy@${PXPIPE_VERSION}" || {
    echo "fail:pxpipe (bun install)"
    exit 1
}

command -v pxpipe >/dev/null 2>&1 || export PATH="$HOME/.bun/bin:$PATH"
if command -v pxpipe >/dev/null 2>&1; then
    echo "ok:pxpipe (${PXPIPE_VERSION})"
    echo "      sessions route through it via the claude() zshrc wrapper; dashboard at http://127.0.0.1:47821/"
else
    echo "warn:pxpipe (installed but pxpipe not on PATH; check ~/.bun/bin)"
fi
