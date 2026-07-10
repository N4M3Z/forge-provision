#!/bin/bash
# Seed Codex config from manifests/codex/config.toml to ~/.codex/config.toml,
# only when absent. The live config is chezmoi-owned (dot_codex/config.toml);
# capture tweaks with `chezmoi re-add`. Never touches ~/.codex/auth.json (secret)
# or the forge-deployed agents/rules/skills/.manifest (forge install owns those).
# Removes only known-invalid Claude hook imports from ~/.codex/hooks.json:
# Codex owns dcg in config.toml, while RTK supports Codex through AGENTS.md
# instructions rather than its Claude PreToolUse rewriter. Other hooks survive.
# Auth is interactive: run `codex login` after install.
# Reference: https://developers.openai.com/codex/config-basic
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

CODEX_CONFIG="${HOME}/.codex"
MANIFEST_FILE="${FORGE_PROVISION_ROOT}/manifests/codex/config.toml"
DEPLOYED_FILE="${CODEX_CONFIG}/config.toml"
HOOKS_FILE="${CODEX_CONFIG}/hooks.json"

clean_imported_claude_hooks() {
    local config_contents=""
    local remove_imported_dcg=false
    local temporary_file

    [[ -f "${HOOKS_FILE}" ]] || return 0

    if [[ -f "${DEPLOYED_FILE}" ]]; then
        config_contents=$(<"${DEPLOYED_FILE}")
        if [[ "${config_contents}" == *'command = "dcg"'* ]] \
            || [[ "${config_contents}" == *"command = 'dcg'"* ]]; then
            remove_imported_dcg=true
        fi
    fi

    if ! command -v jq >/dev/null 2>&1; then
        echo "fail:codex-hooks (jq not on PATH; run scripts/install/brew-bundle.sh)"
        return 1
    fi

    temporary_file=$(mktemp "${TMPDIR:-/tmp}/codex-hooks.XXXXXX") || {
        echo "fail:codex-hooks (could not create temporary file)"
        return 1
    }

    if ! jq --argjson remove_imported_dcg "${remove_imported_dcg}" '
        .hooks.PreToolUse = [
            (.hooks.PreToolUse // [])[]
            | .hooks = [
                (.hooks // [])[]
                | select(
                    .command != "rtk hook claude"
                    and ($remove_imported_dcg == false or .command != "dcg")
                )
            ]
            | select((.hooks | length) > 0)
        ]
        | if (.hooks.PreToolUse | length) == 0
          then del(.hooks.PreToolUse)
          else .
          end
    ' "${HOOKS_FILE}" > "${temporary_file}"; then
        command rm -f "${temporary_file}"
        echo "fail:codex-hooks (invalid hooks.json)"
        return 1
    fi

    if cmp -s "${HOOKS_FILE}" "${temporary_file}"; then
        command rm -f "${temporary_file}"
        echo "skip:codex-hooks (no incompatible Claude hooks)"
        return 0
    fi

    command cp "${temporary_file}" "${HOOKS_FILE}"
    command rm -f "${temporary_file}"
    echo "ok:codex-hooks (removed imported dcg/rtk Claude hooks)"
}

if ! command -v codex >/dev/null 2>&1; then
    echo "fail:codex (codex not on PATH; run scripts/install/brew-bundle.sh)"
    exit 1
fi

if [[ ! -f "${MANIFEST_FILE}" ]]; then
    echo "fail:codex (manifest missing at ${MANIFEST_FILE})"
    exit 1
fi

mkdir -p "${CODEX_CONFIG}"

if [[ -f "${DEPLOYED_FILE}" ]]; then
    echo "skip:codex (config.toml exists; chezmoi owns the live config)"
else
    echo "seed:codex (config.toml)"
    cp "${MANIFEST_FILE}" "${DEPLOYED_FILE}"
fi

clean_imported_claude_hooks || exit 1

echo "ok:codex"
echo "      authenticate with \`codex login\`; review profile: codex --profile review"
