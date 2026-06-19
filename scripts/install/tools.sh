#!/bin/bash
# Install non-Homebrew CLI tools: Bun globals (manifests/Bunfile) and uv tools
# (manifests/Uvfile). The Brewfile's counterpart for the package managers Homebrew
# does not cover. Idempotent: a re-install is a safe no-op when already current.
#
# Reference: https://bun.sh  https://docs.astral.sh/uv
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"
manifests="${SCRIPT_DIR}/../../manifests"

specs() { grep -vE '^[[:space:]]*(#|$)' "$1" 2>/dev/null; }

if command -v bun >/dev/null 2>&1; then
    while IFS= read -r pkg; do
        echo "bun:install ${pkg}"
        bun install -g "${pkg}"
    done < <(specs "${manifests}/Bunfile")
else
    echo "warn:bun missing; skipping ${manifests}/Bunfile (install via the Brewfile first)"
fi

if command -v uv >/dev/null 2>&1; then
    while IFS= read -r tool; do
        echo "uv:install ${tool}"
        uv tool install "${tool}"
    done < <(specs "${manifests}/Uvfile")
else
    echo "warn:uv missing; skipping ${manifests}/Uvfile (install via the Brewfile first)"
fi

echo "ok:tools (Bunfile + Uvfile applied)"
