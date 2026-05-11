#!/bin/bash
# Deploy forge-core's skills/agents/rules into ~/.claude, ~/.gemini, ~/.codex, ~/.opencode.
# Uses forge-cli's `install` (= assemble + deploy in one step).
# Idempotent — manifest-based SHA-256 fingerprints; unchanged files are skipped.
# User-modified deployed files are PRESERVED (skipped) unless --force is added below.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

FORGE_CORE_DIR="${DEV_DIR}/forge-core"
FORGE_BIN="${HOME}/.local/bin/forge"
[[ -x "${FORGE_BIN}" ]] || FORGE_BIN="$(command -v forge 2>/dev/null)"

if [[ ! -d "${FORGE_CORE_DIR}" ]]; then
    echo "fail:forge-deploy (forge-core not cloned at ${FORGE_CORE_DIR})"
    exit 1
fi

if [[ -z "${FORGE_BIN}" || ! -x "${FORGE_BIN}" ]]; then
    echo "fail:forge-deploy (forge binary not found — run scripts/install/forge.sh first)"
    exit 1
fi

echo "validate:forge-core"
"${FORGE_BIN}" validate --source "${FORGE_CORE_DIR}" || {
    echo "fail:forge-deploy (validation failed)"
    exit 1
}

echo "install:forge-core (assemble + deploy)"
# --target ${HOME} deploys each provider to ${HOME}/.{claude,codex,gemini,opencode}/.
# Without --target, providers land under the current directory — definitely not what we want.
"${FORGE_BIN}" install --source "${FORGE_CORE_DIR}" --target "${HOME}" || {
    echo "fail:forge-deploy (install failed)"
    exit 1
}

echo "ok:forge-deploy"
echo "      skills/agents/rules deployed to ~/.claude, ~/.gemini, ~/.codex, ~/.opencode"
