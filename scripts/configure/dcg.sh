#!/usr/bin/env bash
# Deploy dcg's configuration and the forge custom pack to ~/.config/dcg.
# Idempotent: re-copies only when content differs, then validates the pack.
#
# The Claude PreToolUse hook is NOT registered here. dcg's self-heal keeps its
# entry in ~/.claude/settings.json, and the same entry is sourced in the chezmoi
# settings so it survives a chezmoi apply. Other harnesses (Codex, Gemini,
# Cursor) can be wired with `dcg install` once their settings ownership is known.
#
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

if ! command -v dcg >/dev/null 2>&1; then
    echo "fail:dcg-config (dcg not on PATH — run scripts/install/dcg.sh first)"
    exit 1
fi

SRC="${FORGE_PROVISION_ROOT}/manifests/dcg"
DEST="${XDG_CONFIG_HOME:-${HOME}/.config}/dcg"
mkdir -p "${DEST}/packs"

deploy() {
    local src="$1" dest="$2" label="$3"
    if [[ -f "${dest}" ]] && cmp -s "${src}" "${dest}"; then
        echo "skip:dcg-config (${label} already current)"
        return
    fi
    command cp "${src}" "${dest}"
    echo "ok:dcg-config (${label} → ${dest})"
}

deploy "${SRC}/config.toml" "${DEST}/config.toml" "config.toml"
deploy "${SRC}/forge.yaml" "${DEST}/packs/forge.yaml" "forge.yaml"

if dcg pack validate "${DEST}/packs/forge.yaml" >/dev/null 2>&1; then
    echo "ok:dcg-config (forge.yaml validates)"
else
    echo "fail:dcg-config (forge.yaml failed validation)"
    dcg pack validate "${DEST}/packs/forge.yaml"
    exit 1
fi
