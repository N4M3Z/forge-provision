#!/bin/bash
# Seed Codex config from manifests/codex/config.toml to ~/.codex/config.toml
# only when absent. After Codex Desktop runs, the live config is app-managed
# (plugins, trusted hook hashes, project trust, node_repl, and UI state). Never
# overwrite it as a full-file mirror. Never touches ~/.codex/auth.json (secret)
# or forge-deployed agents/rules/skills/.manifest files.
#
# Repairs ~/.codex/hooks.json:
# - removes unsupported imported Claude RTK hooks
# - removes duplicate imported dcg only when native Codex config already has dcg
# - rewrites retired capture-session hooks to forge-data/scripts/session-sync
# - ensures PreCompact and Stop lifecycle capture hooks exist
# Auth is interactive: run `codex login` after install.
# Reference: https://developers.openai.com/codex/config-basic
# Source: https://github.com/N4M3Z/forge-provision

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../lib/env.sh"

DRY_RUN=false
for arg in "$@"; do
    case "${arg}" in
        --dry-run) DRY_RUN=true ;;
        --help|-h)
            echo "usage: scripts/configure/codex.sh [--dry-run]"
            exit 0
            ;;
    esac
done

CODEX_CONFIG="${HOME}/.codex"
MANIFEST_FILE="${FORGE_PROVISION_ROOT}/manifests/codex/config.toml"
DEPLOYED_FILE="${CODEX_CONFIG}/config.toml"
HOOKS_FILE="${CODEX_CONFIG}/hooks.json"
SESSION_SYNC="${SESSION_SYNC:-${DEV_DIR}/forge-data/scripts/session-sync}"

repair_codex_hooks() {
    local config_contents=""
    local remove_imported_dcg=false
    local input_file
    local input_temp=""
    local temporary_file

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

    if [[ -f "${HOOKS_FILE}" ]]; then
        input_file="${HOOKS_FILE}"
    else
        input_temp=$(mktemp "${TMPDIR:-/tmp}/codex-hooks-input.XXXXXX") || {
            echo "fail:codex-hooks (could not create temporary input file)"
            return 1
        }
        printf '%s\n' '{"hooks":{}}' > "${input_temp}"
        input_file="${input_temp}"
    fi

    temporary_file=$(mktemp "${TMPDIR:-/tmp}/codex-hooks.XXXXXX") || {
        [[ -n "${input_temp}" ]] && command rm -f "${input_temp}"
        echo "fail:codex-hooks (could not create temporary file)"
        return 1
    }

    if ! jq \
        --arg session_sync "${SESSION_SYNC}" \
        --argjson remove_imported_dcg "${remove_imported_dcg}" '
        def repair_event($event):
            .hooks[$event] = [
                (.hooks[$event] // [])[]
                | .hooks = [
                    (.hooks // [])[]
                    | if .command == "capture-session"
                      then .command = $session_sync
                      else .
                      end
                ]
                | select((.hooks | length) > 0)
            ]
            | if ([.hooks[$event][]?.hooks[]?.command] | index($session_sync)) == null
              then .hooks[$event] += [{"hooks":[{"type":"command","command":$session_sync}]}]
              else .
              end;

        .hooks = (.hooks // {})
        | .hooks["PreToolUse"] = [
            (.hooks["PreToolUse"] // [])[]
            | .hooks = [
                (.hooks // [])[]
                | select(
                    .command != "rtk hook claude"
                    and ($remove_imported_dcg == false or .command != "dcg")
                )
            ]
            | select((.hooks | length) > 0)
        ]
        | if (.hooks["PreToolUse"] | length) == 0
          then del(.hooks["PreToolUse"])
          else .
          end
        | repair_event("PreCompact")
        | repair_event("Stop")
    ' "${input_file}" > "${temporary_file}"; then
        command rm -f "${temporary_file}"
        [[ -n "${input_temp}" ]] && command rm -f "${input_temp}"
        echo "fail:codex-hooks (invalid hooks.json)"
        return 1
    fi

    [[ -n "${input_temp}" ]] && command rm -f "${input_temp}"

    if [[ -f "${HOOKS_FILE}" ]] && cmp -s "${HOOKS_FILE}" "${temporary_file}"; then
        command rm -f "${temporary_file}"
        echo "skip:codex-hooks (already repaired)"
        return 0
    fi

    if [[ "${DRY_RUN}" == true ]]; then
        command rm -f "${temporary_file}"
        echo "dry-run:codex-hooks (would repair hooks.json)"
        return 0
    fi

    command cp "${temporary_file}" "${HOOKS_FILE}"
    command rm -f "${temporary_file}"
    echo "ok:codex-hooks (repaired lifecycle and imported Claude hooks)"
}

if ! command -v codex >/dev/null 2>&1; then
    echo "fail:codex (codex not on PATH; run scripts/install/brew-bundle.sh)"
    exit 1
fi

if [[ ! -f "${MANIFEST_FILE}" ]]; then
    echo "fail:codex (manifest missing at ${MANIFEST_FILE})"
    exit 1
fi

if [[ "${DRY_RUN}" == true ]]; then
    echo "dry-run:codex (would ensure ${CODEX_CONFIG})"
else
    mkdir -p "${CODEX_CONFIG}"
fi

if [[ -f "${DEPLOYED_FILE}" ]]; then
    echo "skip:codex (config.toml exists; Codex app owns live state)"
else
    echo "seed:codex (config.toml)"
    if [[ "${DRY_RUN}" == true ]]; then
        echo "dry-run:codex (would copy ${MANIFEST_FILE} to ${DEPLOYED_FILE})"
    else
        cp "${MANIFEST_FILE}" "${DEPLOYED_FILE}"
    fi
fi

repair_codex_hooks || exit 1

echo "ok:codex"
echo "      authenticate with \`codex login\`; review profile: codex --profile review"
