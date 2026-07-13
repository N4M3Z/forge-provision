#!/bin/bash
# Seed the Antigravity CLI MCP config from manifests/gemini/mcp_config.json to
# ~/.gemini/config/mcp_config.json, only when absent. The live file is
# chezmoi-owned (dot_gemini/config/mcp_config.json); personal servers (the gbrain
# MCP with real paths and the local Postgres URL) live there, not in this generic
# seed, which ships an empty mcpServers object. Antigravity reuses ~/.gemini/;
# its own settings.json (telemetry, sandbox, trusted workspaces) is app-managed
# and intentionally not tracked. Auth is interactive: launch `agy` and sign in
# with a Google account.
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

GEMINI_CONFIG="${HOME}/.gemini/config"
MANIFEST_FILE="${FORGE_PROVISION_ROOT}/manifests/gemini/mcp_config.json"
DEPLOYED_FILE="${GEMINI_CONFIG}/mcp_config.json"

if ! command -v agy >/dev/null 2>&1; then
    echo "fail:gemini (agy not on PATH; run scripts/install/brew-bundle.sh)"
    exit 1
fi

if [[ ! -f "${MANIFEST_FILE}" ]]; then
    echo "fail:gemini (manifest missing at ${MANIFEST_FILE})"
    exit 1
fi

mkdir -p "${GEMINI_CONFIG}"

if [[ -f "${DEPLOYED_FILE}" ]]; then
    echo "skip:gemini (mcp_config.json exists; chezmoi owns the live config)"
else
    echo "seed:gemini (mcp_config.json)"
    cp "${MANIFEST_FILE}" "${DEPLOYED_FILE}"
fi

echo "ok:gemini"
echo "      authenticate by launching \`agy\` and signing in with a Google account"
