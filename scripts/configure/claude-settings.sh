#!/bin/bash
# Merge manifests/claude-settings.json into ~/.claude/settings.json (deep-merge via jq).
# Idempotent — re-running yields identical bytes.
# Reference: https://stedolan.github.io/jq/manual/
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

MANIFEST="${FORGE_PROVISION_ROOT}/manifests/claude-settings.json"
SETTINGS="${NEW_CLAUDE_DIR}/settings.json"

if ! command -v jq >/dev/null 2>&1; then
    echo "fail:claude-settings (jq not on PATH — run scripts/install/brew-bundle.sh)"
    exit 1
fi

if [[ ! -f "${MANIFEST}" ]]; then
    echo "fail:claude-settings (manifest not found at ${MANIFEST})"
    exit 1
fi

mkdir -p "${NEW_CLAUDE_DIR}"
[[ -f "${SETTINGS}" ]] || echo "{}" > "${SETTINGS}"

TMP="$(mktemp)"
# Deep-merge: . * (manifest) recursively merges, with manifest values winning on key conflicts.
jq -s '.[0] * .[1]' "${SETTINGS}" "${MANIFEST}" > "${TMP}" || {
    echo "fail:claude-settings (jq merge failed)"
    rm -f "${TMP}"
    exit 1
}

# Only replace if content actually differs (preserves mtime for inspection)
if cmp -s "${SETTINGS}" "${TMP}"; then
    echo "skip:claude-settings (settings.json already merged)"
    rm -f "${TMP}"
    exit 0
fi

mv "${TMP}" "${SETTINGS}"
echo "ok:claude-settings"
jq '.' "${SETTINGS}"
