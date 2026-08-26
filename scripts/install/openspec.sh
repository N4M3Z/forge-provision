#!/usr/bin/env bash
# Install the OpenSpec CLI — spec-driven change validation (deck DECK-0010).
# Idempotent: skips when the pinned version is already installed.
#
# OpenSpec ships as an npm package only. The CLI hard-codes the openspec/
# directory name, so the dotfiles wrapper at ~/.local/bin/openspec shadows
# this binary and points it at each repository's docs/ tree through a
# ~/.openspec/<org>/<repo> symlink. The wrapper also keeps telemetry off
# (OPENSPEC_TELEMETRY=0). Do not add hook wiring here.
#     Upstream: https://github.com/Fission-AI/OpenSpec
#
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

OPENSPEC_VERSION="1.10.0"
PACKAGE="@fission-ai/openspec"

if ! command -v npm >/dev/null 2>&1; then
    echo "fail:openspec (npm not on PATH)"
    exit 1
fi

installed="$(npm ls -g --depth 0 "${PACKAGE}" 2>/dev/null | rg -o "${PACKAGE}@[0-9.]+" || true)"
if [[ "${installed}" == "${PACKAGE}@${OPENSPEC_VERSION}" ]]; then
    echo "skip:openspec (already ${OPENSPEC_VERSION})"
    exit 0
fi

echo "install:openspec (${PACKAGE}@${OPENSPEC_VERSION})"
npm install -g "${PACKAGE}@${OPENSPEC_VERSION}" \
    || { echo "fail:openspec (npm install)"; exit 1; }
echo "ok:openspec (${OPENSPEC_VERSION})"
